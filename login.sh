#!/bin/bash
# login.sh — create mac user, enable VNC, configure display helper
# Accepts --no-brew-install to skip brew operations (useful when running under sudo)
set -e

# parse args
NO_BREW=0
for arg in "$@"; do
  if [ "$arg" = "--no-brew-install" ]; then NO_BREW=1; fi
done

MAC_USER="usertestddd"
MAC_PASS="Zxxz4444"
VNC_PASS="Zxxz4444"

echo "Starting login.sh..."
# Ensure we run from a safe directory
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

# set legacy VNC password (Apple expects a special encoded file)
echo "$VNC_PASS" | perl -we 'BEGIN { @k = unpack "C*", pack "H*", "1734516E8BA8C5E2FF1C39567390ADCA"}; $_ = <>; chomp; s/^(.{8}).*/$1/; @p = unpack "C*", $_; foreach (@k) { printf "%02X", $_ ^ (shift @p || 0) }; print "\n"' | sudo tee /Library/Preferences/com.apple.VNCSettings.txt >/dev/null

/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -restart -agent -console || true

# Install brew packages only if not skipped (but keep in mind we're likely running under sudo here)
if [ "$NO_BREW" -eq 0 ]; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing displayplacer & cliclick via brew..."
    brew install displayplacer || true
    brew install cliclick || true
  else
    echo "brew not found, skipping package installs."
  fi
else
  echo "Skipping brew installs (flag --no-brew-install supplied)."
fi

# If displayplacer is present, print list and save a recommended command to /tmp/display_cmd.sh
if command -v displayplacer >/dev/null 2>&1; then
  echo "displayplacer list output:"
  displayplacer list || true

  # Try to build a persistent displayplacer command automatically by extracting the persistent id line.
  PERSISTENT_ID=$(displayplacer list | grep -oE 'id:[A-F0-9-]+' | head -n1 | sed 's/id://')
  if [ -n "$PERSISTENT_ID" ]; then
    # Build the command safely and write it to /tmp/display_cmd.sh using printf to avoid quoting bugs
    CMD_DISPLAY="displayplacer \"id:${PERSISTENT_ID} res:1920x1080 hz:60 color_depth:7 enabled:true scaling:off origin:(0,0) degree:0\""
    printf '%s\n' "#!/bin/bash" "${CMD_DISPLAY}" > /tmp/display_cmd.sh
    chmod +x /tmp/display_cmd.sh || true
    echo "Wrote display command to /tmp/display_cmd.sh:"
    cat /tmp/display_cmd.sh
  else
    echo "Could not auto-detect persistent id; please inspect 'displayplacer list' output above and create /tmp/display_cmd.sh manually if needed."
  fi
else
  echo "displayplacer not installed; cannot configure display automatically."
fi

echo "login.sh done — VNC Username: $MAC_USER  Password: $MAC_PASS"
echo "If ngrok is running, check: http://localhost:4040/api/tunnels"
