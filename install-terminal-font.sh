#!/usr/bin/env bash
set -euo pipefail

TERMINAL_FONT_SIZE="${TERMINAL_FONT_SIZE:-10}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.local/state/omarchy-supplement/backups/terminal-font-$(date +%Y%m%d%H%M%S)}"
ALACRITTY_CONFIG="${ALACRITTY_CONFIG:-$HOME/.config/alacritty/alacritty.toml}"
FOOT_CONFIG="${FOOT_CONFIG:-$HOME/.config/foot/foot.ini}"
GHOSTTY_CONFIG="${GHOSTTY_CONFIG:-$HOME/.config/ghostty/config}"
KITTY_CONFIG="${KITTY_CONFIG:-$HOME/.config/kitty/kitty.conf}"
RESTART_TERMINALS="${RESTART_TERMINALS:-1}"

CHANGED=0
FOUND_CONFIGS=0
TEMP_FILES=()

log() {
  printf '[install-terminal-font] %s\n' "$*"
}

fail() {
  printf '[install-terminal-font] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

cleanup() {
  if [[ "${#TEMP_FILES[@]}" -gt 0 ]]; then
    rm -f -- "${TEMP_FILES[@]}"
  fi
}

trap cleanup EXIT

validate_settings() {
  [[ "$TERMINAL_FONT_SIZE" =~ ^[0-9]+([.][0-9]+)?$ ]] ||
    fail "TERMINAL_FONT_SIZE must be a positive number, got: $TERMINAL_FONT_SIZE"

  awk -v size="$TERMINAL_FONT_SIZE" 'BEGIN { exit !(size > 0) }' ||
    fail "TERMINAL_FONT_SIZE must be greater than zero"

  [[ "$RESTART_TERMINALS" == "0" || "$RESTART_TERMINALS" == "1" ]] ||
    fail "RESTART_TERMINALS must be 0 or 1"
}

new_temp_file() {
  local temp_file

  temp_file="$(mktemp)"
  TEMP_FILES+=("$temp_file")
  printf '%s\n' "$temp_file"
}

render_alacritty() {
  local source="$1"
  local output="$2"

  if ! awk -v size="$TERMINAL_FONT_SIZE" '
    BEGIN { in_font = 0; replaced = 0 }
    /^[[:space:]]*\[font\][[:space:]]*$/ {
      in_font = 1
      print
      next
    }
    /^[[:space:]]*\[[^]]+\][[:space:]]*$/ { in_font = 0 }
    in_font && /^[[:space:]]*size[[:space:]]*=/ {
      print "size = " size
      replaced = 1
      next
    }
    { print }
    END { if (!replaced) exit 42 }
  ' "$source" >"$output"; then
    fail "Could not find the Alacritty font size in $source"
  fi
}

render_foot() {
  local source="$1"
  local output="$2"

  if ! awk -v size="$TERMINAL_FONT_SIZE" '
    BEGIN { replaced = 0 }
    /^[[:space:]]*font=[^#]*:size=[0-9]+([.][0-9]+)?([[:space:]]*(#.*)?)?$/ {
      sub(/:size=[0-9]+([.][0-9]+)?/, ":size=" size)
      replaced = 1
    }
    { print }
    END { if (!replaced) exit 42 }
  ' "$source" >"$output"; then
    fail "Could not find the Foot font size in $source"
  fi
}

render_ghostty() {
  local source="$1"
  local output="$2"

  if ! awk -v size="$TERMINAL_FONT_SIZE" '
    BEGIN { replaced = 0 }
    /^[[:space:]]*font-size[[:space:]]*=/ {
      print "font-size = " size
      replaced = 1
      next
    }
    { print }
    END { if (!replaced) exit 42 }
  ' "$source" >"$output"; then
    fail "Could not find the Ghostty font size in $source"
  fi
}

render_kitty() {
  local source="$1"
  local output="$2"

  awk -v size="$TERMINAL_FONT_SIZE" '
    BEGIN { replaced = 0 }
    /^[[:space:]]*font_size[[:space:]]+/ {
      print "font_size " size
      replaced = 1
      next
    }
    { print }
    END {
      if (!replaced) {
        print ""
        print "# Managed by omarchy-supplement"
        print "font_size " size
      }
    }
  ' "$source" >"$output"
}

render_config() {
  local kind="$1"
  local source="$2"
  local output="$3"

  case "$kind" in
    alacritty) render_alacritty "$source" "$output" ;;
    foot) render_foot "$source" "$output" ;;
    ghostty) render_ghostty "$source" "$output" ;;
    kitty) render_kitty "$source" "$output" ;;
    *) fail "Unsupported terminal config type: $kind" ;;
  esac
}

apply_config() {
  local kind="$1"
  local logical_target="$2"
  local source
  local output
  local backup
  local mode

  if [[ ! -e "$logical_target" && ! -L "$logical_target" ]]; then
    log "Skipping $logical_target; config not found"
    return
  fi

  FOUND_CONFIGS=$((FOUND_CONFIGS + 1))
  source="$(readlink -f -- "$logical_target" 2>/dev/null || true)"
  [[ -f "$source" ]] || fail "$logical_target does not resolve to a regular file"

  output="$(new_temp_file)"
  render_config "$kind" "$source" "$output"

  if cmp -s "$output" "$source"; then
    log "$logical_target already uses font size $TERMINAL_FONT_SIZE"
    return
  fi

  mkdir -p "$BACKUP_DIR"
  backup="$BACKUP_DIR/$(basename "$logical_target")"
  cp -a -- "$source" "$backup"
  mode="$(stat -c '%a' "$source")"
  install -m "$mode" "$output" "$source"
  CHANGED=1

  if [[ "$source" == "$logical_target" ]]; then
    log "Set $logical_target to font size $TERMINAL_FONT_SIZE"
  else
    log "Set $logical_target to font size $TERMINAL_FONT_SIZE (updated $source)"
  fi
  log "Backed up the previous config to $backup"
}

restart_terminals() {
  (( CHANGED == 1 )) || return

  if [[ "$RESTART_TERMINALS" == "0" ]]; then
    log "Terminal configs changed; restart terminals to apply the new size"
    return
  fi

  if command -v omarchy >/dev/null 2>&1; then
    if omarchy restart terminal; then
      log "Reloaded supported terminals"
    else
      log "WARNING: could not reload supported terminals; run 'omarchy restart terminal' manually"
    fi
  else
    log "Terminal configs changed; run 'omarchy restart terminal' to apply the new size"
  fi
}

main() {
  require_command awk
  require_command cmp
  require_command cp
  require_command install
  require_command mktemp
  require_command readlink
  require_command stat
  validate_settings

  apply_config alacritty "$ALACRITTY_CONFIG"
  apply_config foot "$FOOT_CONFIG"
  apply_config ghostty "$GHOSTTY_CONFIG"
  apply_config kitty "$KITTY_CONFIG"

  (( FOUND_CONFIGS > 0 )) || fail "No supported terminal configs were found"
  restart_terminals
  log "Done"
}

main "$@"
