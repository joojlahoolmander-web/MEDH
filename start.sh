#!/bin/bash

# 1. تعريف المتغيرات (الباسورد واليوزر من طلبك)
USER_NAME="usertestddd"
USER_PASS="Zxxz4444"
NGROK_TOKEN=$1

# 2. تثبيت أدوات الشاشة الوهمية (الحل لمشكلة الشاشة السوداء) [cite: 1, 2, 3]
echo "Installing Display Fixes & Ngrok..."
brew install --cask ngrok
brew install displayplacer cliclick

# 3. إجبار النظام على إنشاء شاشة وهمية بدقة 1080p [cite: 6]
# هذا الأمر ضروري جداً لتفعيل كارت الشاشة
displayplacer "id:F466F621-B5FA-4719-9436-D087A4F6E626 res:1920x1080 scaling:on origin:(0,0) degree:0"

# 4. تعطيل الفهرسة وتوفير الطاقة
sudo mdutil -i off -a

# 5. إنشاء المستخدم الجديد (usertestddd)
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

# 6. تفعيل VNC وإعداد كلمة المرور
# نستخدم Perl لعمل تشفير للباسورد لملف الإعدادات
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -allowAccessFor -allUsers -privs -all
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -clientopts -setvnclegacy -vnclegacy yes 

echo $USER_PASS | perl -we 'BEGIN { @k = unpack "C*", pack "H*", "1734516E8BA8C5E2FF1C39567390ADCA"}; $_ = <>; chomp; s/^(.{8}).*/$1/; @p = unpack "C*", $_; foreach (@k) { printf "%02X", $_ ^ (shift @p || 0) }; print "\n"' | sudo tee /Library/Preferences/com.apple.VNCSettings.txt

# 7. إعادة تشغيل خدمات التحكم عن بعد وتنشيط الشاشة
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -restart -agent -console
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate

# 8. تشغيل ngrok
ngrok authtoken $NGROK_TOKEN
ngrok tcp 5900 --region=in &
