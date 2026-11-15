#!/usr/bin/env bash
# IBus protocol checks in a private input context and config directory.
# The original desktop engine is restored even when the test fails.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="$ROOT/build/linux-native"
ENGINE="$BUILD/ibus/telexmini-ibus"
CONFIG="$BUILD/ibus-qa-config"
LOG="$BUILD/ibus-qa.log"
mkdir -p "$CONFIG"
test -x "$ENGINE"
command -v ibus >/dev/null
command -v python3 >/dev/null
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
# The CLI may report "No global engine" even while the IBus daemon is
# healthy. Query via GI and preserve the prior user's engine explicitly.
ORIGINAL="$(python3 -c 'import gi;gi.require_version("IBus","1.0");from gi.repository import IBus;IBus.init(); b=IBus.Bus(); e=b.get_global_engine(); print(e.get_name() if e else "")' 2>/dev/null || true)"
if [[ -z "$ORIGINAL" ]]; then
  ORIGINAL="xkb:us::eng"
fi
# Separate from the user's actual Flutter UI preference files.
printf '[TelexMini]\nVietnameseEnabled=true\nInputMethod=Telex\nSmartEnglish=true\nRestoreInvalid=true\nLanguagePriority=Balanced\n' \
  > "$CONFIG/preferences.ini"
export TELEXMINI_QA_CONFIG_DIR="$CONFIG"
export TELEXMINI_CONFIG_DIR="$CONFIG"
export TELEXMINI_LEXICON_PATH="$ROOT/Resources/english-core.txt"
"$ENGINE" > "$LOG" 2>&1 &
PID=$!
cleanup() {
  # IBus unregisters the transient engine when its process exits and can
  # clear the global selection. STOP the test service FIRST, then restore.
  if kill -0 "$PID" 2>/dev/null; then kill "$PID" 2>/dev/null || true; fi
  wait "$PID" 2>/dev/null || true
  python3 -c 'import gi,sys;gi.require_version("IBus","1.0");from gi.repository import IBus;IBus.init(); b=IBus.Bus(); assert b.set_global_engine(sys.argv[1]); e=b.get_global_engine();assert e and e.get_name()==sys.argv[1]' "$ORIGINAL" >/dev/null 2>&1 || echo "WARNING: IBus original engine restoration failed" >&2
}
trap cleanup EXIT
sleep 1
python3 "$ROOT/linux_ime/tests/ibus_integration.py"
echo "IBUS_DESKTOP_ENGINE_RESTORE=$ORIGINAL"
