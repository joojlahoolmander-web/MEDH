#!/usr/bin/env bash
# start.sh — تهيئة شاشة افتراضية، تفعيل VNC، تشغيل ngrok (اختياري)، وتحريك الماوس للحفاظ على GUI مرئي.
# متغيرات بيئية:
#   NGROK_AUTH_TOKEN  (secret) - اختياري، لتشغيل نفق ngrok
#   VNC_PASSWORD      (secret) - اختياري، كلمة مرور VNC
#   KEEPALIVE_SECONDS - اختياري، افتراضي 60
set -euo pipefail

LOGDIR="/tmp/start_sh_logs"
mkdir -p "$LOGDIR"
exec > >(tee -a "$LOGDIR/start_sh.out.log") 2> >(tee -a "$LOGDIR/start_sh.err.log" >&2)

echo "== start.sh: $(date) =="

NGROK_AUTH_TOKEN="${NGROK_AUTH_TOKEN:-}"
VNC_PASSWORD="${VNC_PASSWORD:-}"
KEEPALIVE_SECONDS="${KEEPALIVE_SECONDS:-60}"

echo "NGROK token present: $( [ -n "$NGROK_AUTH_TOKEN" ] && echo yes || echo no )"
echo "VNC password present: $( [ -n "$VNC_PASSWORD" ] && echo yes || echo no )"

# ---------- helper ----------
run_safe() { echo "+ $*"; if ! eval "$@"; then echo "  -> failed (ignored): $*"; fi }

# ---------- Install (best-effort) ----------
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Skipping auto-install. Recommended to preinstall Homebrew in runner."
fi

# Try install useful tools (best-effort)
run_safe "brew install displayplacer || true"
run_safe "brew install cliclick || true"
run_safe "brew install --cask betterdisplay || true"
# betterdisplaycli comes from a tap
if ! command -v betterdisplaycli >/dev/null 2>&1; then
  run_safe "brew tap waydabber/betterdisplay || true"
  run_safe "brew install waydabber/betterdisplay/betterdisplaycli || true"
fi
if [ -n "$NGROK_AUTH_TOKEN" ]; then
  run_safe "brew install --cask ngrok || true"
fi

# ---------- Start BetterDisplay.app if present ----------
if [ -d "/Applications/BetterDisplay.app" ]; then
  echo "Starting BetterDisplay.app..."
  run_safe "open -a /Applications/BetterDisplay.app"
  sleep 2
fi

# ---------- Create & attach virtual screen (betterdisplaycli) ----------
created_virtual_screen=false
if command -v betterdisplaycli >/dev/null 2>&1; then
  echo "Creating virtual screen via betterdisplaycli (best-effort)..."
  VNAME="HeadlessDummy"
  run_safe "sudo betterdisplaycli create -devicetype=virtualscreen -virtualscreenname=${VNAME} -aspectWidth=16 -aspectHeight=9 -width=2560 -height=1440"
  run_safe "sudo betterdisplaycli set -namelike=${VNAME} -connected=on -main=on"
  if betterdisplaycli list 2>/dev/null | grep -qi "$VNAME"; then
    created_virtual_screen=true
  fi
else
  echo "betterdisplaycli not available; skipping virtual screen creation."
fi

# ---------- Wake up GUI: move mouse & keep alive ----------
if command -v cliclick >/dev/null 2>&1; then
  echo "Waking GUI via cliclick and starting keepalive loop..."
  run_safe "cliclick m:100,100 w:200 m:200,200 w:200"
  nohup bash -c "while true; do cliclick m:500,500; sleep ${KEEPALIVE_SECONDS}; done" >/tmp/mouse_keepalive.log 2>&1 &
else
  echo "cliclick not installed — can't auto-move mouse."
fi

# ---------- Enable Remote Management (VNC) ----------
echo "Configuring Remote Management (Apple Remote Desktop / Screen Sharing)..."
run_safe "sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -access -on -configure -allowAccessFor -allUsers -configure -restart -agent -privs -all"

if [ -n "$VNC_PASSWORD" ]; then
  echo "Attempting to set VNC password (best-effort)..."
  # set legacy VNC and try to set password via kickstart (may be restricted on some macOS builds)
  run_safe "sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -clientopts -setvnclegacy -vnclegacy yes -restart -agent"
  run_safe "printf '%s\n' '$VNC_PASSWORD' | sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -clientopts -setvncpasswd -encrypt || true"
fi

# ---------- Optional: start ngrok tunnel for VNC ----------
if [ -n "$NGROK_AUTH_TOKEN" ] && command -v ngrok >/dev/null 2>&1; then
  echo "Starting ngrok TCP tunnel for port 5900..."
  run_safe "ngrok authtoken '$NGROK_AUTH_TOKEN' || true"
  nohup ngrok tcp 5900 --region=us >/tmp/ngrok.log 2>&1 &
  sleep 4
  if command -v curl >/dev/null 2>&1; then
    run_safe "curl -s http://localhost:4040/api/tunnels || true"
  fi
else
  echo "ngrok skipped (token not set or ngrok missing)."
fi

# ---------- Summary ----------
echo "=== Summary ==="
echo "Virtual screen created: $created_virtual_screen"
echo "Mouse keepalive log: /tmp/mouse_keepalive.log"
echo "Output logs: $LOGDIR/start_sh.out.log, $LOGDIR/start_sh.err.log"
echo "If screen still black: try a physical HDMI/DP dummy plug or open interactive debug (tmate) to inspect."
echo "Done."
  
