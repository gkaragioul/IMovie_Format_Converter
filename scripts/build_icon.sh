#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS_DIR="$ROOT_DIR/Assets"
ICONSET_DIR="$ASSETS_DIR/AppIcon.iconset"
BASE_PNG="$ASSETS_DIR/AppIcon-1024.png"
ICNS_FILE="$ASSETS_DIR/AppIcon.icns"

mkdir -p "$ASSETS_DIR"

swift "$ROOT_DIR/scripts/generate_icon.swift" "$BASE_PNG"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$BASE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
  double_size=$((size * 2))
  sips -z "$double_size" "$double_size" "$BASE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET_DIR" -o "$ICNS_FILE"
rm -rf "$ICONSET_DIR"

echo "Built icon: $ICNS_FILE"
