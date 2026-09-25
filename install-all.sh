#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

"$SCRIPT_DIR/install-dotfiles.sh"
"$SCRIPT_DIR/install-terminal-font.sh"
"$SCRIPT_DIR/install-numlock-boot.sh"
"$SCRIPT_DIR/install-screensaver-mousemove.sh"
