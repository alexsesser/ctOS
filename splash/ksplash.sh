#!/usr/bin/env bash
# Plasma splash (KSplash) with the ctOS logo, shown right after login.
# Per-user, no root needed. Called by install.sh / uninstall.sh.
#
#   ./ksplash.sh install     install and select the ctOS splash
#   ./ksplash.sh uninstall   remove it and select the previous splash again

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(dirname "$SCRIPT_DIR")

# run for the invoking user even under sudo
if [[ $EUID -eq 0 && -n ${SUDO_USER:-} ]]; then
  exec sudo -u "$SUDO_USER" "$0" "$@"
fi

THEME_ID=ctOS
DEST=${XDG_DATA_HOME:-$HOME/.local/share}/plasma/look-and-feel/$THEME_ID
STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/ctos-boot
PREVIOUS_FILE=$STATE_DIR/ksplash-previous

current_theme() {
  kreadconfig6 --file ksplashrc --group KSplash --key Theme
}

case ${1:-} in
  install)
    mkdir -p "$DEST" "$STATE_DIR"
    rsync -a --delete "$SCRIPT_DIR/ksplash/$THEME_ID/" "$DEST/"
    # background grid and corner accents of the greeter
    install -Dm 644 "$REPO_DIR/greeter/resources/lock.png" "$DEST/contents/splash/images/lock.png"
    install -Dm 644 "$REPO_DIR/greeter/resources/accent.svg" "$DEST/contents/splash/images/accent.svg"

    previous=$(current_theme)
    if [[ $previous != "$THEME_ID" ]]; then
      printf '%s\n' "$previous" >"$PREVIOUS_FILE"
    fi

    kwriteconfig6 --file ksplashrc --group KSplash --key Engine KSplashQML
    kwriteconfig6 --file ksplashrc --group KSplash --key Theme "$THEME_ID"
    saved=""
    [[ -f $PREVIOUS_FILE ]] && saved=$(<"$PREVIOUS_FILE")
    echo "[ITEM] plasma splash: $DEST (uninstall restores: ${saved:-default})"
    ;;
  uninstall)
    previous=""
    [[ -f $PREVIOUS_FILE ]] && previous=$(<"$PREVIOUS_FILE")

    if [[ $(current_theme) == "$THEME_ID" ]]; then
      if [[ -n $previous ]]; then
        kwriteconfig6 --file ksplashrc --group KSplash --key Theme "$previous"
      else
        kwriteconfig6 --file ksplashrc --group KSplash --key Theme --delete
      fi
    fi

    rm -rf "$DEST" "$STATE_DIR"
    echo "[ITEM] plasma splash removed (restored: ${previous:-default})"
    ;;
  *)
    echo "usage: $0 install|uninstall" >&2
    exit 1
    ;;
esac
