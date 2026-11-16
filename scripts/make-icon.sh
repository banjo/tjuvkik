#!/bin/sh
# Renders Resources/AppIcon.svg into Resources/AppIcon.icns. Needs rsvg-convert (brew install librsvg).
set -eu
cd "$(dirname "$0")/.."

set=$(mktemp -d)/AppIcon.iconset
mkdir -p "$set"
for size in 16 32 128 256 512; do
  rsvg-convert -w "$size" -h "$size" Resources/AppIcon.svg -o "$set/icon_${size}x${size}.png"
  rsvg-convert -w $((size * 2)) -h $((size * 2)) Resources/AppIcon.svg -o "$set/icon_${size}x${size}@2x.png"
done
iconutil -c icns "$set" -o Resources/AppIcon.icns
rm -rf "$(dirname "$set")"
echo "Wrote Resources/AppIcon.icns"
