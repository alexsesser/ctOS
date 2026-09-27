#!/usr/bin/env bash
# Boot and login splash: Plymouth theme with the ctOS logo instead of kernel
# text, early KMS for NVIDIA, quiet kernel command line with a fallback
# "boot log" entry for systemd-boot, and the ctOS Plasma splash after login.
#
# Called by ../install.sh (skip with --no-splash), can be run on its own.
# Run as your normal user, it calls sudo itself. Undo with ./uninstall.sh.
#
# ENTRY=<file> selects the systemd-boot entry (default: the one booted now).

set -Eeuo pipefail
trap 'echo; echo "[EXIT] Splash install failed at line $LINENO."; exit 1' ERR

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(dirname "$SCRIPT_DIR")

THEME_DIR=/usr/share/plymouth/themes/ctos
PLYMOUTH_CONF=/etc/plymouth/plymouthd.conf
MKINITCPIO_DROPIN=/etc/mkinitcpio.conf.d/ctos-boot.conf
STATE_DIR=/var/lib/ctos-boot

# hide kernel/udev messages and the blinking console cursor
QUIET_PARAMS=(quiet splash loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0)

step() { echo "[ITEM] $*"; }
warn() { echo "[WARN] $*"; }

echo
echo "[SPLASH] Boot and login splash"

sudo -v

# SECTION systemd-boot entry (optional: without it only the kernel options are left to you)

BOOT_PATH=$(bootctl --print-boot-path 2>/dev/null || true)
ENTRY=${ENTRY:-$(bootctl status 2>/dev/null | awk -F': ' '/Current Entry:/ { print $2; exit }' || true)}
ENTRY=${ENTRY:-arch.conf}
ENTRY_PATH=""
if [[ -n $BOOT_PATH && -f $BOOT_PATH/loader/entries/$ENTRY ]]; then
  ENTRY_PATH=$BOOT_PATH/loader/entries/$ENTRY
  VERBOSE_ENTRY_PATH=$BOOT_PATH/loader/entries/${ENTRY%.conf}-bootlog.conf
fi

# SECTION Packages
sudo pacman -S --needed --noconfirm plymouth
step "plymouth installed"

# SECTION Plymouth theme
sudo install -d "$THEME_DIR" "$STATE_DIR"
sudo install -m 644 "$SCRIPT_DIR"/plymouth/* "$THEME_DIR/"
# same background grid as the greeter
sudo install -m 644 "$REPO_DIR/greeter/resources/lock.png" "$THEME_DIR/background.png"
step "theme: $THEME_DIR"

if [[ -f "$PLYMOUTH_CONF" && ! -f "$STATE_DIR/plymouthd.conf.orig" ]]; then
  sudo cp -a "$PLYMOUTH_CONF" "$STATE_DIR/plymouthd.conf.orig"
fi
sudo install -Dm 644 /dev/stdin "$PLYMOUTH_CONF" <<'EOF'
# ctOS splash (splash/install.sh)
[Daemon]
Theme=ctos
ShowDelay=0
DeviceTimeout=8
EOF
step "plymouth config: $PLYMOUTH_CONF"

# SECTION initramfs: plymouth hook + early KMS
{
  echo "# ctOS splash: Plymouth in the initramfs (after udev)"
  cat <<'EOF'
if [[ " ${HOOKS[*]} " != *" plymouth "* ]]; then
    _ctos_hooks=()
    for _hook in "${HOOKS[@]}"; do
        _ctos_hooks+=("$_hook")
        if [[ $_hook == udev || $_hook == systemd ]]; then
            _ctos_hooks+=(plymouth)
        fi
    done
    HOOKS=("${_ctos_hooks[@]}")
    unset _ctos_hooks _hook
fi
EOF
  # without the driver in the initramfs Plymouth only gets a screen late in boot
  # (not `lsmod | grep -q`: with pipefail the SIGPIPE of lsmod fails the check)
  if [[ -d /sys/module/nvidia_drm ]]; then
    echo
    echo "# early KMS for NVIDIA (the initramfs is rebuilt on driver updates by 90-mkinitcpio-install.hook)"
    echo "MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)"
  fi
} | sudo install -Dm 644 /dev/stdin "$MKINITCPIO_DROPIN"
step "mkinitcpio drop-in: $MKINITCPIO_DROPIN"

# SECTION Kernel command line (systemd-boot)
if [[ -n $ENTRY_PATH ]]; then
  if [[ ! -f "$STATE_DIR/$ENTRY.orig" ]]; then
    sudo cp -a "$ENTRY_PATH" "$STATE_DIR/$ENTRY.orig"
  fi

  options=$(grep -m1 '^options' "$ENTRY_PATH" | sed 's/^options[[:space:]]*//')
  for param in "${QUIET_PARAMS[@]}"; do
    if [[ " $options " != *" $param "* ]]; then
      options="$options $param"
    fi
  done
  sudo sed -i "s|^options.*|options $options|" "$ENTRY_PATH"
  step "kernel options ($ENTRY): $options"

  # fallback entry with the text boot log, selectable from the systemd-boot menu
  title=$(awk '$1 == "title" { sub(/^title[[:space:]]*/, ""); print; exit }' "$ENTRY_PATH")
  verbose_options=$options
  for param in "${QUIET_PARAMS[@]}"; do
    verbose_options=$(sed -E "s/(^| )$param( |$)/ /g" <<<"$verbose_options")
  done
  verbose_options="$(xargs <<<"$verbose_options") plymouth.enable=0"
  sed -e "s|^title.*|title ${title:-Linux} (boot log)|" -e "s|^options.*|options $verbose_options|" "$ENTRY_PATH" |
    sudo install -m 644 /dev/stdin "$VERBOSE_ENTRY_PATH"
  step "fallback entry: $VERBOSE_ENTRY_PATH"
else
  warn "systemd-boot entry not found (ENTRY=$ENTRY): add to your kernel command line yourself:"
  warn "  ${QUIET_PARAMS[*]}"
fi

# SECTION Plasma splash after login (per user)
"$SCRIPT_DIR/ksplash.sh" install

# SECTION Rebuild the initramfs only when something changed

initramfs_ok() {
  local image
  if [[ -n $ENTRY_PATH ]]; then
    image=$(awk '$1 == "initrd" && $2 !~ /ucode/ { print $2; exit }' "$ENTRY_PATH")
    image=$BOOT_PATH/${image#/}
  else
    image=/boot/initramfs-linux.img
  fi
  [[ -f $image ]] || return 1

  local contents
  contents=$(lsinitcpio "$image")
  grep -q 'usr/bin/plymouthd' <<<"$contents" || return 1
  grep -q 'themes/ctos/ctos.script' <<<"$contents" || return 1
  if [[ -d /sys/module/nvidia_drm ]]; then
    grep -Eq '/nvidia[-_]drm\.ko' <<<"$contents" || return 1
  fi
}

checksum=$(cat "$THEME_DIR"/* "$PLYMOUTH_CONF" "$MKINITCPIO_DROPIN" | sha256sum | cut -d' ' -f1)
if [[ $(sudo cat "$STATE_DIR/installed.sha256" 2>/dev/null) == "$checksum" ]] && initramfs_ok; then
  step "initramfs up to date"
else
  sudo mkinitcpio -P
  initramfs_ok || {
    echo "[ERROR] plymouth, the ctOS theme or nvidia_drm missing in the initramfs"
    exit 1
  }
  echo "$checksum" | sudo tee "$STATE_DIR/installed.sha256" >/dev/null
  step "initramfs rebuilt and checked"
fi

echo "[SPLASH] Done. Esc during boot: text boot log. Space at power-on: systemd-boot menu → '(boot log)' entry."
