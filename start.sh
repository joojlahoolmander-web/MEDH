#!/bin/bash

# تعريف البيانات
USER_NAME="usertestddd"
USER_PASS="Zxxz4444"
NGROK_TOKEN=$1

# 1. تثبيت الأدوات الضرورية
echo "Installing Display Fixes & Ngrok..."
brew install --cask ngrok
brew install displayplacer cliclick

# 2. الحل السحري للشاشة السوداء (Dynamic Display Configuration)
# نحاول أولاً استخدام معرف 'main' وهو المعرف الافتراضي
echo "Configuring Display Resolution..."
displayplacer "id:main res:1280x1024 scaling:on origin:(0,0) degree:0" || true

# إذا فشل الأمر السابق، نحاول البحث عن المعرف المتاح واستخدامه
CURRENT_ID=$(displayplacer list | grep -o 'id:[^ ]*' | head -1)
if [ -n "$CURRENT_ID" ]; then
  echo "Found Display ID: $CURRENT_ID"
  displayplacer "$CURRENT_ID res:1280x1024 scaling:on origin:(0,0) degree:0"
fi

# 3. إعدادات النظام (Spotlight & Users)
sudo mdutil -i off -a

echo "Creating User: $USER_NAME"
sudo dscl . -create /Users/$USER_NAME
sudo dscl . -create /Users/$USER_NAME UserShell /bin/bash
sudo dscl . -create /Users/$USER_NAME RealName "User Test"
sudo dscl . -create /Users/$USER_NAME UniqueID 1001
sudo dscl . -create /Users/$USER_NAME PrimaryGroupID 80
sudo dscl . -create /Users/$USER_NAME NFSHomeDirectory /Users/$USER_NAME
sudo dscl . -passwd /Users/$USER_NAME $USER_PASS
sudo dscl . -append /Groups/admin GroupMembership $USER_NAME
sudo createhomedir -c -u $USER_NAME > /dev/null

# 4. تفعيل VNC بأقوى صلاحيات (Kickstart)
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -allowAccessFor -allUsers -privs -all
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -clientopts -setvnclegacy -vnclegacy yes 

# تشفير الباسورد لملف الإعدادات
echo $USER_PASS | perl -we 'BEGIN { @k = unpack "C*", pack "H*", "1734516E8BA8C5E2FF1C39567390ADCA"}; $_ = <>; chomp; s/^(.{8}).*/$1/; @p = unpack "C*", $_; foreach (@k) { printf "%02X", $_ ^ (shift @p || 0) }; print "\n"' | sudo tee /Library/Preferences/com.apple.VNCSettings.txt

# 5. إعادة تشغيل خدمات الشاشة لإجبارها على العمل
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -restart -agent -console
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate

# 6. تشغيل ngrok
# ملاحظة: تم إضافة --log=stdout لرؤية أي أخطاء في التيرمينال
ngrok authtoken $NGROK_TOKEN
ngrok tcp 5900 --region=in --log=stdout > /dev/null &
