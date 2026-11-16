#!/usr/bin/env bash
# Reproducible Linux user-only bundle assembled from verified Ubuntu builds.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/build/TelexMini-Linux-x86_64"
ARCHIVE="$ROOT/build/TelexMini-Linux-x86_64.tar.gz"
test -x "$ROOT/build/linux/TelexMini/telexmini"
test -x "$ROOT/build/linux-native/ibus/telexmini-ibus"
test -f "$ROOT/build/linux-native/ibus/telexmini.xml"
test -f "$ROOT/build/linux-native/fcitx5/libtelexmini.so"
test -f "$ROOT/Resources/english-core.txt"
bash -n "$ROOT/tools/install-linux-user.sh"
if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
  echo "Linux x86_64 build host required" >&2; exit 2
fi
if ldd "$ROOT/build/linux/TelexMini/telexmini" | grep -q "not found"; then
  echo "Missing Flutter executable runtime dependency" >&2; exit 3
fi
if ldd "$ROOT/build/linux-native/ibus/telexmini-ibus" | grep -q "not found"; then
  echo "Missing IBus runtime dependency" >&2; exit 3
fi
if ldd "$ROOT/build/linux-native/fcitx5/libtelexmini.so" | grep -q "not found"; then
  echo "Missing Fcitx5 runtime dependency" >&2; exit 3
fi
rm -rf "$DEST"
mkdir -p "$DEST/build/linux/TelexMini" "$DEST/build/linux-native/ibus" "$DEST/build/linux-native/fcitx5" "$DEST/tools" "$DEST/linux_ime/fcitx5" "$DEST/Resources" "$DEST/linux_ime"
cp -a "$ROOT/build/linux/TelexMini/." "$DEST/build/linux/TelexMini/"
cp -a "$ROOT/build/linux-native/ibus/telexmini-ibus" "$ROOT/build/linux-native/ibus/telexmini.xml" "$DEST/build/linux-native/ibus/"
cp -a "$ROOT/build/linux-native/fcitx5/libtelexmini.so" "$DEST/build/linux-native/fcitx5/"
cp -a "$ROOT/linux_ime/fcitx5/telexmini-addon.conf" "$ROOT/linux_ime/fcitx5/telexmini.conf" "$DEST/linux_ime/fcitx5/"
cp -a "$ROOT/Resources/english-core.txt" "$DEST/Resources/"
cp -a "$ROOT/tools/install-linux-user.sh" "$DEST/tools/"
cp -a "$ROOT/linux_ime/README.md" "$DEST/linux_ime/"
cat > "$DEST/INSTALL.txt" <<EOF
TelexMini Linux x86_64 - user-only install
Extract this archive, open a terminal in its TelexMini-Linux-x86_64 directory:
  bash tools/install-linux-user.sh install
No sudo/admin is needed. Select the input source in GNOME/IBus or Fcitx5 settings.
Uninstall while preserving personal dictionaries:
  bash tools/install-linux-user.sh uninstall
EOF
tar -C "$ROOT/build" -czf "$ARCHIVE" "TelexMini-Linux-x86_64"
tar -tzf "$ARCHIVE" >/dev/null
echo "LINUX_BUNDLE=$ARCHIVE"
sha256sum "$ARCHIVE"
du -h "$ARCHIVE"
