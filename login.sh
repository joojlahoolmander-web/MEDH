#!/bin/bash
# login.sh — create mac user, enable VNC, install display tools, start ngrok
set -e

MAC_USER="usertestddd"
MAC_PASS="Zxxz4444"
VNC_PASS="Zxxz4444"

# disable spotlight indexing (optional)
sudo mdutil -i off -a || true

# Create new account (if not exists)
if ! id -u "$MAC_USER" >/dev/null 2>&1; then
  echo "Creating user $MAC_USER..."
  sudo dscl . -create /Users/"$MAC_USER"
  sudo dscl . -create /Users/"$MAC_USER" UserShell /bin/bash
  sudo dscl . -create /Users/"$MAC_USER" RealName "$MAC_USER"
  # choose UniqueID high enough to avoid conflicts
  sudo dscl . -create /Users/"$MAC_USER" UniqueID 1010
  sudo dscl . -create /Users/"$MAC_USER" PrimaryGroupID 80
  sudo dscl . -create /Users/"$MAC_USER" NFSHomeDirectory /Users/"$MAC_USER"
  sudo dscl . -passwd /Users/"$MAC_USER" "$MAC_PASS"
  sudo createhomedir -c -u "$MAC_USER" >/dev/null || true
  sudo dscl . -append /Groups/admin GroupMembership "$MAC_USER" || true
else
  echo "User $MAC_USER already exists, skipping create."
  sudo dscl . -passwd /Users/"$MAC_USER" "$MAC_PASS" || true
fi

# Enable Remote Management (VNC)
echo "Enabling Remote Management..."
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
  -activate -configure -access -on \
  -configure -allowAccessFor -allUsers \
  -configure -privs -all \
  -restart -agent || true

# Set legacy VNC password (8 chars used)
echo "$VNC_PASS" | perl -we 'BEGIN { @k = unpack "C*", pack "H*", "1734516E8BA8C5E2FF1C39567390ADCA"}; $_ = <>; chomp; s/^(.{8}).*/$1/; @p = unpack "C*", $_; foreach (@k) { printf "%02X", $_ ^ (shift @p || 0) }; print "\n"' | sudo tee /Library/Preferences/com.apple.VNCSettings.txt >/dev/null

# Restart ARD agent
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -restart -agent -console || true
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate || true

# Install helper tools if brew exists
if command -v brew >/dev/null 2>&1; then
  echo "Installing displayplacer & cliclick..."
  brew install displayplacer || true
  brew install cliclick || true
else
  echo "Homebrew not found, skipping brew installs."
fi

# Try to 'wake' GUI: set display resolution (best-effort) and move mouse
if command -v displayplacer >/dev/null 2>&1; then
  displayplacer list || true
  displayplacer "id:main res:1920x1080 scaling:on" || true
fi

if command -v cliclick >/dev/null 2>&1; then
  cliclick m:100,100 w:500 m:200,200 w:500 || true
  # background keepalive
  ( while true; do cliclick m:500,500; sleep 60; done ) & disown
fi

# Start ngrok (if installed) using env NGROK_AUTH_TOKEN if present
if command -v ngrok >/dev/null 2>&1; then
  if [ -n "$NGROK_AUTH_TOKEN" ]; then
    ngrok authtoken "$NGROK_AUTH_TOKEN" || true
  fi
  ngrok tcp 5900 --region=us &>/dev/null & disown
  echo "ngrok started (if available)."
else
  echo "ngrok not installed."
fi

echo "Done — VNC Username: $MAC_USER  Password: $MAC_PASS"
echo "If ngrok is running, check http://localhost:4040/api/tunnels for the public URL."
