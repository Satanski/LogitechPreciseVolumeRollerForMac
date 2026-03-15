#!/bin/bash

# Exit on error
set -e

# Configuration
APP_NAME="Logitech Precise Volume Roller"
BUNDLE_ID="com.satanski.LogitechPreciseVolumeRoller"
EXECUTABLE_NAME="LogitechPreciseVolumeRollerForMac"
BUNDLE_DIR="${APP_NAME}.app"

# Resolve version from the latest git tag (falls back to 'dev' if no tag exists)
VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "dev")
echo "🏷️  Version: $VERSION"

echo "🔨 Building Logitech Precise Volume Roller in Release mode..."
swift build -c release

# Create bundle structure
echo "📂 Creating .app bundle structure..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

# Copy binary
echo "🚀 Copying binary..."
BINARY_SOURCE=$(swift build -c release --show-bin-path)/$EXECUTABLE_NAME
if [ ! -f "$BINARY_SOURCE" ]; then
    echo "❌ Binary not found at $BINARY_SOURCE"
    exit 1
fi

cp "$BINARY_SOURCE" "$BUNDLE_DIR/Contents/MacOS/"
chmod +x "$BUNDLE_DIR/Contents/MacOS/$EXECUTABLE_NAME"

# Copy Info.plist
echo "📄 Copying Info.plist..."
cp "Resources/Info.plist" "$BUNDLE_DIR/Contents/"

# Create PkgInfo
echo "APPL????" > "$BUNDLE_DIR/Contents/PkgInfo"

# Generate icon if needed
if [ -f "Resources/icon.png" ]; then
    # Improved check for CI environments
    if [ ! -f "Resources/AppIcon.icns" ] || [ "Resources/icon.png" -nt "Resources/AppIcon.icns" ] || [ "$CI" == "true" ]; then
        echo "🎨 Generating AppIcon.icns from icon.png..."
        chmod +x Resources/generate_icns.sh
        ./Resources/generate_icns.sh
    fi
fi

# Copy Resources
if [ -f "Resources/AppIcon.icns" ]; then
    echo "🖼️ Copying AppIcon.icns..."
    cp "Resources/AppIcon.icns" "$BUNDLE_DIR/Contents/Resources/"
fi

# Sign the bundle
echo "✍️  Ad-hoc signing the app bundle..."
codesign --force --deep -s - "$BUNDLE_DIR" || { echo "❌ Signing failed"; exit 1; }

# Create ZIP — use dots in the base name and append the version tag
ZIP_BASENAME=$(echo "$APP_NAME" | tr ' ' '.')
ZIP_NAME="${ZIP_BASENAME}-${VERSION}.zip"
echo "📦 Creating ZIP archive: $ZIP_NAME..."
rm -f "$ZIP_NAME"
# Use -r for recursive and -y to preserve symlinks
zip -ry9 "$ZIP_NAME" "$BUNDLE_DIR" > /dev/null

echo "✅ Done! Application bundled in $BUNDLE_DIR"
echo "📦 Distributable archive created: $ZIP_NAME"

