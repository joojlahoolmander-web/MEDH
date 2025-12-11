#!/bin/bash
# login.sh — create mac user, enable VNC, configure display helper
set -e

# parse args
NO_BREW=0
for arg in "$@"; do
  if [ "$arg" = "--no-brew-install" ]; then NO_BREW=1; fi
done

MAC_USER="usertestddd"
MAC_PASS="Zxxz4444"
VNC_PASS="Zxxz4444"

echo "Starting..."

# Ensure we run from a safe directory to avoid getcwd permission issues
cd "${GITHUB_WORKSPACE:-$PWD}" || cd /Users/runner || true

# Create user if missing
if ! id -u "$MAC_USER" >/dev/null 2>&1; then
  echo "Creating user $MAC_USER..."
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
  echo "User exists; updating password..."
  dscl . -passwd /Users/"$MAC_USER" "$MAC_PASS" || true
fi

echo "Enabling Remote Management (ARD)..."
/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
  -activate -configure -access -on \
  -configure -allowAccessFor -allUsers \
  -configure -privs -all \
  -restart -agent || true

# set legacy VNC password (Apple expects a special format)
echo "$VNC_PASS" | perl -we 'BEGIN { @k = unpack "C*", pack "H*", "1734516E8BA8C5E2FF1C39567390ADCA"}; $_ = <>; chomp; s/^(.{8}).*/$1/; @p = unpack "C*", $_; foreach (@k) { printf "%02X", $_ ^ (shift @p || 0) }; print "\n"' | sudo tee /Library/Preferences/com.apple.VNCSettings.txt >/dev/null

/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -restart -agent -console || true

# Optionally install brew packages if not run under sudo (skip if asked)
if [ "$NO_BREW" -eq 0 ]; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing displayplacer & cliclick via brew..."
    brew install displayplacer || true
    brew install cliclick || true
  else
    echo "brew not found, skipping package installs (or provide them in workflow before sudo)."
  fi
else
  echo "Skipping brew installs (flag --no-brew-install supplied)."
fi

# Print displayplacer list and suggestion for concrete display command
if command -v displayplacer >/dev/null 2>&1; then
  echo "displayplacer list output (copy the recommended command if you want a stable display id):"
  displayplacer list || true
fi

echo "Done — VNC Username: $MAC_USER  Password: $MAC_PASS"
echo "If ngrok is running, check: http://localhost:4040/api/tunnels"
