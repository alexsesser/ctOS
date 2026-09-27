#!/usr/bin/env bash
# Reverts splash/install.sh: restores the kernel options of the systemd-boot
# entry, removes the fallback entry, the mkinitcpio drop-in, the Plymouth theme
# and the Plasma splash, rebuilds the initramfs. The plymouth package is
# removed only if you confirm.

set -Eeuo pipefail
trap 'echo; echo "[EXIT] Failed at line $LINENO."; exit 1' ERR

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

THEME_DIR=/usr/share/plymouth/themes/ctos
PLYMOUTH_CONF=/etc/plymouth/plymouthd.conf
MKINITCPIO_DROPIN=/etc/mkinitcpio.conf.d/ctos-boot.conf
STATE_DIR=/var/lib/ctos-boot

step() { echo "[ITEM] $*"; }

sudo -v

BOOT_PATH=$(bootctl --print-boot-path 2>/dev/null || true)
ENTRIES_DIR=${BOOT_PATH:-/boot}/loader/entries

# only the options line is restored, other edits of the entries are kept
for backup in $(sudo find "$STATE_DIR" -maxdepth 1 -name '*.conf.orig' 2>/dev/null); do
  entry=$(basename "$backup" .orig)
  if [[ -f $ENTRIES_DIR/$entry ]]; then
    original=$(sudo grep -m1 '^options' "$backup")
    sudo sed -i "s|^options.*|$original|" "$ENTRIES_DIR/$entry"
    step "restored kernel options in $ENTRIES_DIR/$entry"
  fi
  sudo rm -f "$ENTRIES_DIR/${entry%.conf}-bootlog.conf"
done

sudo rm -f "$MKINITCPIO_DROPIN"
if [[ -f "$STATE_DIR/plymouthd.conf.orig" ]]; then
  sudo cp -a "$STATE_DIR/plymouthd.conf.orig" "$PLYMOUTH_CONF"
else
  sudo rm -f "$PLYMOUTH_CONF"
fi
sudo rm -rf "$THEME_DIR" "$STATE_DIR"
step "removed Plymouth theme, config and mkinitcpio drop-in"

"$SCRIPT_DIR/ksplash.sh" uninstall

reply=""
read -rp "[Q] Also remove the plymouth package? (y/n) " reply || true
if [[ $reply =~ ^[Yy]$ ]]; then
  sudo pacman -Rns --noconfirm plymouth
fi

sudo mkinitcpio -P

echo
echo "[EXIT] Done. The next boot uses the text console again."
