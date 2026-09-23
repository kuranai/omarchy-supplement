#!/usr/bin/env bash
set -euo pipefail

PACKAGE="${PACKAGE:-mkinitcpio-numlock}"
HOOKS_FILE="${HOOKS_FILE:-/etc/mkinitcpio.conf.d/omarchy_hooks.conf}"
SDDM_CONFIG_FILE="${SDDM_CONFIG_FILE:-/etc/sddm.conf.d/99-omarchy-supplement-numlock.conf}"

log() {
  printf '[install-numlock-boot] %s\n' "$*"
}

fail() {
  printf '[install-numlock-boot] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

aur_helper() {
  if command -v yay >/dev/null 2>&1; then
    printf 'yay\n'
    return
  fi

  if command -v paru >/dev/null 2>&1; then
    printf 'paru\n'
    return
  fi

  fail "Missing AUR helper. Install yay or paru first, then rerun this script."
}

install_package() {
  local helper

  require_command pacman

  if pacman -Q "$PACKAGE" >/dev/null 2>&1; then
    log "$PACKAGE is already installed"
    return
  fi

  helper="$(aur_helper)"
  log "Installing $PACKAGE with $helper"
  case "$helper" in
    yay)
      "$helper" -S --needed --noconfirm --answerclean None --answerdiff None "$PACKAGE"
      ;;
    paru)
      "$helper" -S --needed --noconfirm --skipreview "$PACKAGE"
      ;;
    *)
      fail "Unsupported AUR helper: $helper"
      ;;
  esac
}

update_hooks_file() {
  local tmp_file
  local hooks_line
  local hooks
  local hook
  local updated_hooks=()
  local inserted=false
  local has_numlock=false

  [[ -f "$HOOKS_FILE" ]] || fail "$HOOKS_FILE does not exist"
  require_command sudo
  require_command mktemp

  hooks_line="$(grep -E '^HOOKS=\(' "$HOOKS_FILE" || true)"
  [[ -n "$hooks_line" ]] || fail "Could not find a HOOKS=(...) line in $HOOKS_FILE"

  hooks="${hooks_line#HOOKS=(}"
  hooks="${hooks%%)*}"

  for hook in $hooks; do
    if [[ "$hook" == "numlock" ]]; then
      has_numlock=true
      break
    fi
  done

  if [[ "$has_numlock" == true ]]; then
    log "$HOOKS_FILE already includes the numlock hook"
    return
  fi

  for hook in $hooks; do
    if [[ "$hook" == "encrypt" && "$inserted" == false ]]; then
      updated_hooks+=("numlock")
      inserted=true
    fi

    updated_hooks+=("$hook")
  done

  [[ "$inserted" == true ]] || fail "Could not find the encrypt hook in $HOOKS_FILE"

  tmp_file="$(mktemp)"
  sed "s/^HOOKS=(.*)$/HOOKS=(${updated_hooks[*]})/" "$HOOKS_FILE" >"$tmp_file"

  log "Adding numlock before encrypt in $HOOKS_FILE"
  sudo install -m 0644 "$tmp_file" "$HOOKS_FILE"
  rm -f "$tmp_file"
}

configure_sddm_numlock() {
  local tmp_file

  require_command sudo
  require_command mktemp

  tmp_file="$(mktemp)"
  cat >"$tmp_file" <<'EOF'
[General]
Numlock=on
EOF

  if [[ -f "$SDDM_CONFIG_FILE" ]] && cmp -s "$tmp_file" "$SDDM_CONFIG_FILE"; then
    log "$SDDM_CONFIG_FILE already enables Num Lock in SDDM"
    rm -f "$tmp_file"
    return
  fi

  log "Enabling Num Lock in the SDDM login greeter via $SDDM_CONFIG_FILE"
  sudo install -D -m 0644 "$tmp_file" "$SDDM_CONFIG_FILE"
  rm -f "$tmp_file"
}

rebuild_initramfs() {
  require_command sudo
  require_command mkinitcpio

  log "Rebuilding initramfs"
  sudo mkinitcpio -P
}

main() {
  install_package
  update_hooks_file
  configure_sddm_numlock
  rebuild_initramfs
  log "Done"
}

main "$@"
