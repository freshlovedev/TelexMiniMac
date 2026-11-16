# TelexMini input backends: user-mode only

The desktop UIs remain Flutter. The OS-specific input adapters are selected
for normal-user operation, without an Administrator/root install.

* Windows: low-level keyboard hook and shared native C++ Telex/VNI composer.
  No TSF input service is built or registered.
* macOS: the original Swift TelexComposer with InputMethodKit. Installs in
  `~/Library/Input Methods/TelexMini.app` without `sudo`. User still needs
  to **enable/select the input source** in macOS Keyboard settings.
* Linux: IBus for GNOME and Fcitx5 for other desktops. These are regular
  desktop input-method frameworks, not global keyboard-capture hooks.
  User-owned files are installed to `~/.local`; no sudo needed.

## Linux user-only install (Ubuntu / GNOME)

Prerequisite: existing IBus or Fcitx5 is already installed on the OS.
Choose either the source build or packaged release as an ordinary user:

```bash
# Existing source checkout:
bash linux_ime/build.sh all
bash tools/build-flutter-ui-linux.sh
bash tools/package-linux.sh
bash tools/install-linux-user.sh install

# From TelexMini-Linux-x86_64.tar.gz:
tar xzf TelexMini-Linux-x86_64.tar.gz
cd TelexMini-Linux-x86_64
bash tools/install-linux-user.sh install
```

The installer updates binaries through staged directories and atomic moves,
without overwriting mapped binaries or editing user dictionaries.
Autostart is explicit and opt-in through Settings.

The user installer copies the GUI to `~/.local/opt/telexmini`, creates a
launcher under `~/.local/bin`, and registers the user-owned IBus descriptor
under `~/.local/share/ibus/component`. Fcitx5 descriptors, the addon library,
and a per-user environment.d configuration are also included. You may need
to **sign out/in and select TelexMini** in the input-source settings for the
desktop to load the new engine. These normal input-source selection steps
are **not permission grants**.

To uninstall without altering user dictionaries:

```bash
bash tools/install-linux-user.sh uninstall
```

This does not uninstall the system's IBus/Fcitx5 packages. Do not run it via
sudo. It never overrides the active desktop input source automatically.

## Verified on existing Ubuntu 26.10 test guest

* Native C++ composer: 4,717 portable cases passed.
* IBus: **21 integration cases passed**, including shortcuts in V/E,
  Telex/VNI and priority changes, dictionary reload and password handling
  in an isolated QA engine.
* Fcitx5: addon compiled and loaded in a private D-Bus test session; direct
  typing in third-party host apps still requires testing.
* Flutter UI: **34 widget tests passed**, analyzer zero issues, Linux release
  built and installed GUI visibly rendered on GNOME/Wayland.
* `tools/install-linux-user.sh install` passed as an ordinary user.
  GUI, IBus and Fcitx5 installed binaries byte-match verified builds.
  Autostart remained OFF; input-source activation after a fresh login still
  requires testing.
* Legacy .deb package created during development is deprecated because it
  requires sudo for system-wide installation.

**Important limitation:** a keyboard hook equivalent to Windows' global
WH_KEYBOARD_LL is not a reliable privilege-free approach on macOS or
Wayland Linux. InputMethodKit and IBus/Fcitx are native per-application input
interfaces. A user still must opt in by selecting the input source; there
is no responsible way to skip the operating system's selection controls.
