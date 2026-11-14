# TelexMini — Phase 1 stability audit
Date: 2026-11-14
Branch: main
Status: source hardening and native build passed; end-to-end interoperability has open blockers.

## Scope completed in source

1. **Composition architecture.** Both the Swift `TelexComposer` and C# `TelexEngine` now isolate bilingual prefix selection from keyboard shape/tone composition. Telex and VNI composition have separate routines. These are staged refactors, **not** a wholesale rewrite of the input method transport.
2. **Independent Unicode oracle.** `Tests/telex-corpus.tsv` is an explicit expected-result file with 4,700 synthetic syllable tests: 10 onsets, 12 vowel nuclei (excluding standalone bare ă), four coda shapes, five tones, each in Telex and VNI. Windows has a mirrored `windows/telex-corpus.tsv` for standalone builds; keep the two files byte-identical. The corpus includes non-lexical combinations to test the compositor, not dictionary correctness.
3. **Regression suite.** Keeps the prior concrete words and failure reports: `as → á`, `ass → as`, `exe → exe`, `eex → ễ`, `kieeru → kiểu`, `nhieefu → nhiều`, `vaajy → vậy`, `chajy → chạy`, `xuosong → xuống`, `boosst → boost`, `been → bên`, `parameter`, `office`, VNI numeric identifiers, and 3,000 deterministic randomized compositions per platform.
4. **Windows input adapter.** Introduced `windows/TextEditPlan.cs`, the shared calculation of trailing backspaces and Unicode insertion. The actual low-level hook uses this plan. The 4,700 corpus inputs are replayed into a scratch document model with every intermediate edit and a final word boundary; additional scenarios exercise whole phrases, escapes, Backspace and mixed-language transitions. If Windows rejects **all** synthesized input events, the hook resets its state and lets the original physical key through instead of silently dropping it. A partially sent batch still raises an injection-failure signal and requires investigation.
5. **Release guards.** Both `tools/build.sh` and `windows/build.ps1` run their automated tests **before** replacing the native app/EXE. Failed tests stop the build; there is still just one `TelexMini.exe` on Windows.

## Verified

- macOS Apple Silicon Swift engine: **8,137 assertions, 0 failures**, including **4,700 oracle rows**, 3,000 stress compositions, marked-text client simulations and existing feature regressions. SwiftUI Settings app launched and visually captured; bundle metadata validated and ad-hoc signature verified.
- Windows desktop .NET Framework: `test.ps1` completed with **Failures: 0**. 4,700 Unicode oracle rows verified, each fed through a simulated text-field edit plan at every character and word boundary. Native hooks install/remove tests and password/terminal/foreground-policy unit tests passed. Invoking `test.ps1` from an unrelated temporary working directory also passed: the test script resolves its own source directory.
- macOS local installation path: `~/Library/Input Methods/TelexMini.app`. `TISRegisterInputSource` returned 0; **TISCreateInputSourceList (including disabled input sources) still returns zero matching sources in the current session**.

## Blocked or incomplete — not counted as passes

- **Windows actual SendInput-to-WinForms TextBox test:** explicitly attempted with a visible test form; Windows refused external foreground activation, and the test safely aborted with `FAIL integration aborted: test window lost foreground`. We did not bypass the safety guard or type into another foreground application. Chrome, Edge, Word, VS Code, chat apps and actual password fields are **not** end-to-end certified by these unit tests.
- **macOS actual IMK typing:** InputMethodKit source is not visible in the current login session. TextEdit/Safari/Chrome/VS Code and secure fields cannot be exercised until a macOS log-out/log-in refresh and the input source is enabled via System Settings → Keyboard → Text Input.
- No distribution signing/notarization, x86_64 macOS validation, DPI 125–200% / multi-display Windows matrix or extended long-duration hardware-soak run completed.

## Subsequent acceptance criteria

1. On Windows, use a clean virtual-machine session where the foreground WinForms scratch test can retain focus. Then check rich-text and browser editors with a disposable document, plus high-DPI and orientation/focus changes. Do **not** send test keys to existing user documents or remove the foreground safety check.
2. On macOS, refresh the login session without losing work, enable the TelexMini input source and test real marked-text composition and secure fields.
3. Only after those tests pass should the app be called ready for public release. Keep `main` local until the user explicitly requests pushing.

No typing history, passwords or real user content were written to this report or corpus.
