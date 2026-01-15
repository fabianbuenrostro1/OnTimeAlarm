---
description: Build and Run OnTimeAlarm on iPhone Simulator
---
// turbo-all

1. Boot the Simulator
```bash
xcrun simctl boot "iPhone 16 Pro" || true
open -a Simulator
```

2. Build the App
```bash
cd "/Users/fabianbuenrostro/Cursor Projects/Antigravity/On Time Alarm"
xcodegen generate
xcodebuild -project OnTimeAlarm.xcodeproj -scheme OnTimeAlarm -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

3. Install and Launch
```bash
# Find the built app path
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "OnTimeAlarm.app" -path "*/Build/Products/Debug-iphonesimulator/*" | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "Could not find built app"
    exit 1
fi

echo "Installing $APP_PATH..."
xcrun simctl uninstall "iPhone 16 Pro" com.antigravity.OnTimeAlarm || true
xcrun simctl install "iPhone 16 Pro" "$APP_PATH"
xcrun simctl launch "iPhone 16 Pro" com.antigravity.OnTimeAlarm
```
