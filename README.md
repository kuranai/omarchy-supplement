# Omarchy Supplement

Idempotent setup scripts for a fresh Omarchy system.

Run these after the base Omarchy install has completed.

## Scripts

- `install-dotfiles.sh`: clone or update `https://github.com/kuranai/dotfiles.git`, back up conflicting files, and apply every GNU Stow package.
- `install-terminal-font.sh`: set supported terminal configs to a readable 10pt font, back up changed files, and reload terminals.
- `install-numlock-boot.sh`: install `mkinitcpio-numlock`, add the `numlock` hook before `encrypt`, configure SDDM to enable Num Lock, restore the Omarchy Plymouth theme, and rebuild the boot image.
- `install-screensaver-mousemove.sh`: install a user-owned screensaver renderer and launcher that exit on keyboard or mouse input, and wire them into Omarchy's idle service.
- `install-all.sh`: run all setup scripts in order.

## Usage

```sh
./install-dotfiles.sh
```

Make the terminal font a little larger:

```sh
./install-terminal-font.sh
```

The default size is 10pt, up from Omarchy's 9pt default. Override it with
`TERMINAL_FONT_SIZE`, for example `TERMINAL_FONT_SIZE=11 ./install-terminal-font.sh`.
The script updates Alacritty, Foot, Ghostty, and Kitty configs when present,
follows Stow symlinks, and stores backups under
`$HOME/.local/state/omarchy-supplement/backups/`.

Enable Num Lock during early boot password prompts and in the SDDM login greeter:

```sh
./install-numlock-boot.sh
```

The initramfs hook controls Num Lock before the graphical login starts. The
script writes `/etc/sddm.conf.d/99-omarchy-supplement-numlock.conf` with
`Numlock=on`, restores the `omarchy` Plymouth theme, and rebuilds the boot
image. On Omarchy systems it uses `limine-mkinitcpio` so the unified kernel
image used by Limine is updated. Restart the computer after running the
script so the new settings are used. SDDM ignores the login-greeter setting
when autologin is enabled.

Enable screensaver exit on mouse movement or click:

```sh
./install-screensaver-mousemove.sh
```

On current Omarchy versions the script clones and customizes `omarchy.idle` in
`~/.config/omarchy/` and installs a small user-owned PATH shim so both the idle
service and `omarchy launch screensaver` use the mouse-aware renderer. It does
not modify files owned by the Omarchy package. Rerun it after an Omarchy update
if the screensaver implementation changes.

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
