#!/usr/bin/env bash
# Builds a release binary and wraps it in build/LockedInReader.app
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/LockedInReader.app"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/LockedInReader"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/LockedInReader"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Locked In Reader</string>
    <key>CFBundleDisplayName</key><string>Locked In Reader</string>
    <key>CFBundleIdentifier</key><string>com.lockedinreader.app</string>
    <key>CFBundleExecutable</key><string>LockedInReader</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $APP"
echo "Install with: cp -R $APP /Applications/"
