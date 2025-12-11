#!/usr/bin/env bash
# login.sh — تجهيز حساب مستخدم محلي (اختياري) وتفعيل Remote Management مع صلاحيات كاملة.
# لا تحفظ كلمات مرور صريحة في الريبو؛ استخدم GitHub Secrets.
set -euo pipefail

USERNAME="${1:-ciuser}"
PASSWORD="${2:-}"
FULLNAME="${3:-CI User}"

if id "$USERNAME" &>/dev/null; then
  echo "User $USERNAME already exists."
else
  echo "Creating user $USERNAME..."
  sudo sysadminctl -addUser "$USERNAME" -fullName "$FULLNAME" -password "${PASSWORD:-changeme}" || true
  sudo dscl . -append /Groups/admin GroupMembership "$USERNAME" || true
fi

echo "Ensure user is allowed for Remote Management (if needed)"
# Grant access to all users (kickstart)
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
  -activate -configure -access -on \
  -configure -allowAccessFor -allUsers \
  -configure -restart -agent -privs -all || true

echo "If you need to set a VNC password, call start.sh with VNC_PASSWORD env or run kickstart -setvncpasswd."
