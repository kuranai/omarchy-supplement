# Omarchy Supplement

Idempotent setup scripts for a fresh Omarchy system.

Run these after the base Omarchy install has completed.

## Scripts

- `install-dotfiles.sh`: clone or update `https://github.com/kuranai/dotfiles.git`, back up conflicting files, and apply every GNU Stow package.
- `install-all.sh`: run all setup scripts in order. For now, this only runs `install-dotfiles.sh`.

## Usage

```sh
./install-dotfiles.sh
```

To stow only selected packages:

```sh
./install-dotfiles.sh nvim ghostty shell
```

Environment overrides:

```sh
DOTFILES_DIR="$HOME/code/dotfiles" \
DOTFILES_REPO="https://github.com/kuranai/dotfiles.git" \
STOW_TARGET="$HOME" \
./install-dotfiles.sh
```

Conflicting existing files are moved to:

```sh
$HOME/.local/state/omarchy-supplement/backups/
```
