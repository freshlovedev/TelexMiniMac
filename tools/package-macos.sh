#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT="$ROOT/build/TelexMini.app"
SETTINGS="$ROOT/build/TelexMini Settings.app"
STAGE="$ROOT/build/TelexMini-macOS"
ARCHIVE="$ROOT/build/TelexMini-macOS.zip"

for app in "$INPUT" "$SETTINGS"; do
  if [[ ! -d "$app" ]]; then
    echo "ERROR: Missing built bundle: $app" >&2
    echo "Build both native and Flutter bundles using tools/build.sh first." >&2
    exit 1
  fi
  codesign --verify --deep --strict "$app"
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist"
done

rm -rf "$STAGE" "$ARCHIVE"
mkdir -p "$STAGE"
ditto "$INPUT" "$STAGE/TelexMini.app"
ditto "$SETTINGS" "$STAGE/TelexMini Settings.app"
cat > "$STAGE/INSTALL.txt" <<'EOF'
TelexMini for macOS — native Vietnamese input + shared Flutter Settings UI
============================================================================
1. Move TelexMini.app to ~/Library/Input Methods (create directory if needed).
2. Sign out and sign back in when macOS requests it.
3. Enable TelexMini in System Settings > Keyboard > Input Sources.
4. Open TelexMini Settings.app to configure V/E, Telex/VNI and dictionaries.

The TelexMini.app bundle is the native InputMethodKit keyboard engine.
The TelexMini Settings.app bundle is the shared Flutter user interface.
Both must be kept installed. Do not rename or edit files inside bundles.

These are local development builds with ad-hoc signing, NOT notarized
distribution packages. For public distribution, Developer ID signing and
Apple notarization are required.

Settings and user dictionaries remain local to this Mac.
EOF
ditto -c -k --sequesterRsrc --keepParent "$STAGE" "$ARCHIVE"
test -s "$ARCHIVE"
echo "MACOS_ARCHIVE=$ARCHIVE"
du -sh "$STAGE" "$ARCHIVE"
file "$INPUT/Contents/MacOS/TelexMiniInput"
file "$SETTINGS/Contents/MacOS/TelexMini Settings"
