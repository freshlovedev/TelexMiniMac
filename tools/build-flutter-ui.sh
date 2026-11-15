#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/flutter_ui"
OUT="$APP/build/macos/Build/Products/Release/TelexMini Settings.app"

cd "$APP"
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter build macos --release

if [[ ! -d "$OUT" ]]; then
  echo "ERROR: Flutter macOS app bundle not found: $OUT" >&2
  find "$APP/build/macos/Build/Products/Release" -maxdepth 2 -name '*.app' -print >&2 || true
  exit 1
fi

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$OUT/Contents/Info.plist")
if [[ "$BUNDLE_ID" != "com.telexmini.mac.settings" ]]; then
  echo "ERROR: Unexpected bundle identifier: $BUNDLE_ID" >&2
  exit 1
fi

echo "FLUTTER_MACOS_APP=$OUT"
echo "BUNDLE_ID=$BUNDLE_ID"
du -sh "$OUT"
