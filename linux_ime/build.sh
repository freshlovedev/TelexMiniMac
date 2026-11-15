#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build/linux-native"
mkdir -p "$BUILD"

# Portable core always runs on Linux before compiling desktop adapters.
c++ -std=c++20 -O2 -Wall -Wextra -Werror \
  "$ROOT/native_core/core.cpp" "$ROOT/native_core/c_api.cpp" \
  "$ROOT/native_core/test_portable.cpp" -o "$BUILD/telexmini-core-tests"
"$BUILD/telexmini-core-tests" \
  "$ROOT/Tests/telex-corpus.tsv" "$ROOT/Resources/english-core.txt"

# Both adapters are optional: distribution packages may install just one.
if [[ "${1:-all}" == "ibus" || "${1:-all}" == "all" ]]; then
  if ! pkg-config --exists ibus-1.0; then
    echo "IBus development headers are unavailable (install libibus-1.0-dev)." >&2
    exit 3
  fi
  cmake -S "$ROOT/linux_ime/ibus" -B "$BUILD/ibus" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
  cmake --build "$BUILD/ibus" --parallel
fi
if [[ "${1:-all}" == "fcitx5" || "${1:-all}" == "all" ]]; then
  if ! pkg-config --exists fcitx5-core && \
     [[ ! -e /usr/lib/cmake/Fcitx5Core/Fcitx5CoreConfig.cmake && \
        ! -e /usr/lib/x86_64-linux-gnu/cmake/Fcitx5Core/Fcitx5CoreConfig.cmake ]]; then
    echo "Fcitx5 development SDK is unavailable (install libfcitx5core-dev)." >&2
    exit 3
  fi
  cmake -S "$ROOT/linux_ime/fcitx5" -B "$BUILD/fcitx5" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
  cmake --build "$BUILD/fcitx5" --parallel
fi
echo "LINUX_NATIVE_BUILD=PASS"
