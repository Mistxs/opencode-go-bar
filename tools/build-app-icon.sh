#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

swift tools/make-app-icon.swift "$TMP/app-icon.png"

ICONSET="$TMP/AppIcon.iconset"
mkdir -p "$ICONSET"

for spec in "16 icon_16x16" "32 icon_16x16@2x" "32 icon_32x32" "64 icon_32x32@2x" \
            "128 icon_128x128" "256 icon_128x128@2x" "256 icon_256x256" \
            "512 icon_256x256@2x" "512 icon_512x512" "1024 icon_512x512@2x"; do
  set -- $spec
  sips -z "$1" "$1" "$TMP/app-icon.png" --out "$ICONSET/$2.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
cp "$TMP/app-icon.png" docs/app-icon.png

echo "==> Resources/AppIcon.icns и docs/app-icon.png обновлены"
