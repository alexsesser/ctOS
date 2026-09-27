#!/usr/bin/env bash
# Renders the Plymouth theme images into plymouth/. Needs ImageMagick, rsvg-convert and
# JetBrainsMono Nerd Font. Only has to be re-run after changing this script;
# the generated PNGs are part of the theme.
#
# Everything is rendered at 2x the size it has on a 1080p screen (the greeter's
# reference resolution); ctos.script scales by screen height / 1080 / 2.

set -euo pipefail

cd "$(dirname "$0")"

OUT=plymouth
CTOS_DIR=..
FONT_DIR=/usr/share/fonts/TTF

LIGHT=$FONT_DIR/JetBrainsMonoNerdFont-Light.ttf
REGULAR=$FONT_DIR/JetBrainsMonoNerdFont-Regular.ttf
MEDIUM=$FONT_DIR/JetBrainsMonoNerdFont-Medium.ttf

# colors from ctOS common/Theme.qml
BACKGROUND="#0E0E0E"     # gray800
CTOS_GRAY="#D9D9D9"      # gray200: splash bar
TEXT_PRIMARY="#FFFFFF"   # gray50
TEXT_DIM="#CACACA"       # gray100
TEXT_DIMMER="#C3C3C3"    # gray300
TEXT_SECONDARY="#7A7A7A" # gray500

mkdir -p "$OUT"

# trimmed glyphs, positioned by their bounding box in the script
glyph() { # file font size color text
  magick -background none -fill "$4" -font "$2" -pointsize "$3" "label:$5" -trim +repage "$OUT/$1"
}

# full text line (constant height and advance, so lines line up)
line() { # file font size color text
  magick -background none -fill "$4" -font "$2" -pointsize "$3" "label:$5" "$OUT/$1"
}

# 1x1 pixels, scaled to rectangles in the script
magick -size 1x1 "xc:$CTOS_GRAY" "$OUT/bar.png"
magick -size 1x1 "xc:$TEXT_SECONDARY" "$OUT/track.png"

# splash: "CT" (dark, inside the bar) and "OS"
glyph os.png "$LIGHT" 128 "$TEXT_PRIMARY" "OS"
glyph ct.png "$MEDIUM" 68 "$BACKGROUND" "CT"

# corner accents, same svg as the greeter
rsvg-convert -w 8 -h 8 "$CTOS_DIR/greeter/resources/accent.svg" -o "$OUT/accent-tl.png"
magick "$OUT/accent-tl.png" -rotate 90 "$OUT/accent-tr.png"
magick "$OUT/accent-tl.png" -rotate 180 "$OUT/accent-br.png"
magick "$OUT/accent-tl.png" -rotate 270 "$OUT/accent-bl.png"

# status line under the splash (greeter: 14px)
for mode in boot shutdown reboot; do
  case $mode in
    boot) text="INITIALIZING" ;;
    shutdown) text="SHUTTING DOWN" ;;
    reboot) text="REBOOTING" ;;
  esac
  for dots in 0 1 2 3; do
    line "status-$mode-$dots.png" "$REGULAR" 28 "$TEXT_DIMMER" "$text$(printf '%*s' "$dots" '' | tr ' ' '.')"
  done
done

for digit in 0 1 2 3 4 5 6 7 8 9; do
  line "digit-$digit.png" "$MEDIUM" 28 "$TEXT_DIM" "$digit"
done

# password prompt (encrypted disks) and its bullets (greeter: "█")
line password.png "$REGULAR" 28 "$TEXT_DIMMER" "PASSPHRASE:"
line bullet.png "$REGULAR" 28 "$TEXT_PRIMARY" "█"

# hint in the bottom left corner (greeter: PowerHints, 12px)
line hint.png "$REGULAR" 24 "$TEXT_DIMMER" "[ESC]  Boot log"

echo "Assets written to $OUT/"
