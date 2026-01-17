# Run OnTimeAlarm in iOS Simulator

## Quick Commands

### Build and Run
```bash
cd "/Users/fabianbuenrostro/Cursor Projects/Antigravity/On Time Alarm" && xcodegen generate && xcodebuild -scheme OnTimeAlarm -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build && xcrun simctl boot "iPhone 16 Pro" 2>/dev/null || true && open -a Simulator && xcrun simctl install "iPhone 16 Pro" ~/Library/Developer/Xcode/DerivedData/OnTimeAlarm-cllodkhnyzsaszaigyxcouggbdri/Build/Products/Debug-iphonesimulator/OnTimeAlarm.app && xcrun simctl launch "iPhone 16 Pro" com.antigravity.OnTimeAlarm
```

### Run Only (already built)
```bash
xcrun simctl boot "iPhone 16 Pro" 2>/dev/null || true && open -a Simulator && xcrun simctl install "iPhone 16 Pro" ~/Library/Developer/Xcode/DerivedData/OnTimeAlarm-cllodkhnyzsaszaigyxcouggbdri/Build/Products/Debug-iphonesimulator/OnTimeAlarm.app && xcrun simctl launch "iPhone 16 Pro" com.antigravity.OnTimeAlarm
```

### Build Only
```bash
cd "/Users/fabianbuenrostro/Cursor Projects/Antigravity/On Time Alarm" && xcodegen generate && xcodebuild -scheme OnTimeAlarm -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

## App Info
- **Bundle ID**: `com.antigravity.OnTimeAlarm`
- **Simulator**: iPhone 16 Pro
- **Min iOS**: 17.0
