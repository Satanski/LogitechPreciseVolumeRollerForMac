#!/bin/bash

# Configuration
APP_NAME="LogitechPreciseVolumeRoller"
BUNDLE_ID="com.user.LogitechPreciseVolumeRoller"
EXECUTABLE_NAME="LogitechPreciseVolumeRollerForMac"
BUNDLE_DIR="${APP_NAME}.app"

echo "🔨 Building Logitech Precise Volume Roller in Release mode..."
swift build -c release

# Create bundle structure
echo "📂 Creating .app bundle structure..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

# Copy binary
echo "🚀 Copying binary..."
cp ".build/release/$EXECUTABLE_NAME" "$BUNDLE_DIR/Contents/MacOS/"

# Copy Info.plist
echo "📄 Copying Info.plist..."
cp "Resources/Info.plist" "$BUNDLE_DIR/Contents/"

# Copy Resources (icon if exists)
if [ -f "Resources/icon.png" ]; then
    echo "🖼️ Copying icon.png..."
    cp "Resources/icon.png" "$BUNDLE_DIR/Contents/Resources/"
fi

# Sign the bundle
echo "✍️  Ad-hoc signing the app bundle..."
codesign --force --deep -s - "$BUNDLE_DIR"

echo "✅ Done! Application bundled in $BUNDLE_DIR"
echo "👉 You can now move $BUNDLE_DIR to your /Applications folder."
