#!/bin/bash
# login.sh — create mac user, enable VNC, install display tools, start ngrok
set -e

MAC_USER="usertestddd"
MAC_PASS="Zxxz4444"
VNC_PASS="Zxxz4444"

if ! id -u "$MAC_USER" >/dev/null 2>&1; then
  dscl . -create /Users/"$MAC_USER"
  dscl . -create /Users/"$MAC_USER" UserShell /bin/bash
  dscl . -create /Users/"$MAC_USER" RealName "$MAC_USER"
  dscl . -create /Users/"$MAC_USER" UniqueID 1010
  dscl . -create /Users/"$MAC_USER" PrimaryGroupID 80
  dscl . -create /Users/"$MAC_USER" NFSHomeDirectory /Users/"$MAC_USER"
  dscl . -passwd /Users/"$MAC_USER" "$MAC_PASS"
  createhomedir -c -u "$MAC_USER" >/dev/null || true
  dscl . -append /Groups/admin GroupMembership "$MAC_USER" || true
else
  dscl . -passwd /Users/"$MAC_USER" "$MAC_PASS" || true
fi

/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
  -activate -configure -access -on \
  -configure -allowAccessFor -allUsers \
  -configure -privs -all \
  -restart -agent || true

echo "$VNC_PASS" | perl -we 'BEGIN { @k = unpack "C*", pack "H*", "1734516E8BA8C5E2FF1C39567390ADCA"}; $_ = <>; chomp; s/^(.{8}).*/$1/; @p = unpack "C*", $_; foreach (@k) { printf "%02X", $_ ^ (shift @p || 0) }; print "\n"' | sudo tee /Library/Preferences/com.apple.VNCSettings.txt >/dev/null

/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -restart -agent -console || true

if command -v brew >/dev/null 2>&1; then
  brew install displayplacer || true
  brew install cliclick || true
fi

if command -v displayplacer >/dev/null 2>&1; then
  displayplacer list || true
  displayplacer "id:main res:1920x1080 scaling:on" || true
fi

if command -v cliclick >/dev/null 2>&1; then
  cliclick m:100,100 w:500 m:200,200 w:500 || true
  ( while true; do cliclick m:500,500; sleep 60; done ) & disown
fi

if command -v ngrok >/dev/null 2>&1; then
  if [ -n "$NGROK_AUTH_TOKEN" ]; then
    ngrok authtoken "$NGROK_AUTH_TOKEN" || true
  fi
  ngrok tcp 5900 --region=us &>/dev/null & disown
fi

echo "Done — VNC Username: $MAC_USER  Password: $MAC_PASS"
echo "If ngrok is running, check http://localhost:4040/api/tunnels for the public URL."
