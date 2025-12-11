#!/usr/bin/env bash
# start.sh
# يقوم بمحاولات إنشاء شاشة افتراضية (BetterDisplay), تهيئة VNC, تحريك الماوس لإيقاظ GUI,
# وتشغيل ngrok TCP tunnel على 5900 (إن توفّر NGROK_AUTH_TOKEN).
#
# يعتمد على Homebrew packages: betterdisplay (cask), betterdisplaycli, displayplacer, cliclick, ngrok (cask)
# يُفضّل تثبيت هذه الحزم مسبقًا في الـ workflow قبل استدعاء start.sh — لكن السكربت يحاول تثبيتها أيضًا.
#
# متغيرات بيئية:
#   NGROK_AUTH_TOKEN   -> من GitHub Secret (مطلوب إذا تريد ngrok)
#   VNC_PASSWORD       -> من GitHub Secret (مطلوب لتعيين كلمة مرور VNC)
#   NEW_USER_NAME      -> اسم المستخدم الذي أنشأته (مهم لو تحتاج أن تتصرف باسمه)
#   KEEPALIVE_SECONDS  -> فاصل تحريك الماوس (افتراضي 60)

set -euo pipefail

LOGDIR="/tmp/start_sh_logs"
mkdir -p "$LOGDIR"
exec > >(tee -a "$LOGDIR/start_sh.out.log") 2> >(tee -a "$LOGDIR/start_sh.err.log" >&2)

echo "== start.sh $(date) =="

NGROK_AUTH_TOKEN="${NGROK_AUTH_TOKEN:-}"
VNC_PASSWORD="${VNC_PASSWORD:-}"
USERNAME="${NEW_USER_NAME:-medhag}"
KEEPALIVE_SECONDS="${KEEPALIVE_SECONDS:-60}"

echo "Username: $USERNAME"
echo "NGROK_AUTH_TOKEN set: $( [ -n "$NGROK_AUTH_TOKEN" ] && echo yes || echo no )"
echo "VNC_PASSWORD set: $( [ -n "$VNC_PASSWORD" ] && echo yes || echo no )"

run_safe() { echo "+ $*"; if ! eval "$@"; then echo "  -> failed (ignored): $*"; fi }

# 1) محاولة تثبيت الأدوات (best-effort)
if command -v brew >/dev/null 2>&1; then
  echo "Ensuring dependencies (best-effort) via Homebrew..."
  run_safe "brew update || true"
  run_safe "brew install displayplacer || true"
  run_safe "brew install cliclick || true"
  run_safe "brew install --cask betterdisplay || true"
  run_safe "brew tap waydabber/betterdisplay || true"
  run_safe "brew install waydabber/betterdisplay/betterdisplaycli || true"
  # ngrok cask
  if [ -n "$NGROK_AUTH_TOKEN" ]; then
    run_safe "brew install --cask ngrok || true"
  fi
else
  echo "Homebrew not found — skipping package install. Ensure dependencies are installed in runner."
fi

# 2) Start BetterDisplay app (so helper daemons run)
if [ -d "/Applications/BetterDisplay.app" ]; then
  echo "Opening BetterDisplay.app..."
  run_safe "open -a /Applications/BetterDisplay.app"
  sleep 2
fi

# 3) Create virtual screen via betterdisplaycli (best-effort)
created_virtual=false
if command -v betterdisplaycli >/dev/null 2>&1; then
  VNAME="HeadlessDummy"
  echo "Creating virtual display $VNAME (best-effort)..."
  run_safe "sudo betterdisplaycli create -devicetype=virtualscreen -virtualscreenname=${VNAME} -aspectWidth=16 -aspectHeight=9 -width=1920 -height=1080"
  run_safe "sudo betterdisplaycli set -namelike=${VNAME} -connected=on -main=on"
  if betterdisplaycli list 2>/dev/null | grep -qi "$VNAME"; then
    created_virtual=true
    echo "Virtual display $VNAME is present."
  fi
else
  echo "betterdisplaycli not available; skipping virtual display creation."
fi

# 4) Move mouse to wake GUI and start keepalive loop
if command -v cliclick >/dev/null 2>&1; then
  echo "Waking GUI with cliclick and starting keepalive loop..."
  run_safe "cliclick m:50,50 w:150 m:100,100"
  nohup bash -c "while true; do cliclick m:500,500; sleep ${KEEPALIVE_SECONDS}; done" >/tmp/mouse_keepalive.log 2>&1 &
  echo "Mouse keepalive started."
else
  echo "cliclick not installed — GUI wake not available programmatically."
fi

# 5) Enable Remote Management (ARD) and set VNC password (legacy VNC)
echo "Configuring Remote Management (ARD) and trying to set VNC password (best-effort)..."
run_safe "sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -access -on -configure -allowAccessFor -allUsers -configure -restart -agent -privs -all"

if [ -n "$VNC_PASSWORD" ]; then
  # enable legacy VNC and attempt to set encrypted password
  run_safe "sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -clientopts -setvnclegacy -vnclegacy yes -restart -agent"
  # attempt to set vnc password (may fail on some macOS builds; best-effort)
  run_safe "printf '%s\n' '$VNC_PASSWORD' | sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -clientopts -setvncpasswd -encrypt || true"
  echo "Attempted to set VNC password (if supported by OS)."
else
  echo "VNC_PASSWORD not provided — skip setting VNC password."
fi

# 6) Start ngrok tunnel (tcp 5900) if token provided
if [ -n "$NGROK_AUTH_TOKEN" ] && command -v ngrok >/dev/null 2>&1; then
  echo "Starting ngrok TCP tunnel for port 5900..."
  run_safe "ngrok authtoken '$NGROK_AUTH_TOKEN' || true"
  nohup ngrok tcp 5900 --region=us >/tmp/ngrok.log 2>&1 &
  sleep 4
  if command -v curl >/dev/null 2>&1; then
    echo "ngrok tunnels:"
    run_safe "curl -s http://localhost:4040/api/tunnels || true"
  fi
else
  echo "Skipping ngrok: token not set or ngrok not installed."
fi

echo "=== Summary ==="
echo "Virtual created: $created_virtual"
echo "Mouse keepalive log: /tmp/mouse_keepalive.log"
echo "Start logs: $LOGDIR/start_sh.out.log ; $LOGDIR/start_sh.err.log"
echo "If screen still black: try attaching a hardware HDMI/DP dummy plug (Headless display emulator)."
echo "Done."
