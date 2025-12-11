#!/usr/bin/env bash
set -euo pipefail

# 1) حاول إنشاء شاشة افتراضية عبر betterdisplaycli
if command -v betterdisplaycli >/dev/null 2>&1; then
  sudo betterdisplaycli create -devicetype=virtualscreen -virtualscreenname=HeadlessDummy -aspectWidth=16 -aspectHeight=9 -width=3840 -height=2160 || true
  sudo betterdisplaycli set -namelike=HeadlessDummy -connected=on -main=on || true
fi

# 2) تحريك الماوس لتنشيط WindowServer
if command -v cliclick >/dev/null 2>&1; then
  cliclick m:100,100 w:300 m:200,200 w:300
  # keep alive background loop
  nohup bash -c 'while true; do cliclick m:500,500; sleep 60; done' >/tmp/mouse_keepalive.log 2>&1 &
fi

# 3) إعادة تشغيل ARD (VNC) كما في login.sh الخاص بك (مقتبس). :contentReference[oaicite:11]{index=11}
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
  -activate -configure -access -on \
  -configure -allowAccessFor -allUsers \
  -configure -restart -agent -privs -all || true

# 4) شغّل ngrok إن وُجد
if command -v ngrok >/dev/null 2>&1 && [ -n "${NGROK_AUTH_TOKEN:-}" ]; then
  ngrok authtoken "$NGROK_AUTH_TOKEN" || true
  nohup ngrok tcp 5900 --region=us >/tmp/ngrok.log 2>&1 &
  sleep 3
  jq -r '.tunnels[0].public_url' <(curl -s http://localhost:4040/api/tunnels) || true
fi

echo "Done. Check logs and VNC connection."
