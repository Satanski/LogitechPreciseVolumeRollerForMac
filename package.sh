#!/bin/bash

# Configuration
APP_NAME="Logitech Precise Volume Roller"
BUNDLE_ID="com.satanski.LogitechPreciseVolumeRoller"
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

# Generate icon if needed
if [ -f "Resources/icon.png" ]; then
    if [ ! -f "Resources/AppIcon.icns" ] || [ "Resources/icon.png" -nt "Resources/AppIcon.icns" ]; then
        echo "🎨 Generating AppIcon.icns from icon.png..."
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

# Create ZIP
ZIP_NAME="${APP_NAME}.zip"
echo "📦 Creating ZIP archive: $ZIP_NAME..."
rm -f "$ZIP_NAME"
zip -r9 "$ZIP_NAME" "$BUNDLE_DIR" > /dev/null

echo "✅ Done! Application bundled in $BUNDLE_DIR"
echo "📦 Distributable archive created: $ZIP_NAME"
echo "👉 You can now move $BUNDLE_DIR to your /Applications folder or share $ZIP_NAME."
