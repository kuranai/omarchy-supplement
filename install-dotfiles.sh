#!/usr/bin/env bash
set -euo pipefail

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/kuranai/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/code/dotfiles}"
STOW_TARGET="${STOW_TARGET:-$HOME}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.local/state/omarchy-supplement/backups/dotfiles-$(date +%Y%m%d%H%M%S)}"

PACKAGES=("$@")

log() {
  printf '[install-dotfiles] %s\n' "$*"
}

fail() {
  printf '[install-dotfiles] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

is_inside_dotfiles() {
  local path="$1"
  local resolved

  resolved="$(readlink -f "$path" 2>/dev/null || true)"
  [[ -n "$resolved" && "$resolved" == "$DOTFILES_DIR"/* ]]
}

backup_conflict() {
  local target="$1"
  local relative="${target#"$STOW_TARGET"/}"
  local backup="$BACKUP_DIR/$relative"

  mkdir -p "$(dirname "$backup")"
  mv "$target" "$backup"
  log "Backed up $target to $backup"
}

backup_file_conflicts_for_package() {
  local package="$1"
  local package_dir="$DOTFILES_DIR/$package"
  local source
  local relative
  local target

  while IFS= read -r -d '' source; do
    relative="${source#"$package_dir"/}"
    target="$STOW_TARGET/$relative"

    if [[ -e "$target" || -L "$target" ]]; then
      if is_inside_dotfiles "$target"; then
        continue
      fi

      backup_conflict "$target"
    fi
  done < <(find "$package_dir" \( -type f -o -type l \) -print0)
}

clone_or_update_dotfiles() {
  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    if [[ -n "$(git -C "$DOTFILES_DIR" status --porcelain)" ]]; then
      log "Dotfiles checkout has local changes; skipping git pull"
      return
    fi

    log "Updating existing dotfiles checkout at $DOTFILES_DIR"
    git -C "$DOTFILES_DIR" pull --ff-only
    return
  fi

  if [[ -e "$DOTFILES_DIR" ]]; then
    fail "$DOTFILES_DIR exists but is not a git checkout"
  fi

  log "Cloning dotfiles into $DOTFILES_DIR"
  mkdir -p "$(dirname "$DOTFILES_DIR")"
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
}

discover_packages() {
  if [[ "${#PACKAGES[@]}" -gt 0 ]]; then
    return
  fi

  mapfile -t PACKAGES < <(
    find "$DOTFILES_DIR" -mindepth 1 -maxdepth 1 -type d \
      ! -name '.git' \
      ! -name '.codex' \
      -printf '%f\n' | sort
  )
}

stow_packages() {
  local package

  for package in "${PACKAGES[@]}"; do
    [[ -d "$DOTFILES_DIR/$package" ]] || fail "Unknown dotfiles package: $package"

    backup_file_conflicts_for_package "$package"
    log "Stowing $package"
    stow --dir="$DOTFILES_DIR" --target="$STOW_TARGET" --restow "$package"
  done
}

main() {
  require_command git
  require_command stow
  require_command readlink

  clone_or_update_dotfiles
  discover_packages

  [[ "${#PACKAGES[@]}" -gt 0 ]] || fail "No stow packages found in $DOTFILES_DIR"

  log "Using packages: ${PACKAGES[*]}"
  stow_packages
  log "Done"
}

main "$@"
