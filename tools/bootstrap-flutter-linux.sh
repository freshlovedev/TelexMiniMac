#!/usr/bin/env bash
# Install the exact matching Flutter Linux stable SDK, without sudo.
# The archive is verified against the official release SHA-256.
set -euo pipefail
VERSION="3.47.1"
EXPECTED_SHA="a1d8166c0309267cb7dc99f1424eecf08b86946ad3b50723c6f59945964aea45"
URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${VERSION}-stable.tar.xz"
INSTALL_ROOT="${TELEXMINI_FLUTTER_HOME:-$HOME/.local/opt}"
SDK="$INSTALL_ROOT/flutter"
CACHE="$HOME/.cache/telexmini-flutter-sdk"
ARCHIVE="$CACHE/flutter_linux_${VERSION}-stable.tar.xz"
mkdir -p "$INSTALL_ROOT" "$CACHE"
if [ -x "$SDK/bin/flutter" ]; then
  echo "Existing Flutter SDK: $SDK"
else
  echo "Downloading official Flutter Linux SDK ${VERSION}..."
  curl --fail --location --retry 4 --retry-delay 2 --continue-at - \
       --progress-bar "$URL" --output "$ARCHIVE"
  echo "$EXPECTED_SHA  $ARCHIVE" | sha256sum --check --status
  echo "SDK_SHA256_VERIFIED=PASS"
  echo "Extracting Flutter SDK to $INSTALL_ROOT..."
  tar -xJf "$ARCHIVE" -C "$INSTALL_ROOT" --no-same-owner
  test -x "$SDK/bin/flutter"
  rm -f "$ARCHIVE"
fi
export PATH="$SDK/bin:$PATH"
git config --global --add safe.directory "$SDK" >/dev/null 2>&1 || true
flutter config --enable-linux-desktop >/dev/null
flutter --version
flutter precache --linux
echo "FLUTTER_LINUX_SDK_READY=$SDK"
