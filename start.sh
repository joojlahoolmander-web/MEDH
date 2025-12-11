#!/usr/bin/env bash
# start.sh - Enhanced: create virtual display, set VNC, start ngrok, diagnostics & logs
set -euo pipefail

LOGDIR="/tmp/start_sh_logs"
mkdir -p "$LOGDIR"
exec > >(tee -a "$LOGDIR/start_sh.out.log") 2> >(tee -a "$LOGDIR/start_sh.err.log" >&2)

echo "== start.sh $(date) =="
NGROK_AUTH_TOKEN="${NGROK_AUTH_TOKEN:-}"
VNC_PASSWORD="${VNC_PASSWORD:-}"
USERNAME="${NEW_USER_NAME:-medhag}"
KEEPALIVE_SECONDS="${KEEPALIVE_SECONDS:-60}"

echo "User: $USERNAME"
echo "NGROK token set: $( [ -n "$NGROK_AUTH_TOKEN" ] && echo yes || echo no )"
echo "VNC password set: $( [ -n "$VNC_PASSWORD" ] && echo yes || echo no )"

run_safe() { echo "+ $*"; if ! eval "$@"; then echo "  -> failed (ignored): $*"; fi }

# Attempt to ensure betterdisplaycli is linked (Homebrew sometimes leaves it unlinked)
if command -v brew >/dev/null 2>&1; then
  if brew list waydabber/betterdisplay/betterdisplaycli >/dev/null 2>&1 2>/dev/null; then
    echo "Ensuring betterdisplaycli is linked..."
    run_safe "brew link waydabber/betterdisplay/betterdisplaycli || brew link betterdisplaycli || true"
  fi
fi

# Start BetterDisplay app if present, wait for its helper
if [ -d "/Applications/BetterDisplay.app" ]; then
  echo "Opening BetterDisplay.app..."
  run_safe "open -a /Applications/BetterDisplay.app"
  echo "Waiting up to 8s for BetterDisplay helper to start..."
  sleep 4
fi

# Create virtual display (best-effort)
created_virtual=false
if command -v betterdisplaycli >/dev/null 2>&1; then
  VNAME="HeadlessDummy"
  echo "Creating virtual display '$VNAME' (best-effort)..."
  run_safe "sudo betterdisplaycli create -devicetype=virtualscreen -virtualscreenname=${VNAME} -aspectWidth=16 -aspectHeight=9 -width=1920 -height=1080"
  run_safe "sudo betterdisplaycli set -namelike=${VNAME} -connected=on -main=on"
  sleep 1
  if betterdisplaycli list 2>/dev/null | grep -qi "$VNAME"; then
    created_virtual=true
    echo "Virtual display '$VNAME' created and active."
  else
    echo "Warning: virtual display '$VNAME' not visible in betterdisplaycli list."
    echo "betterdisplaycli list output:"
    betterdisplaycli list 2>&1 | sed -n '1,200p' || true
  fi
else
  echo "betterdisplaycli not installed — cannot create software virtual display."
fi

# Wake GUI & keepalive mouse
if command -v cliclick >/dev/null 2>&1; then
  echo "Waking GUI via cliclick..."
  run_safe "cliclick m:50,50 w:120 m:100,100"
  nohup bash -c "while true; do cliclick m:500,500; sleep ${KEEPALIVE_SECONDS}; done" >/tmp/mouse_keepalive.log 2>&1 &
  echo "Mouse keepalive started (log: /tmp/mouse_keepalive.log)."
else
  echo "cliclick not available."
fi

# Configure ARD and try to set VNC password
echo "Configuring Remote Management (ARD)..."
run_safe "sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -access -on -configure -allowAccessFor -allUsers -configure -restart -agent -privs -all"

if [ -n "$VNC_PASSWORD" ]; then
  echo "Attempting to enable legacy VNC and set password (best-effort)..."
  run_safe "sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -clientopts -setvnclegacy -vnclegacy yes -restart -agent"
  run_safe "printf '%s\n' '$VNC_PASSWORD' | sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -clientopts -setvncpasswd -encrypt || true"
fi

# Start ngrok if token provided
if [ -n "$NGROK_AUTH_TOKEN" ]; then
  if command -v ngrok >/dev/null 2>&1; then
    echo "Starting ngrok for TCP 5900..."
    run_safe "ngrok authtoken '$NGROK_AUTH_TOKEN' || true"
    nohup ngrok tcp 5900 --region=us >/tmp/ngrok.log 2>&1 &
    sleep 4
    echo "ngrok process(es):"
    ps aux | egrep 'ngrok' | egrep -v 'egrep' || true
    echo "ngrok tunnels (API):"
    curl -s http://localhost:4040/api/tunnels 2>/dev/null || echo "ngrok API not responding - check /tmp/ngrok.log"
  else
    echo "ngrok not installed; skipping ngrok start."
  fi
fi

# Diagnostics summary (short)
echo "=== Quick diagnostics ==="
echo "betterdisplaycli list:"
command -v betterdisplaycli >/dev/null 2>&1 && betterdisplaycli list 2>/dev/null | sed -n '1,200p' || echo "betterdisplaycli not present"
echo "system_profiler SPDisplaysDataType (first 120 lines):"
system_profiler SPDisplaysDataType 2>/dev/null | sed -n '1,120p' || true
echo "lsof listeners for port 5900:"
sudo lsof -iTCP -sTCP:LISTEN -P -n | egrep "5900|Screen|VNC" || true

echo "start.sh finished. created_virtual=$created_virtual"
