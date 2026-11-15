# Linux native input integration

The shared Flutter desktop UI is scaffolded for Linux and its method channel writes preferences and user dictionaries under:

`$XDG_CONFIG_HOME/telexmini` or `~/.config/telexmini`

## Native engine target

Use Fcitx5 as the first Linux input-method integration. It supports both X11 and Wayland environments, but the input method must be implemented and tested against each desktop/compositor combination.

The Fcitx5 engine is intentionally not stubbed with a partial Telex implementation. Before enabling it in a release:
- Port the complete Telex/VNI composition rules and English fallback behavior.
- Preserve password-field safety and per-application exclusions where the compositor exposes sufficient context.
- Read `preferences.ini`, `EnglishWords.txt`, `VietnameseOverrides.txt`, `snippets.tsv` and `dictionary-reload.flag`.
- Reuse the existing Telex/VNI regression cases and add Fcitx5 integration tests.
- Validate on real X11 and Wayland desktops, including GNOME and KDE.

Until those gates pass, Linux is a Flutter UI target in progress, not a released system-wide input method.
