#!/usr/bin/env bash
# login.sh
# يخلق مستخدم محلي ويمنحه صلاحية admin ثم يفعّل Remote Management (ARD)
# الاستخدام:
#   ./login.sh <username> <password>
# القيم الافتراضية (إن لم تُمرَّر):
#   username = medhag
#   password = (مطلوب عبر env NEW_USER_PASSWORD أو كوسيلة تمرير)

set -euo pipefail

USERNAME="${1:-${NEW_USER_NAME:-medhag}}"
PASSWORD="${2:-${NEW_USER_PASSWORD:-}}"
FULLNAME="${3:-${USERNAME}}"

if [ -z "$PASSWORD" ]; then
  echo "ERROR: user password not provided. Set NEW_USER_PASSWORD secret or pass as argument."
  exit 2
fi

echo "== login.sh => creating/configuring user =="
echo "User: $USERNAME"
echo "Full name: $FULLNAME"

# if user exists, skip creation
if id "$USERNAME" &>/dev/null; then
  echo "User '$USERNAME' already exists — skipping creation."
else
  echo "Creating user '$USERNAME'..."
  sudo sysadminctl -addUser "$USERNAME" -fullName "$FULLNAME" -password "$PASSWORD" || {
    echo "Warning: sysadminctl failed; attempting dscl fallback..."
    sudo dscl . -create "/Users/$USERNAME"
    sudo dscl . -create "/Users/$USERNAME" UserShell /bin/bash
    sudo dscl . -create "/Users/$USERNAME" RealName "$FULLNAME"
    sudo dscl . -create "/Users/$USERNAME" UniqueID "$(dscl . -list /Users UniqueID | awk '{print $2}' | sort -n | tail -1 | awk '{print $1+1}')" || true
    sudo dscl . -create "/Users/$USERNAME" PrimaryGroupID 80
    sudo dscl . -create "/Users/$USERNAME" NFSHomeDirectory "/Users/$USERNAME"
    echo "$PASSWORD" | sudo dscl . -passwd "/Users/$USERNAME" "$PASSWORD" || true
  }
  # create home directory (best-effort)
  sudo createhomedir -c -u "$USERNAME" >/dev/null 2>&1 || true
fi

# add to admin group
echo "Adding $USERNAME to admin group..."
sudo dscl . -append /Groups/admin GroupMembership "$USERNAME" || true

# Enable Remote Management (Apple Remote Desktop) and allow all privileges for admin users
echo "Enabling Remote Management (ARD) and granting privileges..."
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
  -activate -configure -access -on \
  -configure -allowAccessFor -allUsers \
  -configure -restart -agent -privs -all || true

echo "login.sh finished. User '$USERNAME' configured and Remote Management enabled."
