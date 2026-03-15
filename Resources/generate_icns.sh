#!/bin/bash

# This script generates a multi-resolution AppIcon.icns from a source PNG file.
# It uses Apple's 'sips' for resizing and 'iconutil' for packing.

SRC_PNG="Resources/icon.png"
ICONSET_DIR="Resources/AppIcon.iconset"
OUTPUT_ICNS="Resources/AppIcon.icns"

if [ ! -f "$SRC_PNG" ]; then
    echo "Error: $SRC_PNG not found."
    exit 1
fi

echo "🎨 Generating iconset from $SRC_PNG..."

mkdir -p "$ICONSET_DIR"

# Standard sizes
sips -z 16 16     "$SRC_PNG" --out "$ICONSET_DIR/icon_16x16.png" > /dev/null 2>&1
sips -z 32 32     "$SRC_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null 2>&1
sips -z 32 32     "$SRC_PNG" --out "$ICONSET_DIR/icon_32x32.png" > /dev/null 2>&1
sips -z 64 64     "$SRC_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null 2>&1
sips -z 128 128   "$SRC_PNG" --out "$ICONSET_DIR/icon_128x128.png" > /dev/null 2>&1
sips -z 256 256   "$SRC_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null 2>&1
sips -z 256 256   "$SRC_PNG" --out "$ICONSET_DIR/icon_256x256.png" > /dev/null 2>&1
sips -z 512 512   "$SRC_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null 2>&1
sips -z 512 512   "$SRC_PNG" --out "$ICONSET_DIR/icon_512x512.png" > /dev/null 2>&1
sips -z 1024 1024 "$SRC_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null 2>&1

echo "📦 Converting iconset to .icns..."
iconutil -c icns "$ICONSET_DIR"

if [ -f "$OUTPUT_ICNS" ]; then
    echo "✅ Successfully created $OUTPUT_ICNS"
    rm -rf "$ICONSET_DIR"
else
    echo "❌ Failed to create $OUTPUT_ICNS"
    exit 1
fi
