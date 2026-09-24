# Omarchy Supplement

Idempotent setup scripts for a fresh Omarchy system.

Run these after the base Omarchy install has completed.

## Scripts

- `install-dotfiles.sh`: clone or update `https://github.com/kuranai/dotfiles.git`, back up conflicting files, and apply every GNU Stow package.
- `install-numlock-boot.sh`: install `mkinitcpio-numlock`, add the `numlock` hook before `encrypt`, configure SDDM and its Hyprland greeter to enable Num Lock, and rebuild initramfs.
- `install-screensaver-mousemove.sh`: install a user-owned screensaver renderer and launcher that exit on keyboard or mouse input, and wire them into Omarchy's idle service.
- `install-all.sh`: run all setup scripts in order.

## Usage

```sh
./install-dotfiles.sh
```

Enable Num Lock during early boot password prompts and in the SDDM login greeter:

```sh
./install-numlock-boot.sh
```

The initramfs hook controls Num Lock before the graphical login starts. The
script writes `/etc/sddm.conf.d/99-omarchy-supplement-numlock.conf` with
`Numlock=on` and points SDDM at `/etc/sddm/hyprland.lua`. That user-owned
greeter wrapper loads Omarchy's packaged configuration and applies
`input.numlock_by_default = true`, so it remains compatible with future
Omarchy greeter updates. Restart the computer after running the script so
SDDM reads the new setting. SDDM ignores the login-greeter setting when
autologin is enabled.

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
