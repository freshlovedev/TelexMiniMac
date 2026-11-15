#!/usr/bin/env bash
set -euo pipefail
# Safe, no-secret-in-arguments Ubuntu builder; never modifies a desktop session.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $# -ne 1 || "$1" != *@* ]]; then
  echo "Usage: bash linux_ime/build-on-ubuntu.sh USER@HOST" >&2
  exit 2
fi
REMOTE="$1"
SSH_OPTS=(-o BatchMode=yes -o IdentitiesOnly=yes -o ConnectTimeout=7 -o StrictHostKeyChecking=yes)
# Never pass SSH secrets on the command line. Keep the private key on the Mac.
IDENTITY="${TELEXMINI_SSH_IDENTITY:-$HOME/.ssh/id_ed25519_telexmini_ubuntu}"
if [[ -f "$IDENTITY" ]]; then SSH_OPTS+=(-i "$IDENTITY"); fi
echo "Connecting to $REMOTE (SSH key authentication required)."
ssh "${SSH_OPTS[@]}" "$REMOTE" 'uname -a; id -un; cat /etc/os-release | head -n 5; command -v cmake; command -v g++'
REMOTE_DIR=".cache/telexmini-native-qa"
ssh "${SSH_OPTS[@]}" "$REMOTE" "mkdir -p '$REMOTE_DIR'"
# Never push private settings, installed input methods, Git metadata or binary builds.
COPYFILE_DISABLE=1 tar -C "$ROOT" --exclude='._*' -czf - \
  native_core linux_ime Tests/telex-corpus.tsv Resources/english-core.txt |
  ssh "${SSH_OPTS[@]}" "$REMOTE" "tar -xzf - -C '$REMOTE_DIR'"
ssh "${SSH_OPTS[@]}" "$REMOTE" \
  "cd '$REMOTE_DIR' && bash linux_ime/build.sh all"
echo "UBUNTU_NATIVE_BUILD=PASS"
echo "No system packages were installed or desktop settings modified."
