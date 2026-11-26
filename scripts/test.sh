#!/bin/bash
# Runs the unit tests without Xcode: compiles Shared/ + MacLockTests/ with Swift Testing.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=build/cli/tests; mkdir -p "$OUT"
DEV=$(xcode-select -p)
FW="$DEV/Library/Developer/Frameworks"
LIB="$DEV/Library/Developer/usr/lib"
xcrun swiftc -target arm64-apple-macosx26.0 -swift-version 6 -parse-as-library -module-name MacLockTests \
  -F "$FW" -I "$LIB" -L "$LIB" -plugin-path "$DEV/usr/lib/swift/host/plugins/testing" -Xlinker -rpath -Xlinker "$FW" -Xlinker -rpath -Xlinker "$LIB" \
  $(find Shared MacLockTests -name '*.swift') scripts/TestMain.swift -o "$OUT/MacLockTests"
"$OUT/MacLockTests"
