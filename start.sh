#!/bin/bash

# تعريف البيانات
USER_NAME="usertestddd"
USER_PASS="Zxxz4444"
NGROK_TOKEN=$1

# 1. تثبيت Ngrok فقط (حذفنا displayplacer لأنه يسبب Crash)
echo "Installing Ngrok..."
brew install --cask ngrok
brew install cliclick

# 2. إعدادات الطاقة (مهم جداً لمنع الشاشة السوداء)
echo "Configuring Power Settings..."
sudo systemsetup -setcomputersleep Never
sudo systemsetup -setdisplaysleep Never
sudo systemsetup -setharddisksleep Never
sudo mdutil -i off -a

# 3. إنشاء المستخدم
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

# 4. تفعيل VNC
echo "Enabling VNC..."
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -allowAccessFor -allUsers -privs -all
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -clientopts -setvnclegacy -vnclegacy yes 

# تشفير الباسورد
echo $USER_PASS | perl -we 'BEGIN { @k = unpack "C*", pack "H*", "1734516E8BA8C5E2FF1C39567390ADCA"}; $_ = <>; chomp; s/^(.{8}).*/$1/; @p = unpack "C*", $_; foreach (@k) { printf "%02X", $_ ^ (shift @p || 0) }; print "\n"' | sudo tee /Library/Preferences/com.apple.VNCSettings.txt

# 5. إعادة تشغيل الوكيل (Agent) فقط
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -restart -agent -console
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate

# 6. تشغيل ngrok
ngrok authtoken $NGROK_TOKEN
ngrok tcp 5900 --region=in --log=stdout > /dev/null &
