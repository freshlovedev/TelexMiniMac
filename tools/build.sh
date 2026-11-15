#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"
FLUTTER_SETTINGS="$ROOT/flutter_ui/build/macos/Build/Products/Release/TelexMini Settings.app"
mkdir -p "$BUILD"

# Native input-method regression suite must pass before replacing any app bundle.
swiftc -swift-version 5 "$ROOT/Sources/ProductivityCore.swift" "$ROOT/Sources/SpellAdvisor.swift" "$ROOT/Sources/TelexComposer.swift" "$ROOT/Tests/EngineTests.swift" -o "$BUILD/telexmini-engine-tests"
(cd "$(dirname "$ROOT")" && "$BUILD/telexmini-engine-tests")

# One shared Flutter desktop UI; this script also runs Dart analysis and widget tests.
bash "$ROOT/tools/build-flutter-ui.sh"
if [[ ! -d "$FLUTTER_SETTINGS" ]]; then
  echo "ERROR: Flutter Settings app bundle missing: $FLUTTER_SETTINGS" >&2
  exit 1
fi

rm -rf "$BUILD/TelexMini.app" "$BUILD/TelexMini Settings.app" "$BUILD/TelexMini.iconset"
INPUT="$BUILD/TelexMini.app"
SETTINGS="$BUILD/TelexMini Settings.app"
mkdir -p "$INPUT/Contents/MacOS" "$INPUT/Contents/Resources"
cp -R "$FLUTTER_SETTINGS" "$SETTINGS"
cp "$ROOT/Resources/Input-Info.plist" "$INPUT/Contents/Info.plist"
cp "$ROOT/Resources/english-core.txt" "$INPUT/Contents/Resources/english-core.txt"

# Compile a universal native input engine, matching the universal Flutter UI.
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target "${arch}-apple-macosx13.0" \
    -parse-as-library -framework AppKit -framework InputMethodKit \
    "$ROOT/Sources/ProductivityCore.swift" "$ROOT/Sources/TelexComposer.swift" "$ROOT/Sources/InputMain.swift" \
    -o "$BUILD/TelexMiniInput-${arch}"
done
lipo -create -output "$INPUT/Contents/MacOS/TelexMiniInput" \
  "$BUILD/TelexMiniInput-arm64" "$BUILD/TelexMiniInput-x86_64"
NATIVE_ARCHS=$(lipo -archs "$INPUT/Contents/MacOS/TelexMiniInput")
if [[ " $NATIVE_ARCHS " != *" arm64 "* || " $NATIVE_ARCHS " != *" x86_64 "* ]]; then
  echo "ERROR: Native IMK binary is missing arm64 or x86_64: $NATIVE_ARCHS" >&2
  exit 1
fi

# Use the same minimal teal T identity for the native input-method bundle.
swiftc -O -swift-version 5 -parse-as-library -framework AppKit \
    "$ROOT/tools/MakeIcon.swift" -o "$BUILD/telexmini-makeicon"
"$BUILD/telexmini-makeicon" "$ROOT/Resources/TelexMini-Icon-Teal.png" "$BUILD/icon-1024.png"
mkdir -p "$BUILD/TelexMini.iconset"
for size in 16 32 128 256 512; do
  sips -s format png -z "$size" "$size" "$BUILD/icon-1024.png" --out "$BUILD/TelexMini.iconset/icon_${size}x${size}.png" >/dev/null
  twice=$((size*2))
  sips -s format png -z "$twice" "$twice" "$BUILD/icon-1024.png" --out "$BUILD/TelexMini.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$BUILD/TelexMini.iconset" -o "$BUILD/TelexMini.icns"
cp "$BUILD/TelexMini.icns" "$INPUT/Contents/Resources/TelexMini.icns"

# Local-only ad-hoc signatures. Distribution still requires Developer ID + notarization.
codesign --force --sign - --timestamp=none "$INPUT"
codesign --force --sign - --timestamp=none --deep "$SETTINGS"
plutil -lint "$INPUT/Contents/Info.plist" "$SETTINGS/Contents/Info.plist"
codesign --verify --deep --strict "$INPUT"
codesign --verify --deep --strict "$SETTINGS"

INPUT_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INPUT/Contents/Info.plist")
SETTINGS_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SETTINGS/Contents/Info.plist")
if [[ "$INPUT_ID" != "com.telexmini.mac.input" || "$SETTINGS_ID" != "com.telexmini.mac.settings" ]]; then
  echo "ERROR: Unexpected app bundle identifiers: $INPUT_ID / $SETTINGS_ID" >&2
  exit 1
fi

echo "BUILT INPUT: $INPUT"
echo "BUILT SETTINGS (Flutter): $SETTINGS"
echo "INPUT_BUNDLE_ID=$INPUT_ID"
echo "SETTINGS_BUNDLE_ID=$SETTINGS_ID"
du -sh "$INPUT" "$SETTINGS"
echo "NOTE: For manual test install input .app under ~/Library/Input Methods then enable via System Settings."
