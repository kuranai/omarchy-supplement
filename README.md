# Omarchy Supplement

Idempotent setup scripts for a fresh Omarchy system.

Run these after the base Omarchy install has completed.

## Scripts

- `install-dotfiles.sh`: clone or update `https://github.com/kuranai/dotfiles.git`, back up conflicting files, and apply every GNU Stow package.
- `install-numlock-boot.sh`: install `mkinitcpio-numlock`, add the `numlock` hook before `encrypt`, and rebuild initramfs so NumLock is enabled at boot password prompts.
- `install-screensaver-mousemove.sh`: replace Omarchy's local `omarchy-cmd-screensaver` with the version that exits on keyboard or mouse input.
- `install-all.sh`: run all setup scripts in order.

## Usage

```sh
./install-dotfiles.sh
```

Enable NumLock during early boot password prompts:

```sh
./install-numlock-boot.sh
```

Enable screensaver exit on mouse movement or click:

```sh
./install-screensaver-mousemove.sh
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
