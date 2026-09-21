#!/usr/bin/env bash
set -euo pipefail

OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
USER_BIN_DIR="$HOME/.local/bin"
SUPPLEMENT_BIN_DIR="$HOME/.local/share/omarchy-supplement/bin"
SCREENSAVER_NAME="omarchy-supplement-screensaver"
LAUNCHER_NAME="omarchy-supplement-screensaver-launch"
SCREENSAVER_TARGET="$USER_BIN_DIR/$SCREENSAVER_NAME"
LAUNCHER_TARGET="$USER_BIN_DIR/$LAUNCHER_NAME"
SCREENSAVER_SHIM_TARGET="$SUPPLEMENT_BIN_DIR/omarchy-screensaver"
HYPR_CONFIG_DIR="$HOME/.config/hypr"
HYPRLAND_CONFIG="$HYPR_CONFIG_DIR/hyprland.lua"
HYPR_ENV_MODULE="$HYPR_CONFIG_DIR/omarchy_supplement.lua"
HYPR_ENV_REQUIRE='require("hypr.omarchy_supplement")'
BACKUP_DIR="${BACKUP_DIR:-$HOME/.local/state/omarchy-supplement/backups/screensaver-$(date +%Y%m%d%H%M%S)}"
IDLE_PLUGIN_ID="${USER:-$(id -un)}.idle"
IDLE_PLUGIN_DIR="$HOME/.config/omarchy/plugins/$IDLE_PLUGIN_ID"
LEGACY_TARGET="${TARGET:-$OMARCHY_PATH/bin/omarchy-cmd-screensaver}"

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

backup_file() {
  local source="$1"
  local backup_name="$2"
  local backup="$BACKUP_DIR/$backup_name"

  mkdir -p "$BACKUP_DIR"
  cp -a "$source" "$backup"
  log "Backed up $source to $backup"
}

install_generated_file() {
  local source="$1"
  local target="$2"
  local backup_name="$3"
  local mode="${4:-0755}"

  mkdir -p "$(dirname "$target")"

  if [[ -f "$target" ]] && cmp -s "$source" "$target"; then
    log "$target already has the screensaver mousemove fix"
    rm -f "$source"
    return
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    backup_file "$target" "$backup_name"
  fi

  install -m "$mode" "$source" "$target"
  rm -f "$source"
  log "Installed $target"
}

command_source() {
  local command_name="$1"
  local command_path

  command_path="$(command -v "$command_name" 2>/dev/null || true)"
  [[ -n "$command_path" ]] || return 1
  [[ -f "$command_path" || -L "$command_path" ]] || return 1

  readlink -f -- "$command_path"
}

omarchy_source() {
  local command_name="$1"
  local fallback="$2"
  local source

  source="$(command_source "$command_name" || true)"
  if [[ -n "$source" && -f "$source" ]]; then
    printf '%s\n' "$source"
    return
  fi

  [[ -f "$fallback" ]] || return 1
  readlink -f -- "$fallback"
}

detect_engine() {
  local source="$1"

  if grep -Eq '^[[:space:]]*ttfx[[:space:]]' "$source"; then
    printf 'ttfx\n'
    return
  fi

  if grep -Eq '^[[:space:]]*tte[[:space:]]' "$source"; then
    printf 'tte\n'
    return
  fi

  fail "Could not detect the TTE renderer used by $source"
}

write_fixed_screensaver() {
  local source="$1"
  local engine
  local tmp_file

  engine="$(detect_engine "$source")"
  tmp_file="$(mktemp)"

  cat >"$tmp_file" <<'SCRIPT'
#!/bin/bash

# Run the Omarchy screensaver using random effects from TTE and leave it when
# the pointer moves, the user types, or the screensaver window loses focus.

screensaver_in_focus() {
  hyprctl activewindow -j | jq -e '.class == "org.omarchy.screensaver"' >/dev/null 2>&1
}

exit_screensaver() {
  hyprctl eval 'hl.config({ cursor = { invisible = false } })' &>/dev/null ||
    hyprctl keyword cursor:invisible false &>/dev/null || true
  pkill -x __OMARCHY_SCREENSAVER_ENGINE__ 2>/dev/null
  pkill -f '[o]rg.omarchy.screensaver' 2>/dev/null
  exit 0
}

# Exit the screensaver on signals and input from keyboard and mouse
trap exit_screensaver SIGINT SIGTERM SIGHUP SIGQUIT

printf '\033]11;rgb:00/00/00\007'  # Set background color to black

hyprctl eval 'hl.config({ cursor = { invisible = true } })' &>/dev/null ||
  hyprctl keyword cursor:invisible true &>/dev/null

tty=$(tty 2>/dev/null)

# Current Omarchy terminals initially allocate an 80x24 pty and resize it
# after the fullscreen window maps. TTFX measures the terminal at startup, so
# wait until that resize has arrived before rendering.
wait_for_terminal_resize() {
  local deadline=$((SECONDS + 2))
  while ((SECONDS < deadline)) && [[ $(stty size 2>/dev/null) == "24 80" ]]; do
    sleep 0.02
  done
}

wait_for_terminal_resize

while true; do
  __OMARCHY_SCREENSAVER_ENGINE__ -i ~/.config/omarchy/branding/screensaver.txt \
    --frame-rate 120 --canvas-width 0 --canvas-height 0 --reuse-canvas --anchor-canvas c --anchor-text c\
    --random-effect --exclude-effects dev_worm \
    --no-eol --no-restore-cursor &

  last_pos=$(hyprctl cursorpos 2>/dev/null || true)
  while pgrep -t "${tty#/dev/}" -x __OMARCHY_SCREENSAVER_ENGINE__ >/dev/null; do
    current_pos=$(hyprctl cursorpos 2>/dev/null || true)
    if [[ "$current_pos" != "$last_pos" ]] || read -n1 -t 1 || ! screensaver_in_focus; then
      exit_screensaver
    fi

    last_pos=$current_pos
  done
done
SCRIPT

  sed -i "s/__OMARCHY_SCREENSAVER_ENGINE__/$engine/g" "$tmp_file"
  printf '%s\n' "$tmp_file"
}

write_fixed_launcher() {
  local source="$1"
  local tmp_file
  local replacement='-e "$HOME/.local/bin/omarchy-supplement-screensaver"'

  tmp_file="$(mktemp)"
  cp "$source" "$tmp_file"

  sed -i \
    -e "s|-e omarchy-screensaver|$replacement|g" \
    -e "s|-e omarchy-cmd-screensaver|$replacement|g" \
    "$tmp_file"

  grep -Fq -- "$SCREENSAVER_NAME" "$tmp_file" ||
    fail "Could not adapt the Omarchy screensaver launcher at $source"

  printf '%s\n' "$tmp_file"
}

write_screensaver_shim() {
  local tmp_file

  tmp_file="$(mktemp)"
  cat >"$tmp_file" <<'SCRIPT'
#!/bin/sh

exec "$HOME/.local/bin/omarchy-supplement-screensaver" "$@"
SCRIPT
  printf '%s\n' "$tmp_file"
}

write_hypr_path_module() {
  local tmp_file

  tmp_file="$(mktemp)"
  cat >"$tmp_file" <<'LUA'
-- Keep the Omarchy screensaver command user-overridable without changing the
-- package-owned /usr/share/omarchy files.
local home = os.getenv("HOME") or ""
if home == "" then return end

local supplement_bin = home .. "/.local/share/omarchy-supplement/bin"
local kept = {}
for entry in (os.getenv("PATH") or ""):gmatch("[^:]+") do
  if entry ~= supplement_bin then table.insert(kept, entry) end
end
table.insert(kept, 1, supplement_bin)
hl.env("PATH", table.concat(kept, ":"))
LUA
  printf '%s\n' "$tmp_file"
}

configure_normal_launcher() {
  local shim_tmp
  local module_tmp

  shim_tmp="$(write_screensaver_shim)"
  module_tmp="$(write_hypr_path_module)"

  install_generated_file "$shim_tmp" "$SCREENSAVER_SHIM_TARGET" "omarchy-screensaver-shim"
  install_generated_file "$module_tmp" "$HYPR_ENV_MODULE" "hypr-omarchy_supplement.lua" 0644

  if [[ ! -f "$HYPRLAND_CONFIG" ]]; then
    log "Hyprland config not found at $HYPRLAND_CONFIG; the idle plugin is configured, but the normal launcher still needs $LAUNCHER_NAME"
    return
  fi

  if grep -Fq "$HYPR_ENV_REQUIRE" "$HYPRLAND_CONFIG"; then
    log "$HYPRLAND_CONFIG already loads the screensaver PATH override"
  else
    backup_file "$HYPRLAND_CONFIG" "hyprland.lua"
    printf '\n-- omarchy-supplement: make the mouse-aware renderer win for normal launches\n%s\n' "$HYPR_ENV_REQUIRE" >>"$HYPRLAND_CONFIG"
    log "Configured $HYPRLAND_CONFIG to use the mouse-aware renderer for normal launches"
  fi

  if command -v hyprctl >/dev/null 2>&1; then
    if hyprctl reload >/dev/null 2>&1; then
      local config_errors
      config_errors="$(hyprctl configerrors 2>&1 || true)"
      if [[ -n "$config_errors" && "$config_errors" != "no errors" ]]; then
        log "WARNING: Hyprland reported config errors after reload: $config_errors"
      else
        log "Reloaded Hyprland with the screensaver PATH override"
      fi
    else
      log "Hyprland could not be reloaded; restart or run 'hyprctl reload' before testing"
    fi
  else
    log "hyprctl is not available; restart Hyprland before testing"
  fi
}

ensure_idle_plugin_clone() {
  local manifest="$IDLE_PLUGIN_DIR/manifest.json"
  local cloned_from

  if [[ ! -d "$IDLE_PLUGIN_DIR" ]]; then
    require_command omarchy
    log "Cloning Omarchy's idle service to $IDLE_PLUGIN_DIR"
    omarchy plugin clone omarchy.idle
  fi

  [[ -f "$manifest" ]] || fail "Expected idle plugin manifest at $manifest"
  require_command jq

  cloned_from="$(jq -r '.omarchy.clonedFrom // empty' "$manifest")"
  [[ "$cloned_from" == "omarchy.idle" ]] ||
    fail "$IDLE_PLUGIN_DIR is not a clone of omarchy.idle"
}

patch_idle_plugin() {
  local service_file="$IDLE_PLUGIN_DIR/Service.qml"

  [[ -f "$service_file" ]] || fail "Expected idle service at $service_file"

  if grep -Fq "|| $LAUNCHER_NAME" "$service_file"; then
    log "$service_file already uses the mousemove screensaver launcher"
    return
  fi

  grep -Fq '|| omarchy-launch-screensaver' "$service_file" ||
    fail "Could not find the screensaver launcher in $service_file"

  backup_file "$service_file" "idle-Service.qml"
  sed -i "s/|| omarchy-launch-screensaver/|| $LAUNCHER_NAME/g" "$service_file"
  log "Configured the idle service to use $LAUNCHER_NAME"
}

install_current_screensaver() {
  local renderer_source
  local launcher_source
  local idle_source="$OMARCHY_PATH/shell/plugins/services/idle/Service.qml"
  local renderer_tmp
  local launcher_tmp

  renderer_source="$(omarchy_source omarchy-screensaver "$OMARCHY_PATH/bin/omarchy-screensaver" || true)"
  [[ -n "$renderer_source" ]] || fail "omarchy-screensaver was not found"

  launcher_source="$(omarchy_source omarchy-launch-screensaver "$OMARCHY_PATH/bin/omarchy-launch-screensaver" || true)"
  [[ -n "$launcher_source" ]] || fail "omarchy-launch-screensaver was not found"
  [[ -f "$idle_source" ]] || fail "Omarchy idle service was not found at $idle_source"

  renderer_tmp="$(write_fixed_screensaver "$renderer_source")"
  launcher_tmp="$(write_fixed_launcher "$launcher_source")"

  install_generated_file "$renderer_tmp" "$SCREENSAVER_TARGET" "$SCREENSAVER_NAME"
  install_generated_file "$launcher_tmp" "$LAUNCHER_TARGET" "$LAUNCHER_NAME"
  configure_normal_launcher

  ensure_idle_plugin_clone
  patch_idle_plugin

  if command -v omarchy-shell >/dev/null 2>&1; then
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  fi
}

install_legacy_screensaver() {
  local screensaver_tmp

  [[ -f "$LEGACY_TARGET" ]] ||
    fail "No supported Omarchy screensaver found. Expected omarchy-screensaver or $LEGACY_TARGET"
  [[ -w "$LEGACY_TARGET" ]] ||
    fail "$LEGACY_TARGET is not writable; this legacy Omarchy install cannot be changed safely"

  screensaver_tmp="$(write_fixed_screensaver "$LEGACY_TARGET")"
  install_generated_file "$screensaver_tmp" "$LEGACY_TARGET" "$(basename "$LEGACY_TARGET")"
}

main() {
  local current_screensaver

  require_command cmp
  require_command cp
  require_command grep
  require_command install
  require_command mktemp
  require_command readlink
  require_command sed

  current_screensaver="$(omarchy_source omarchy-screensaver "$OMARCHY_PATH/bin/omarchy-screensaver" || true)"
  if [[ -n "$current_screensaver" && -f "$OMARCHY_PATH/shell/plugins/services/idle/Service.qml" ]]; then
    install_current_screensaver
  else
    install_legacy_screensaver
  fi

  log "Done"
}

main "$@"
