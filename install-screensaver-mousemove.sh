#!/usr/bin/env bash
set -euo pipefail

OMARCHY_PATH="${OMARCHY_PATH:-$HOME/.local/share/omarchy}"
TARGET="${TARGET:-$OMARCHY_PATH/bin/omarchy-cmd-screensaver}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.local/state/omarchy-supplement/backups/screensaver-$(date +%Y%m%d%H%M%S)}"

log() {
  printf '[install-screensaver-mousemove] %s\n' "$*"
}

fail() {
  printf '[install-screensaver-mousemove] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

write_fixed_screensaver() {
  local tmp_file

  require_command mktemp
  tmp_file="$(mktemp)"

  cat >"$tmp_file" <<'SCRIPT'
#!/bin/bash

# Run the Omarchy screensaver using random effects from TTE.

screensaver_in_focus() {
  hyprctl activewindow -j | jq -e '.class == "org.omarchy.screensaver"' >/dev/null 2>&1
}

exit_screensaver() {
  hyprctl keyword cursor:invisible false &>/dev/null || true
  pkill -x tte 2>/dev/null
  pkill -f org.omarchy.screensaver 2>/dev/null
  exit 0
}

# Exit the screensaver on signals and input from keyboard and mouse
trap exit_screensaver SIGINT SIGTERM SIGHUP SIGQUIT

printf '\033]11;rgb:00/00/00\007'  # Set background color to black

hyprctl keyword cursor:invisible true &>/dev/null

tty=$(tty 2>/dev/null)

while true; do
  tte -i ~/.config/omarchy/branding/screensaver.txt \
    --frame-rate 120 --canvas-width 0 --canvas-height 0 --reuse-canvas --anchor-canvas c --anchor-text c\
    --random-effect --exclude-effects dev_worm \
    --no-eol --no-restore-cursor &

  last_pos=$(hyprctl cursorpos)
  while pgrep -t "${tty#/dev/}" -x tte >/dev/null; do
    current_pos=$(hyprctl cursorpos)
    if [[ "$current_pos" != "$last_pos" ]] || read -n1 -t 1 || ! screensaver_in_focus; then
      exit_screensaver
    fi

    last_pos=$current_pos
  done
done
SCRIPT

  printf '%s\n' "$tmp_file"
}

backup_target() {
  local backup="$BACKUP_DIR/$(basename "$TARGET")"

  mkdir -p "$BACKUP_DIR"
  cp "$TARGET" "$backup"
  log "Backed up $TARGET to $backup"
}

install_fixed_screensaver() {
  local tmp_file

  [[ -f "$TARGET" ]] || fail "$TARGET does not exist"
  [[ -w "$TARGET" ]] || fail "$TARGET is not writable"
  require_command cmp
  require_command install

  tmp_file="$(write_fixed_screensaver)"

  if cmp -s "$tmp_file" "$TARGET"; then
    log "$TARGET already has the mousemove screensaver fix"
    rm -f "$tmp_file"
    return
  fi

  backup_target
  install -m 0755 "$tmp_file" "$TARGET"
  rm -f "$tmp_file"
  log "Installed mousemove screensaver fix in $TARGET"
}

main() {
  install_fixed_screensaver
  log "Done"
}

main "$@"
