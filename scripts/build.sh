#!/bin/bash
# Builds MacLock.app without Xcode, using only the Command Line Tools (swiftc + codesign).
# Mirrors the Xcode project's settings. Usage: scripts/build.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-debug}"
OUT="build/cli/$CONFIG"
APP="$OUT/MacLock.app"
TARGET="arm64-apple-macosx26.0"
IDENTITY="${CODESIGN_IDENTITY:-Apple Development}"
VERSION="0.1"; BUILD="1"

if [ "$CONFIG" = "release" ]; then
  OPT=(-O -whole-module-optimization)
else
  OPT=(-Onone -g -D DEBUG)
fi
COMMON=(-target "$TARGET" -swift-version 6 "${OPT[@]}")

rm -rf "$APP" "$OUT"/*.dSYM && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Library/LaunchDaemons" "$OUT/tmp"

echo "▸ Compiling daemon"
xcrun swiftc "${COMMON[@]}" -module-name MacLockDaemon \
  $(find MacLockDaemon Shared -name '*.swift') \
  -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker LaunchServices/daemon-Info.plist \
  -o "$APP/Contents/MacOS/MacLockDaemon"

echo "▸ Compiling app"
# Same as the Xcode target: main-actor default isolation + approachable concurrency.
xcrun swiftc "${COMMON[@]}" -module-name MacLock -parse-as-library \
  -default-isolation MainActor \
  -enable-upcoming-feature NonisolatedNonsendingByDefault \
  -enable-upcoming-feature InferIsolatedConformances \
  $(find MacLock Shared -name '*.swift') \
  -o "$APP/Contents/MacOS/MacLock"

# Debug symbols belong next to the app, not inside it.
mv "$APP/Contents/MacOS/"*.dSYM "$OUT/" 2>/dev/null || true

echo "▸ Bundling"
cp LaunchServices/com.maclock.daemon.plist "$APP/Contents/Library/LaunchDaemons/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key><string>com.maclock.app</string>
	<key>CFBundleName</key><string>MacLock</string>
	<key>CFBundleDisplayName</key><string>MacLock</string>
	<key>CFBundleExecutable</key><string>MacLock</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>$VERSION</string>
	<key>CFBundleVersion</key><string>$BUILD</string>
	<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
	<key>LSMinimumSystemVersion</key><string>26.0</string>
	<key>LSUIElement</key><true/>
	<key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
	<key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

echo "▸ Signing ($IDENTITY)"
# Inside-out: daemon first, then the app. Hardened Runtime on both, like the Xcode project.
codesign --force --options runtime --timestamp=none --sign "$IDENTITY" \
  --identifier com.maclock.daemon "$APP/Contents/MacOS/MacLockDaemon"
codesign --force --options runtime --timestamp=none --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"
echo "✓ $APP"
