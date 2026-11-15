# TelexMini — shared Flutter desktop UI + native input engines

TelexMini is a local-first Vietnamese/English input utility. The desktop settings and dashboard are being consolidated into **one Flutter application** for Windows, macOS and Linux. The system-wide input engine remains native on each operating system so keyboard hooks, password-field safety, menu-bar/tray integration and input-method APIs are not forced through Flutter.

## Architecture

- **Shared Flutter UI:** dashboard, V/E mode, dictionaries, snippets, quick symbols, preferences, light/dark theme and Vietnamese/English interface.
- **Windows native engine:** existing C# keyboard hook and Telex/VNI core. The Flutter Windows runner writes the same local preferences and dictionary files; the C# host detects changes and applies them live.
- **macOS native engine:** existing InputMethodKit source. The Flutter macOS settings app uses a native method channel to share V/E state, preferences and user dictionaries with the IMK engine.
- **Linux target:** Flutter Linux runner and local settings bridge are scaffolded. A native Fcitx5 input-method engine is still required before Linux can be called a supported system-wide input method.

See [docs/SHARED_UI_ARCHITECTURE.md](docs/SHARED_UI_ARCHITECTURE.md) for the method-channel contract, platform status and release gates.

## Repository layout

```text
TelexMiniMac/
  Sources/                         # Native macOS InputMethodKit engine
  Resources/                       # Shared lexicon and brand assets
  Tests/                           # macOS composer regression suite
  windows/                         # Native Windows C# input engine and tests
  flutter_ui/                      # Shared Flutter UI + macOS/Windows/Linux runners
  docs/SHARED_UI_ARCHITECTURE.md    # Cross-platform architecture and current status
  tools/build.sh                   # Native macOS engine + Flutter Settings package
  tools/build-flutter-ui.sh        # Flutter macOS UI build
  tools/build-flutter-ui.ps1       # Flutter Windows UI build/package
  tools/build-flutter-ui-linux.sh  # Flutter Linux UI build/package
  tools/package-macos.sh           # macOS ZIP packaging and verification
```

## Build

### macOS

Requires Flutter, Xcode and Swift 5. From the repository root:

```bash
flutter --version
bash tools/build.sh
```

This runs the native Telex/VNI regression suite, Flutter analysis and widget tests, then builds:
- `build/TelexMini.app` — native universal InputMethodKit engine for arm64/x86_64 (approximately 1.9 MB on the current build host).
- `build/TelexMini Settings.app` — shared Flutter settings UI (approximately 42 MB on the current build host).

The settings app's method channel is connected to the native IMK engine. Both macOS executables contain arm64 and x86_64 slices. Run `bash tools/package-macos.sh` to create the roughly 21 MB macOS ZIP. These are locally ad-hoc signed builds; public distribution still needs Developer ID signing and notarization.

### Windows

The existing native engine can still be built and tested with the current scripts:

```powershell
cd windows
powershell -NoProfile -ExecutionPolicy Bypass -File .\test.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
```

To build the integrated Windows release, install Flutter and Visual Studio C++ desktop build tools, then run from the `windows` folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\\build-flutter-distribution.ps1
```

The release contains the existing native `TelexMini.exe` input engine and the shared `TelexMiniSettings.exe` Flutter UI. **Start `TelexMini.exe`**: the engine remains in the system tray and automatically opens the Flutter dashboard. Relaunching the native EXE reopens the dashboard without creating a second input engine. Without the co-located Flutter bundle, the native WinForms dashboard remains a fallback.

The release was compiled and visually inspected on Windows 11. The 4,700-case Telex/VNI oracle, Flutter analysis, five widget tests, one-instance reopening, and live native V/E bridge tests passed. The packaged folder measured roughly **27.1 MB**, and the **11.3 MB ZIP** is available at `windows/build/TelexMini-Windows-x64.zip`. After starting the integrated package, `windows/test-flutter-bridge.ps1` verifies V/E changes and restores original preferences byte-for-byte.

### Linux

The Flutter Linux UI target is scaffolded. On a Linux desktop with Flutter and the GTK development dependencies installed:

```bash
bash tools/build-flutter-ui-linux.sh
```

This builds the settings UI only. **System-wide Linux typing is not implemented yet.** The planned native adapter is a Fcitx5 engine for X11 and Wayland; it must port and pass the full Telex/VNI regression corpus and be tested on real GNOME/KDE desktops before release.

## Windows settings and dictionary bridge

The C# input engine reads settings from `%LOCALAPPDATA%\\TelexMini`, detects Flutter-written preference changes and applies V/E mode, Telex/VNI, language priority, productivity flags and auto-start without restarting. The Flutter dashboard polls native V/E mode every 450 ms while open, so hotkey changes are reflected without multi-second UI delays. The native fallback interface appears only when the co-located Flutter UI cannot launch.

## English typing reliability

The offline lexicon includes common development terms such as `parameter`, `parameters`, `parameterized`, `parameterization`, `parallel` and `parser`. With Smart English enabled, it protects **each prefix as you type**, not only the completed word. Regression tests assert that `p`, `pa`, `par`, `para`, ... remain unchanged through `parameter` and verify Vietnamese Telex examples still work.

### Immediate tone keys and placement (regression fix)

In **Vietnamese/Balanced mode**, an explicit Telex tone key must act **on the
current keystroke**, even if the raw keys happen to be an English prefix:
`a` → `as` displays **á** immediately, `ex` displays **ẽ**. Repeating the
tone key escapes it as before (`ass → as`). A new vowel after a tone-key
sequence cannot be treated as a late shaping command:
`exe → exe`, whereas `eex → ễ` (shape before tone).
Both engines test these intermediate outputs and their final word-boundary
results, so the English lexicon cannot silently swallow a user's accent.
A tone key can also precede the final vowel in a **valid Vietnamese diphthong**:
`chayj → chạy` and `chajy → chạy` both work. Crucially, the engine
tests the **composed Unicode syllable**, not the raw key sequence that
still contains shaping keys such as `ee`, `aa`, `ow`.
This prevents a mistaken English fallback after `kieer + u → kiểu`,
`nhieef + u → nhiều` or `vaaj + y → vậy`, while still treating
`ex + e → exe` literally. The regression suite includes both tone-key
orders, 30 accent/vowel combinations covering 6 syllable families and all
5 tone keys, and 3,000 deterministic stress compositions per platform.
These checks validate the core composer; they are not a substitute for
end-to-end typing tests in every desktop application.

### Immediate Telex shaping (smart bilingual)

When Vietnamese mode is on, a second vowel key now performs its Telex
transformation **immediately**, even when the raw letters look like an English
prefix. For example: `bo` → `boo` produces **bô** at the second `o`; `boon`
becomes **bôn** and `boons` becomes **bốn**. The same applies to `aa → â`
and `ee → ê`. English words such as `book`, `books`, `good` and `boost`
are recovered once recognized. Intermediate rendering of ambiguous English
words may temporarily show a Telex accent: this is unavoidable while also
requiring immediate, speculative Vietnamese accents.

### Vietnamese-first when an explicit Telex shape is valid

In Vietnamese mode, the user explicitly typing a vowel-shaping sequence takes
priority over an English dictionary match **when the resulting syllable is valid**.
For example, `been → bên`, `bee → bê`, `teen → tên`, and `seen → sên`
appear immediately and stay Vietnamese at word boundaries. English terms that
cannot form valid Vietnamese syllables, such as `book` and `good`, are
recovered as English. Fully ambiguous words (for example `boost → bốt`)
will now favor Vietnamese; select English mode to type those literally.

### Repeat a Telex key to cancel an accent (UniKey-style)

With Vietnamese mode enabled, **repeat the most recent effective Telex key**
to undo its change and continue the current word literally, without switching
to English mode. A repeat acts as an escape keystroke rather than adding the
duplicate character. Examples: `boons → bốn`, but `boosst → boost`;
`guitarr → guitar`; `ass → as`; `aaa → aa`, `eee → ee`,
`ooo → oo`, `ddd → dd`, and `uoww → uow`.
This also works after a final consonant when that consonant follows a Telex
tone command.

Some repeated letters could instead start an English word. If the next key
makes a recognized English prefix, the engine restores the repeated character:
`office` and `assets` still work normally. Legacy intentional escapes such
as `offfice → office` and `asssets → assets` are also retained. This
behavior remains local; no text history or cloud detection is involved.

### Smart Bilingual v2: algorithmic detection

The typing path now uses three **offline** signals, not just a list of known English words:

1. **Word/prefix dictionary:** known English words stay literal from the first character.
2. **Foreign onset detection:** tokens beginning with clearly non-Vietnamese clusters (e.g. `pr`, `fl`, `cr`, `wh`, `st`, or `p` followed by anything other than `h`) enter literal mode while typing, even when absent from the dictionary.
3. **Syllable impossibility check:** when a provisional Telex transformation can no longer form a Vietnamese syllable (such as a second vowel group after a consonant or an illegal coda), the engine immediately restores the original key sequence and keeps the rest of that token literal.

`VietnameseOverrides.txt` is checked as prefixes as well, so a custom Vietnamese sequence can override English detection **before** its final character. User-added English words still work as before. Tests cover unfamiliar English technical terms and immediate Vietnamese accent insertion with both implementations.

**Limitations:** Completely ambiguous prefixes can still temporarily acquire a Telex accent before later characters disambiguate them. Some unknown English words are also indistinguishable from valid Telex syllables; no purely local, letter-by-letter heuristic can always infer the intended language. For those, add a word to `EnglishWords.txt`, toggle Smart English or use per-word Vietnamese overrides. No typing data is uploaded or recorded.

## Privacy

Input processing is intended to remain fully local and offline. There is no network-based AI, keylogging archive or cloud telemetry built into the typing path. User-added words and options are local and excluded from Git. Avoid entering real passwords into any demonstration app.

## Telex shape/tone order independence

Telex vowel-shaping keys can appear **after** a tone key without switching to
English or losing the accent. In particular, `xuosong → xuống` (raw
`xuo + s + o + ng`) now produces the same composed syllable as
`xuoosng` and `xuoongs`. The same structural rule works for the other
five tone keys and similar vowel clusters, as long as the shaped syllable is
valid Vietnamese. It does not indiscriminately double vowels: `exe → exe`,
`eex → ễ`, and English words such as `book` remain unchanged.

Both Windows and macOS exercise 25 additional shape-after-tone
equivalence cases (5 vowel families × 5 tone keys), besides direct
regression cases for `xuosong`, `muosong`, `cuosong`, `xuofong`
and `xuorong`. The tests assert immediate composition and word-boundary
output; they do not substitute for end-to-end host-application typing tests.

## Typing Engine v3 and advanced settings

The Windows and macOS native engines support Telex (default) and optional VNI (1-5 tone, 6/7/8 vowel shapes, 9 for đ). The shared Flutter settings UI exposes input method, language priority (Balanced by default, Vietnamese-first or English-first), V/E shortcut, dictionaries, snippets and per-app profile controls where the native engine supports them. Linux will receive the same UI, but its Fcitx5 composition engine is still pending.

Regression coverage now includes 3,000 deterministic random compositions per platform, VNI numeric identifiers, Telex immediate accents, repeated escape keys and Backspace. **This does not establish application-level compatibility.** See [QA-RESULTS.md](QA-RESULTS.md) for tested behavior and outstanding Windows-focus / macOS-input-registration blockers.

## Phases 2–4: offline productivity and preview packaging

New opt-in features on Windows/macOS: per-app Vietnamese/English/Balanced
profiles, `snippets.tsv` text expansions with `{date}`/`{time}` macros,
on-demand spelling suggestions (small local list), and a Quick Symbols
picker. Nothing sends typed words to a service, learns passwords, or silently
rewrites text without an enabled snippet rule.

Settings transfer uses `telexmini-sync.tsv` plus explicit dictionaries,
snippets and profile files. Windows also supports an opt-in `portable.flag`
and `Data/` directory beside its one canonical EXE. Preview packagers:
`bash tools/package-preview.sh` on macOS and
`powershell -File windows/package-preview.ps1` on Windows; they create
ZIP archives and SHA-256 digest files without including private user data.
Updates are checked only when the user opens the GitHub Releases page.

**Read [PHASES-2-4-REPORT.md](PHASES-2-4-REPORT.md) before claiming release
readiness.** These are preview builds, not Developer ID-notarized or
Authenticode-signed commercial releases. Trusted automatic installation,
full UI localization, robust per-window mode memory and live integration
verification remain outstanding.

## Stability audit — Phase 1 (2026-11-14)

The core now separates bilingual classification from native Telex/VNI editing on
both platforms. A **4,700-row shared Unicode oracle** tests known results
independently of the composition logic (two identical corpus copies, for Mac
and standalone Windows builds). The Windows input hook shares a tested
`TextEditPlan` for computing Unicode tail replacements; it also fails open
when Windows rejects the entire synthetic-input batch. Both native build
scripts must pass their tests **before** replacing an executable.

See [PHASE1-REPORT.md](PHASE1-REPORT.md) for actual test totals, the Windows
foreground integration blocker and the macOS input-registration blocker.
These issues prevent claiming the app is end-to-end release-certified.

## Roadmap and release

See [windows/COMMERCIAL-ROADMAP.md](windows/COMMERCIAL-ROADMAP.md) for hardening and commercial-release gates. Separate app signing, notarization, end-to-end IME tests, updates, support and licensing are **not** shipped here.

## Git

```bash
cd TelexMiniMac
git status
git log -1 --oneline
# Add your own remote, then push manually when ready:
# git remote add origin <your-repository-url>
# git push -u origin main
```

Source is committed; generated EXEs/DMGs/apps, machine-specific settings and signing credentials are ignored. Git remotes are managed by the repository owner; no push is performed automatically.
