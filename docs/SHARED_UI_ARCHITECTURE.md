# TelexMini shared desktop architecture

## Direction

TelexMini uses one Flutter desktop application for the settings and dashboard UI on Windows, macOS and Linux. The input method remains native to each operating system.

- Flutter UI: dashboard, dictionaries, snippets, symbols, preferences, themes and localization.
- Windows adapter: Flutter Windows method channel -> shared preferences file -> existing C# keyboard engine.
- macOS adapter: Flutter macOS method channel -> `UserDefaults(suiteName: com.telexmini.mac)` and shared dictionary files -> existing InputMethodKit engine.
- Linux adapter: Flutter Linux method channel -> XDG config files -> planned Fcitx5 input method engine.

The Flutter channel contract is `com.telexmini/control`:

| Method | Purpose |
|---|---|
| `getStatus` | Read current V/E mode and native bridge availability |
| `setMode` | Switch Vietnamese/English mode |
| `applyPreferences` | Apply input method, language priority, safety and productivity options |
| `loadDictionary` | Load user-managed English or Vietnamese dictionary entries |
| `saveDictionary` | Persist user-managed dictionary entries |
| `reloadEngine` | Notify the native engine that dictionaries/settings changed |

## Current implementation status

### Shared Flutter UI
- Responsive desktop shell, sidebar, dashboard, mode card, dictionary editor, snippets, quick symbols and settings.
- Shared teal/navy visual identity and light/dark theme.
- Vietnamese/English UI strings.
- Local JSON settings store.
- Flutter targets scaffolded for macOS, Windows and Linux.

### macOS
- Measured Release bundles on the current build host: Flutter Settings app approximately 42 MB; native InputMethodKit app approximately 1.9 MB.
- Flutter method channel is connected to the existing InputMethodKit engine.
- Mode state, input method, language priority, dictionaries, snippets, excluded apps and profiles are mapped to the existing native storage.
- The input method reads the shared V/E state and dictionary reload signal.
- `tools/build.sh` builds the native input method and Flutter Settings app, both universal arm64/x86_64. `tools/package-macos.sh` verifies signatures and bundles them into a ~21 MB ZIP (local/ad-hoc signing only).

### Windows
- Flutter Windows runner method channel is compiled and running in the Windows 11 desktop workspace. The UI and C# input engine are shipped together.
- Native launcher `TelexMini.exe` stays in the tray and opens `TelexMiniSettings.exe` automatically; duplicate launches reopen the UI.
- Shared preferences in `%LOCALAPPDATA%\\TelexMini\\preferences.ini` support live V/E, Telex/VNI, dictionaries, productivity and startup settings.
- 450 ms Flutter mode monitoring reflects system hotkey changes; live CRLF preference parsing and native settings refresh were repaired and visually tested.
- The native C# suite passed its 4,700-case oracle; Flutter analysis + five widget tests passed; the live native E/V bridge smoke test passed and restored original user preferences.
- `windows/build-flutter-distribution.ps1` produces a ~27.1 MB directory and ~11.3 MB ZIP at `windows/build/TelexMini-Windows-x64.zip`.

### Linux
- Flutter Linux runner and method-channel file adapter are scaffolded.
- Preferences are stored under `$XDG_CONFIG_HOME/telexmini` (or `~/.config/telexmini`).
- Fcitx5 input-method engine is the planned native integration for X11 and Wayland.
- The Fcitx5 engine, Linux package and real desktop testing are not complete. The available Windows/macOS workspaces do not have a Linux desktop/Fcitx5 test environment. A Linux UI build script is provided at `tools/build-flutter-ui-linux.sh`, but it does not claim system-wide Vietnamese input support.

## Build commands

macOS shared UI:
```sh
cd flutter_ui
flutter analyze
flutter test
flutter build macos --release
```

Full macOS package (native InputMethodKit + shared Flutter Settings):
```sh
bash tools/build.sh
bash tools/package-macos.sh
```

Windows integrated native engine + Flutter UI release, from the `windows` directory:
```powershell
.\\build-flutter-distribution.ps1
.\\test-flutter-bridge.ps1  # Run with the packaged native engine already running
```

Linux after installing Flutter Linux desktop dependencies and Fcitx5 development packages:
```sh
cd flutter_ui
flutter pub get
flutter analyze
flutter test
flutter build linux --release
```

## Release gates

Do not replace or remove the existing native application until each platform passes:
1. Shared Flutter UI build and widget tests.
2. Native method-channel tests.
3. Telex/VNI regression corpus and dictionary tests.
4. Real keyboard input tests on the target OS.
5. Login/startup, tray/menu-bar and app lifecycle tests.
6. Packaged artifact inspection and size measurement.

The Linux Fcitx5 adapter must pass the same Telex/VNI regression corpus before being considered a supported input method.
