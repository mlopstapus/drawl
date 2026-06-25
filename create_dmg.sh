#!/bin/bash
set -e

# Change directory to the script's directory (repository root)
cd "$(dirname "$0")"

echo "=== Building Drawl in Release Configuration ==="
xcodebuild -project Drawl.xcodeproj -scheme Drawl -configuration Release -derivedDataPath build clean build

echo "=== Packaging Application ==="
TEMP_DIR="build/dmg_temp"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

echo "Copying Drawl.app to staging area..."
cp -R build/Build/Products/Release/Drawl.app "$TEMP_DIR/"

echo "Creating Applications shortcut..."
ln -s /Applications "$TEMP_DIR/Applications"

echo "Creating DMG..."
DMG_PATH="build/Drawl.dmg"
rm -f "$DMG_PATH"

hdiutil create -volname "Drawl Installer" -srcfolder "$TEMP_DIR" -ov -format UDZO "$DMG_PATH"

# Cleanup staging area
rm -rf "$TEMP_DIR"

echo "=== DMG Created Successfully ==="
echo "You can find your installer at: $(pwd)/$DMG_PATH"
