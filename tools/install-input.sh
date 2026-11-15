#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT="$ROOT/build/TelexMini.app"
TARGET="$HOME/Library/Input Methods/TelexMini.app"
BACKUP="$ROOT/build/TelexMini-previous-input.app"
STAGING="$HOME/Library/Input Methods/.TelexMini-next.app"
test -d "$INPUT" || { echo "Run bash tools/build.sh first" >&2; exit 2; }
if pgrep -x "TelexMiniInput" >/dev/null; then
  echo "ERROR: TelexMiniInput is running; select another input source and close it before upgrading." >&2
  exit 3
fi
codesign --verify --deep --strict "$INPUT"
plutil -lint "$INPUT/Contents/Info.plist"
mkdir -p "$HOME/Library/Input Methods"
rm -rf "$STAGING"
ditto "$INPUT" "$STAGING"
codesign --verify --deep --strict "$STAGING"
# Backup the previous bundle. Never overwrite a running input method binary.
if [[ -d "$TARGET" ]]; then
  rm -rf "$BACKUP"
  ditto "$TARGET" "$BACKUP"
  rm -rf "$HOME/Library/Input Methods/.TelexMini-old.app"
  mv "$TARGET" "$HOME/Library/Input Methods/.TelexMini-old.app"
fi
if ! mv "$STAGING" "$TARGET"; then
  if [[ -d "$HOME/Library/Input Methods/.TelexMini-old.app" ]]; then
    mv "$HOME/Library/Input Methods/.TelexMini-old.app" "$TARGET"
  fi
  echo "ERROR: failed to activate the new input bundle; old version restored" >&2
  exit 4
fi
rm -rf "$HOME/Library/Input Methods/.TelexMini-old.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then "$LSREGISTER" -f "$TARGET" || true; fi
swiftc -framework Carbon "$ROOT/tools/RegisterInput.swift" -o "$ROOT/build/telexmini-register"
"$ROOT/build/telexmini-register" "$TARGET"
echo "INSTALLED_INPUT=$TARGET"
echo "PREVIOUS_BACKUP=$BACKUP"
echo "WARNING: Never force logout; select the input source manually after re-login if needed."
