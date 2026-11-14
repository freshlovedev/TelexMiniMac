# TelexMini — Phases 2–4 implementation and release-readiness report
Date: 2026-11-14
Branch: main
Policy: commit only after tests; DO NOT push without a separate request.

## Phase 2 — Smart bilingual / profiles
- Existing offline Vietnamese/English composer remains the default; the Phase 1 core and 4,700-case Telex/VNI oracle are retained.
- New opt-in per-application profiles: `English` (preserve keystrokes), `Vietnamese` (disable English prefix protection) and `Balanced` (normal bilingual selection).
- Windows identifies the foreground process when the target window changes; macOS uses the frontmost application's bundle ID in InputMethodKit. Per-application rules are user-authored in `profiles.tsv`.
- User dictionaries remain local, with the existing in-app editor and import/export.
- **Not a new learned language model**: context-sensitive probability scoring and per-window V/E state memory are not yet implemented. Profiles are deterministic and offline.

## Phase 3 — Productivity
- Opt-in snippets: user-authored `snippets.tsv` with `latin-key<TAB>replacement`, expanded only at word boundaries. Shortcuts are restricted to ASCII alphabetic characters because the keyboard hook handles those reliably; 2–48 characters, up to 256 rules, 1,024-character replacement.
- `{date}` and `{time}` macros use local calendar/time at expansion and have unit tests.
- Quick Symbols picker opens on user request and copies the selected symbol; paste into the target app with Ctrl+V/Command+V. Does not read clipboard history.
- On-demand spelling suggestions use a deliberately small bundled list of Vietnamese terms and a bounded edit-distance search. **No automatic correction or background keystroke capture**.
- Existing repeat-key Telex escape, dictionary overrides, password fail-closed policies and Unicode composition are preserved.
- Integration across editors is not fully certified, see blockers below.

## Phase 4 — Desktop preview and portability
- Windows Portable Mode creates a `portable.flag` alongside `TelexMini.exe`, copies existing preferences/dictionaries/snippets/profiles to `Data/`, preserves the originals and requires app restart. Normal installed mode continues in `%LOCALAPPDATA%/TelexMini`. A switch back copies to the normal data location.
- Shared `telexmini-sync.tsv` transfers a whitelist of typing and UI settings through manual export/import, along with `snippets.tsv`, `profiles.tsv` and dictionaries. **This is manual file-based transfer; it does not automatically synchronize online.**
- Per-app profile identifiers are platform-specific (Windows exe name vs. macOS bundle ID) and must be entered separately.
- New preview packaging scripts produce `.zip` files plus SHA-256 digest files, always after the build guard. The scripts copy only app binaries and documentation, not user data.
- Update menu/button opens the public GitHub Releases page on user request. **No unattended download, auto-install or verified silent updater**; these would require a signed update channel.
- English/Vietnamese UI selector and translations for the primary macOS preferences controls are in place. Windows and some secondary macOS text remain Vietnamese: **full localization is not complete**.

## Automated tests and builds
- macOS Apple Silicon: **8,147 assertions, 0 failures** including 4,700 explicit Unicode oracle cases (Telex + VNI), 3,000 deterministic stress compositions, old regression cases, simulated multiword IMK composition, snippet/profile validation, date macro and spelling suggestions.
- Windows WinForms/.NET Framework: **Failures: 0**. All 4,700 oracle cases replayed into an isolated scratch document model via the same `TextEditPlan` as the actual hook; app context, productivity dialog, symbol picker, dictionary UI, config synchronization and offline suggestion tests passed.
- Both build scripts run tests before replacing built outputs; the canonical Windows EXE is not version-suffixed.
- Windows preview package integrity verified: `verify-preview.ps1` reported **HASH_MATCH=True** and checked archive contents for user private files. macOS `shasum -c` passed and `unzip -t` reported no errors.
- Import validation and atomic file replacement were added for cross-platform snippet/profile files. Existing user data is not deleted before an incoming file passes validation.

## Known release blockers
- Windows real SendInput-to-TextBox integration test still fails the **foreground ownership check** under the current Windows VM. The test stops safely. No claim of successful Word/Chrome/Edge/VS Code integration without testing them.
- macOS `TISRegisterInputSource` returns 0, but `SOURCE_COUNT=0` in this session; full TextEdit/Safari/Chrome/VS Code real typing must follow logout/login and source activation. We did not force a session logout.
- No commercial Developer ID notarization, Apple Universal 2 validation, Windows Authenticode signing, trusted auto-updater, or complete multi-app/multi-DPI accessibility verification.
- Spellcheck corpus is intentionally small; suggestions are offered only on request. Not a comprehensive Vietnamese spell checker.
- Portable Mode and cross-platform file sync have unit tests, but full user-driven migration/rollback testing remains to be completed before a commercial release.

## Preview locations
- Windows EXE: `D:\Softs\TelexMini\TelexMini.exe`
- Windows archive: `D:\Softs\TelexMini\dist\TelexMini-Windows-preview.zip`
- Mac bundle: `/Volumes/Kodak/projects/TelexMiniMac/build/TelexMini.app`
- Mac Settings bundle: `/Volumes/Kodak/projects/TelexMiniMac/build/TelexMini Settings.app`
- Mac archive: `/Volumes/Kodak/projects/TelexMiniMac/dist/TelexMini-macOS-preview.zip`

Never report these preview builds as a signed/notarized release.
