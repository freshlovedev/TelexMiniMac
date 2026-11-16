# TelexMini cross-platform QA and parity — 16 November 2026

Shared Flutter Settings is built from one source tree, but every platform uses
its own native input method. **Building a platform's UI is not equivalent to
testing its actual text input in a host application.**

| Capability | Windows | macOS (InputMethodKit) | Linux (IBus / Fcitx5) |
| --- | --- | --- | --- |
| Responsive shared UI, About, inline examples, Typing Lab | Tested | Built + Flutter tests | Built + Flutter tests; launched visibly on GNOME Wayland |
| Vietnamese Telex/VNI and Balanced/Vietnamese/English priority | Tested | Native composer test + universal native bundle; source must be activated to test actual host input | Portable C++ 4,717 cases; IBus 21 protocol cases; Fcitx5 addon loaded |
| Editable English/Vietnamese dictionary | Tested | Native bridge, reload after explicit edit | XDG native bridge; IBus verified hot reload, Fcitx5 inotify implementation |
| Text expansion, V and E | Tested | InputMethodKit marked-text composition; source QA pending in host apps | IBus V/E expanded and tested; Fcitx5 implementation loads but not directly typed in host app |
| Snippet macros | date/time/datetime, clipboard, cursor + escaping | date/time/datetime + escaped newline/tab, clipboard only when triggered; cursor not supported | date/time/datetime + escaped newline/tab; clipboard/cursor not supported |
| Application-specific profiles | Native process list | Native app bundle identifiers | Fcitx5 context program identity; IBus does not reliably expose app ID |
| Terminal English fallback | Windows context | Built-in terminal bundle identifiers | Fcitx5 terminal program names; IBus app-ID limitation |
| Password field safeguard | Windows context-based bypass | IMK relies on native system secure-input routing | IBus password/private purpose tested; Fcitx5 password/sensitive capability |
| Auto-start | Existing Windows mechanism | macOS Login Items; user can withhold system approval | User-owned GNOME .desktop entry, explicitly opted-in; never selects input source |
| Instant repair after word, adaptive self-learning, smart punctuation | Native Windows | Not yet equivalent | Not yet equivalent |
| Expansion Smart Undo and {cursor} repositioning | Windows native | Not implemented; controls are not falsely shown | Not implemented; controls are not falsely shown |

## Verified builds/tests

- Windows source was committed/pushed previously (commit `0bef3ee`). Windows DDANG stability and real UI integration tests were performed in that release.
- macOS release uses `bash tools/build.sh` and `bash tools/package-macos.sh`, builds ad-hoc-signed universal arm64/x86_64 InputMethodKit and Flutter Settings bundles. The Swift composer tests and Flutter tests run via maintained build scripts. Input-source enablement in System Settings is still an explicit user step.
- Ubuntu 26.10 GNOME Wayland on the **pre-existing guest**, accessed by existing macOS SSH identity as the ordinary `utu` user, without root/sudo: portable C++ composer **4,717/4,717**; IBus test engine isolated under `telexmini-qa` **21/21**, covering Telex/VNI, priority, snippets in V/E, dictionary hot reload and password; Fcitx5 library builds and addon registers in isolated D-Bus; Flutter analyzer 0 issues, **34 widget tests passed**; GTK Linux release builds and renders visibly.
- `bash tools/install-linux-user.sh install` was executed without sudo. The installed GUI/IBus/Fcitx5 binaries were byte-compared against their verified builds. No user dictionary/config file existed in that guest at install time, so the initial empty checksum manifest cannot be used as proof of changed user data; no configuration content was removed. Autostart was **not enabled** automatically. User selection of an input source remains mandatory.
- Linux distribution built with `bash tools/package-linux.sh`: `build/TelexMini-Linux-x86_64.tar.gz`, containing only validated binaries/resources/user-only installer, not user data.

## Important non-claims / remaining release gates

1. IBus protocol automation verifies an isolated IME input context, not every Chrome/Firefox/GNOME text widget under human typing. Test additional host apps before advertising a production release.
2. Fcitx5 addon registration and load are **not** an end-to-end typing test in third-party applications; test its actual host text insertion, per-app profiles, terminal fallback, password handling and live reload.
3. macOS InputMethodKit universal build and Swift composer tests are **not** live typing tests in a third-party editor after input-source registration. The user must choose the TelexMini input source themselves.
4. Windows-only instant repair, adaptive learning, smart punctuation, and full snippet Smart Undo/cursor macros need separate OS-native implementations for actual parity. Their switches are hidden on unsupported systems and limits explained.
5. No elevated global keyboard hooks, TSF, Linux root services, Accessibility privilege bypass, or background clipboard monitoring have been added. Only explicitly triggered snippets may request clipboard on supported platforms.

This document is deliberately more conservative than saying "everything is identical" before native UI testing proves it.
