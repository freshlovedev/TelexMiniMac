# TelexMini: user-mode desktop input (15 Nov 2026)

## Product design
Windows: ordinary-user Hook + portable C++ engine; no privileged input service.
macOS: original Swift TelexComposer + InputMethodKit in the user's
~/Library/Input Methods folder. Linux: user-installed IBus/Fcitx5 components
in ~/.local and portable Flutter UI. Flutter is the settings UI across
platforms; the OS-level input adapter is necessarily platform-specific.

## Verified
- Windows build: 0 native regression failures; 17 Flutter widget tests
  passed. Hook-only portable ZIP verified without privileged IME binaries.
- Windows system: old service profile unregistered, legacy processor
  registration removed, COM registration absent. Windows still holds
  three obsolete, inactive files under Program Files/TelexMini/TSF;
  ordinary-user deletion is forbidden, so those must be cleaned by the
  administrator after closing host processes or restarting Windows.
- macOS: restored original Swift TelexComposer and original IMK Info.plist;
  universal arm64/x86_64 bundle compiled and signed. User-local input
  app installed without sudo. Input source count is zero in this login
  session, so selecting it after logout/login remains unverified.
- Ubuntu 26.10: installed GUI, IBus engine, Fcitx5 addon under ~/.local
  using tools/install-linux-user.sh install as the normal desktop user.
  No sudo, no replacement of active input source. Previous isolated IBus
  integration tests passed 13/13 and Fcitx5 addon loading worked.
  User-local real typing in host applications still needs verification.

## Limitations
The user must select/enable input methods in OS keyboard settings. This is
distinct from privileged Administrator / Accessibility / Input Monitoring
grants.

A Windows low-level hook cannot be reused on macOS or Wayland Linux without
platform security limitations. Native input methods are the appropriate
user-mode alternative.

No release-ready certification without physical-keyboard tests and user
acceptance. Do not force an OS restart.
