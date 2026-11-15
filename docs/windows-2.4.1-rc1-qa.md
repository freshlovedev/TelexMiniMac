# TelexMini Windows 2.4.1-rc.1 — Release Candidate QA

**Date:** 2026-11-16 (Asia/Ho_Chi_Minh)
**Scope:** Windows x64 only. macOS and Linux were not rebuilt or retested.
**Release status:** Candidate for user acceptance; **not published**.

## Phase 1 — Windows lifecycle and input safety

- Retained the per-user keyboard Hook + C++ Telex/VNI composer; no TSF
  registration, administrator access, global elevated service or UAC prompt.
- Stable executable remains at
  `%LOCALAPPDATA%\Programs\TelexMini\TelexMini.exe`.
  All Flutter assets are copied to the canonical install.
- Upgrade from an **already updated RC** requests graceful tray shutdown
  through a named per-user event, waits for the singleton mutex to release,
  updates the canonical bundle and restarts exactly one instance.
  Upgrading from a **legacy build without that event** may require exiting
  the old tray instance once; the updater does not force-kill that process.
- The updater refuses to replace the bundle while its Flutter Settings
  process is still running, protecting unsaved edits.
- Flutter Settings has a separate per-user singleton mutex, verified by
  launching twice and observing a single responsive process.
- No duplicate notification icons after upgrade: Windows showed exactly
  **one TelexMini tray-history registry entry** associated with the stable
  executable. This count excludes other applications.

## Phase 2 — Input integration

The existing independent native regression corpus passed without errors
(43,788 native C++ oracle cases and the C# regression suite).

**Visible Windows GUI:** 35/35 integration scenarios passed, 0 failures.
The harness displays a WinForms TextBox or PasswordBox and sends controlled
test-only `SendInput` events. The dedicated Keyboard instance explicitly
enables injected input **for this test only**. The installed production engine
continues to reject synthesized key events. Scenarios included:

- Vietnamese spelling: `w→ư`, `now→nơ`, `ow→ơ`, `uw→ư`,
  `boons→bốn`, `been→bên`, `ddang→đang`, `chayj→chạy`,
  and tone placement for `tieengs`.
- English protection: `boost`, `parameter`, `exe`, `windows`;
  manual English-exact mode kept `now` unchanged.
- Boundaries and editing: spaces, punctuation, tabs, Backspace,
  snippet expansion and undo.
- A real Windows password-style edit control kept raw `as`, rather than
  converting it to accented Vietnamese.
- The visible GUI test **requires the Start button** after the test window
  is foregrounded to avoid losing its first synthetic key during focus change.
- Tests restored the original user preferences and restarted the stable
  tray engine. No user document contents were read or logged.

**Coverage limitation:** These are visible synthetic-key integration tests,
not human physical-key trials in Chrome, Microsoft Word, VS Code, or a
terminal. Those compatibility cases remain part of user acceptance testing.

## Phase 3 — Performance and DPI

- Flutter widget tests: **23/23 passed**; Flutter analyzer passed.
- Tested layouts at Windows logical DPI scales 100%, 125% and 150%.
  Compact navigation retains access to all pages, and the dictionary
  page scrolls rather than overflowing at small logical heights.
- Added timing-only on-demand Hook callback p95/p99 diagnostics to the
  existing average/max metrics, with a bounded 2,048-sample buffer.
  **No key codes or typed text are stored** by these metrics.
- Portable synthetic performance benchmark (100,000 stress words;
  **0 failures**) on the existing Windows test environment:

  | Metric | p95 | p99 |
  |---|---:|---:|
  | Compose + edit plan per word | 79.9 µs | 151.2 µs |
  | Native C++ bridge per word | 118.0 µs | 757.9 µs |
  | Cached app-profile lookup | 0.4 µs | 0.6 µs |

- Idle native engine observed **57.43 MB working set**, **37.79 MB private
  bytes**, and 0 CPU-seconds increase during one 4-second observation.
  These are specific observations, **not guarantees**.
- The live Hook diagnostic was verified to return five timing fields.
  It reported zero samples immediately after a clean restart, so **actual
  key-to-screen p95/p99 latency has not been established**. Synthetic
  compose/edit-plan timings must not be represented as physical latency.

## Phase 4 — Packaging and rollback

- Windows 2.4.1-rc.1 package passed the maintained release build guard,
  native tests, Flutter analyzer, Flutter widget tests, synthetic benchmark,
  and archive consistency verification.
- ZIP: `build\TelexMini-Windows-2.4.1-RC1.zip` (13,794,604 bytes;
  approximately 13.16 MiB).
- SHA-256 ZIP:
  `3A0BA944CB53FA293FA16E36078184872BD194DF22A3BA6306ED91A83C73134A`
- SHA-256 `TelexMini.exe`:
  `B3F1687B2F7CCDD5EC0C8E3B3E3E49A0E0555164D1CE48FFD67301AB21505A54`
- Extracted the ZIP to a separate temporary QA directory, verified
  executable/DLL/Flutter assets, launched from that extracted bundle,
  and verified the canonical installed executable hash matched.
- Performed a **second update while RC was already running**:
  controlled shutdown and replacement succeeded, with exactly one
  running native tray process.
- Confirmed a single responsive Settings process and one Windows
  tray-history record for the app.
- Existing app-bundle rollback copy retained under:
  `%LOCALAPPDATA%\Programs\TelexMini.rollback-before-RC241`.
  User settings backup retained separately in
  `%LOCALAPPDATA%\TelexMini\preferences.before-RC241.ini`.
  Neither backup should be bundled in the release.

## Rollback for testers

1. Exit TelexMini from its tray and close the Settings window.
2. Rename `%LOCALAPPDATA%\Programs\TelexMini` to an unused suffix
   such as `TelexMini.failed-RC241`.
3. Copy the **contents** of
   `%LOCALAPPDATA%\Programs\TelexMini.rollback-before-RC241`
   back into a new `%LOCALAPPDATA%\Programs\TelexMini` folder.
4. Start `TelexMini.exe` from that canonical path.
   Preserve `%LOCALAPPDATA%\TelexMini` (dictionary, snippets, user prefs).

**Release decision:** Windows RC is ready for the user's acceptance testing;
do not claim full cross-application physical-key certification. **Commit
locally; do not push or publish this RC until acceptance.**
