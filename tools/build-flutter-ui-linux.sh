#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/flutter_ui"
RELEASE="$APP/build/linux/x64/release/bundle"
DEST="$ROOT/build/linux/TelexMini"

cd "$APP"
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter build linux --release

if [[ ! -x "$RELEASE/telexmini" ]]; then
  echo "ERROR: Flutter Linux executable not found: $RELEASE/telexmini" >&2
  exit 1
fi

rm -rf "$DEST"
mkdir -p "$DEST"
cp -R "$RELEASE/." "$DEST/"
install -Dm644 "$APP/linux/telexmini.desktop" "$DEST/share/applications/telexmini.desktop"
install -Dm644 "$APP/linux/icons/telexmini.png" "$DEST/share/icons/hicolor/256x256/apps/telexmini.png"
echo "FLUTTER_LINUX_UI=$DEST"
du -sh "$DEST"
