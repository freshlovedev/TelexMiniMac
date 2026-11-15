#!/usr/bin/env bash
# Isolated Fcitx5 QA: does not register a system input method, change
# the user's active desktop input method, or alter their configuration.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="$ROOT/build/linux-native"
STAGE="$BUILD/fcitx5-qa-stage"
CONFIG="$BUILD/fcitx5-qa-config"
LOG="$BUILD/fcitx5-smoke.log"
mkdir -p "$STAGE" "$CONFIG/fcitx5"
command -v fcitx5 >/dev/null
command -v gdbus >/dev/null
if fcitx5-remote --check >/dev/null 2>&1; then
  echo "Fcitx5 already runs in this desktop session. Do not replace it for QA." >&2
  exit 3
fi
cmake --install "$BUILD/fcitx5" --prefix "$STAGE" >/dev/null
test -f "$STAGE/share/fcitx5/addon/telexmini.conf"
test -f "$STAGE/lib/$(gcc -dumpmachine | sed 's/-gnu$//')/fcitx5/libtelexmini.so" ||
  find "$STAGE/lib" -name libtelexmini.so | grep -q .
# Set up a private input-method group, not ~/.config/fcitx5.
cat > "$CONFIG/fcitx5/profile" <<'PROFILE'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=telexmini
[Groups/0/Items/0]
Name=keyboard-us
Layout=
[Groups/0/Items/1]
Name=telexmini
Layout=
[GroupOrder]
0=Default
PROFILE
ADDON_LIB="$(dirname "$(find "$STAGE/lib" -name libtelexmini.so -print -quit)")"
SYSTEM_LIB="$(dirname "$(find /usr/lib -name libdbus.so -path '*/fcitx5/*' -print -quit)")"
if [[ -z "$SYSTEM_LIB" || -z "$ADDON_LIB" ]]; then
  echo "Fcitx5 libraries are unavailable" >&2
  exit 4
fi
export XDG_CONFIG_HOME="$CONFIG" XDG_DATA_HOME="$STAGE/share"
export FCITX_ADDON_DIRS="$ADDON_LIB:$SYSTEM_LIB"
export TELEXMINI_LEXICON_PATH="$ROOT/Resources/english-core.txt"
export TELEXMINI_CONFIG_DIR="$BUILD/fcitx5-private-preferences"
mkdir -p "$TELEXMINI_CONFIG_DIR"
# Process never claims GNOME IBus's service name; it is a separate Fcitx5 D-Bus service.
fcitx5 -D --disable=all --enable=keyboard,telexmini,dbus,dbusfrontend \
  --verbose=default=4 > "$LOG" 2>&1 &
PID=$!
cleanup() {
  if kill -0 "$PID" 2>/dev/null; then kill "$PID" 2>/dev/null || true; fi
  wait "$PID" 2>/dev/null || true
}
trap cleanup EXIT
for attempt in $(seq 1 40); do
  if grep -q "Loaded addon telexmini" "$LOG" &&
     gdbus call --session --dest org.fcitx.Fcitx5 --object-path /controller \
       --method org.fcitx.Fcitx.Controller1.AddonForIM telexmini \
       | grep -q "('telexmini',)"; then
    echo "FCITX5_ADDON_LOADED=PASS"
    gdbus call --session --dest org.fcitx.Fcitx5 --object-path /controller \
      --method org.fcitx.Fcitx.Controller1.InputMethodGroupInfo Default
    echo "FCITX5_DBUS_ADDON_REGISTRATION=PASS"
    exit 0
  fi
  sleep 0.25
done
tail -n 35 "$LOG" >&2
echo "FCITX5_ADDON_LOADED=FAIL" >&2
exit 1
