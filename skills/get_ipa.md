# Build IPA for TestFlight

## Quick Start

Run these commands from the project root:

```bash
# Step 1: Archive
xcodebuild -project OnTimeAlarm.xcodeproj \
  -scheme OnTimeAlarm \
  -destination 'generic/platform=iOS' \
  -archivePath ./Transporter_Ready/OnTimeAlarm.xcarchive \
  archive

# Step 2: Export IPA
xcodebuild -exportArchive \
  -archivePath ./Transporter_Ready/OnTimeAlarm.xcarchive \
  -exportPath ./Transporter_Ready \
  -exportOptionsPlist ExportOptions.plist
```

## Output

IPA file location: `./Transporter_Ready/OnTimeAlarm.ipa`

## Upload to TestFlight

1. Open **Transporter** app
2. Drag `./Transporter_Ready/OnTimeAlarm.ipa` into the window
3. Click **Deliver**
4. Check [App Store Connect](https://appstoreconnect.apple.com) → Your App → TestFlight for the build

### CLI Upload (Alternative)

```bash
# Using API Key (create at App Store Connect → Integrations → API Keys)
xcrun altool --upload-app \
  -f ./Transporter_Ready/OnTimeAlarm.ipa \
  -t ios \
  --apiKey YOUR_API_KEY_ID \
  --apiIssuer YOUR_ISSUER_ID
```

## ExportOptions.plist

Create this file in the project root if it doesn't exist:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>export</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

## Troubleshooting

- **Signing error**: Ensure your Apple Developer account is signed in to Xcode and you have a valid distribution certificate
- **Provisioning error**: Check that your app's bundle ID is registered in App Store Connect
- **Archive fails**: Run `xcodebuild clean` first, then retry
- **Transporter error**: Verify the IPA was exported with `method` set to `app-store-connect` in ExportOptions.plist
