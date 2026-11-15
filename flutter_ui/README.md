# TelexMini Flutter desktop UI

This folder contains the shared Flutter desktop UI for Windows, macOS and Linux.

## Local development

```sh
flutter pub get
flutter analyze
flutter test
```

Build the current host desktop target with:

```sh
flutter build macos --release
flutter build windows --release
flutter build linux --release
```

Only build the target on its supported host OS. Windows and Linux runner scaffolds are present, but the available build workspace currently has the Flutter SDK only on macOS.

## Native bridge

The UI talks to the platform input engine through the `com.telexmini/control` method channel. See `../docs/SHARED_UI_ARCHITECTURE.md` for the bridge contract and platform integration status.
