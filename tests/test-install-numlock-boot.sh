#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/../install-numlock-boot.sh"
TEST_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_ROOT"
}

trap cleanup EXIT

mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/etc/sddm.conf.d"

cat >"$TEST_ROOT/bin/pacman" <<'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT

cat >"$TEST_ROOT/bin/sudo" <<'SCRIPT'
#!/usr/bin/env bash
exec "$@"
SCRIPT

cat >"$TEST_ROOT/bin/mkinitcpio" <<'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT

chmod +x "$TEST_ROOT/bin/pacman" "$TEST_ROOT/bin/sudo" "$TEST_ROOT/bin/mkinitcpio"

HOOKS_FILE="$TEST_ROOT/etc/mkinitcpio.conf"
SDDM_CONFIG_FILE="$TEST_ROOT/etc/sddm.conf.d/99-omarchy-supplement-numlock.conf"
printf 'HOOKS=(base encrypt filesystems)\n' >"$HOOKS_FILE"

PATH="$TEST_ROOT/bin:$PATH" \
  PACKAGE=mkinitcpio-numlock \
  HOOKS_FILE="$HOOKS_FILE" \
  SDDM_CONFIG_FILE="$SDDM_CONFIG_FILE" \
  "$INSTALL_SCRIPT" >/dev/null

grep -Fqx '[General]' "$SDDM_CONFIG_FILE"
grep -Fqx 'Numlock=on' "$SDDM_CONFIG_FILE"
grep -Fqx 'HOOKS=(base numlock encrypt filesystems)' "$HOOKS_FILE"

config_before="$(<"$SDDM_CONFIG_FILE")"
PATH="$TEST_ROOT/bin:$PATH" \
  PACKAGE=mkinitcpio-numlock \
  HOOKS_FILE="$HOOKS_FILE" \
  SDDM_CONFIG_FILE="$SDDM_CONFIG_FILE" \
  "$INSTALL_SCRIPT" >/dev/null

[[ "$config_before" == "$(<"$SDDM_CONFIG_FILE")" ]]
