#!/usr/bin/env bash
# TelexMini user-only Linux install: no sudo, polkit, privileged hooks or UAC.
# Use IBus on GNOME, Fcitx5 in desktops that already use Fcitx5.
set -euo pipefail
ACTION="${1:-install}"
case "$ACTION" in install|uninstall) ;; *) echo "Use: $0 install|uninstall" >&2; exit 2;; esac
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_HOME="$HOME/.local/bin"
LIBEXEC_HOME="$HOME/.local/libexec"
LIB_HOME="$HOME/.local/lib/fcitx5"
APP_HOME="$HOME/.local/opt/telexmini"
F5_DIR="$DATA_HOME/fcitx5"
IBUS_DIR="$DATA_HOME/ibus/component"
ENV_FILE="$HOME/.config/environment.d/telexmini-fcitx5.conf"
AUTOSTART="$HOME/.config/autostart/telexmini-input-service.desktop"
PIDFILE="$HOME/.cache/telexmini-ibus-user.pid"
if [[ $EUID -eq 0 ]]; then
  echo "Run as an ordinary desktop user, never with sudo" >&2
  exit 3
fi
if [[ "$ACTION" == uninstall ]]; then
  # Remove only TelexMini-owned files. Preserve the user's dictionaries and
  # current input layout/selected source.
  for f in "$LIBEXEC_HOME/telexmini-ibus" "$LIBEXEC_HOME/telexmini-ibus-bin" \
           "$IBUS_DIR/telexmini.xml" "$LIB_HOME/libtelexmini.so" \
           "$F5_DIR/addon/telexmini.conf" "$F5_DIR/inputmethod/telexmini.conf" \
           "$BIN_HOME/telexmini" "$ENV_FILE" \
           "$DATA_HOME/applications/telexmini.desktop"; do
    rm -f "$f"
  done
  rm -f "$AUTOSTART"
  if [[ -f "$PIDFILE" ]]; then
    pid="$(cat "$PIDFILE")"
    if [[ "$pid" =~ ^[0-9]+$ ]] && ps -p "$pid" -o comm= 2>/dev/null | grep -q '^telexmini-ibus'; then
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$PIDFILE"
  fi
  rm -rf "$APP_HOME"
  echo "USER_ONLY_TELEXMINI_UNINSTALL=PASS"
  echo "CONFIG_AND_DICTIONARIES_PRESERVED=YES"
  exit 0
fi
APP="$ROOT/build/linux/TelexMini"
IBUS="$ROOT/build/linux-native/ibus"
FCITX="$ROOT/build/linux-native/fcitx5"
test -x "$APP/telexmini"
test -x "$IBUS/telexmini-ibus"
test -f "$IBUS/telexmini.xml"
test -f "$FCITX/libtelexmini.so"
mkdir -p "$LIBEXEC_HOME" "$BIN_HOME" "$IBUS_DIR" "$LIB_HOME" \
         "$F5_DIR/addon" "$F5_DIR/inputmethod" \
         "$DATA_HOME/telexmini" "$DATA_HOME/applications" \
         "$HOME/.config/environment.d" "$HOME/.config/autostart" \
         "$HOME/.cache" "$APP_HOME"
cp -a "$APP/." "$APP_HOME/"
install -m 755 "$IBUS/telexmini-ibus" "$LIBEXEC_HOME/telexmini-ibus-bin"
install -m 644 "$FCITX/libtelexmini.so" "$LIB_HOME/libtelexmini.so"
install -m 644 "$ROOT/linux_ime/fcitx5/telexmini-addon.conf" "$F5_DIR/addon/telexmini.conf"
install -m 644 "$ROOT/linux_ime/fcitx5/telexmini.conf" "$F5_DIR/inputmethod/telexmini.conf"
install -m 644 "$ROOT/Resources/english-core.txt" "$DATA_HOME/telexmini/english-core.txt"
cat > "$LIBEXEC_HOME/telexmini-ibus" <<WRAPPER
#!/bin/sh
export TELEXMINI_LEXICON_PATH="$DATA_HOME/telexmini/english-core.txt"
exec "$LIBEXEC_HOME/telexmini-ibus-bin" "\$@"
WRAPPER
chmod 755 "$LIBEXEC_HOME/telexmini-ibus"
# Point IBus at the user's own executable, without writing to /usr.
sed "s|<exec>.*</exec>|<exec>$LIBEXEC_HOME/telexmini-ibus --ibus</exec>|" \
   "$IBUS/telexmini.xml" > "$IBUS_DIR/telexmini.xml"
# Fcitx5 supports XDG data paths but addon library locations must be explicit.
SYS_LIB="/usr/lib/$(gcc -dumpmachine)/fcitx5"
printf 'FCITX_ADDON_DIRS=%s:%s\n' "$LIB_HOME" "$SYS_LIB" > "$ENV_FILE"
cat > "$BIN_HOME/telexmini" <<WRAPPER
#!/bin/sh
exec "$APP_HOME/telexmini" "\$@"
WRAPPER
chmod 755 "$BIN_HOME/telexmini"
# Keep the IBus component registered for the logged-in user. This is a
# normal desktop input service, not a global key-monitoring hook.
cat > "$AUTOSTART" <<DESKTOP
[Desktop Entry]
Type=Application
Name=TelexMini input service
Exec=$LIBEXEC_HOME/telexmini-ibus
NoDisplay=true
X-GNOME-Autostart-enabled=true
OnlyShowIn=GNOME;
DESKTOP
if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" && -n "${XDG_RUNTIME_DIR:-}" ]]; then
  if [[ ! -f "$PIDFILE" ]] || ! kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    nohup "$LIBEXEC_HOME/telexmini-ibus" > "$HOME/.cache/telexmini-ibus-user.log" 2>&1 </dev/null &
    echo $! > "$PIDFILE"
  fi
fi
cat > "$DATA_HOME/applications/telexmini.desktop" <<DESKTOP
[Desktop Entry]
Name=TelexMini
Exec=$BIN_HOME/telexmini
Type=Application
Terminal=false
Icon=input-keyboard
Categories=Utility;
DESKTOP
echo "USER_ONLY_TELEXMINI_INSTALL=PASS"
echo "SUDO_OR_ADMIN=NOT_USED"
echo "INPUT_SOURCE_NOT_CHANGED=YES"
echo "Choose TelexMini in the existing desktop input-source settings after login."
