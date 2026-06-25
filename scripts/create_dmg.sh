#!/bin/bash
set -e

# Always resolve paths relative to the repository root, not the script location.
# This allows the script to be called from any working directory and from
# subdirectories (e.g., scripts/) without breaking xcodebuild path references.
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

APP_PATH=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-path)
      APP_PATH="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$APP_PATH" ]]; then
  # Local developer mode: build the app first, then package
  echo "=== Building Drawl in Release Configuration ==="
  xcodebuild -project Drawl.xcodeproj -scheme Drawl -configuration Release -derivedDataPath build clean build
  APP_PATH="build/Build/Products/Release/Drawl.app"
else
  echo "=== Using pre-built app at: $APP_PATH ==="
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Error: app not found at $APP_PATH" >&2
  exit 1
fi

echo "=== Packaging Application ==="
TEMP_DIR="build/dmg_temp"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

echo "Copying Drawl.app to staging area..."
cp -R "$APP_PATH" "$TEMP_DIR/"

echo "Creating Applications shortcut..."
ln -s /Applications "$TEMP_DIR/Applications"

echo "Creating DMG..."
DMG_PATH="build/Drawl.dmg"
rm -f "$DMG_PATH"

hdiutil create -volname "Drawl Installer" -srcfolder "$TEMP_DIR" -ov -format UDZO "$DMG_PATH"

# Cleanup staging area
rm -rf "$TEMP_DIR"

echo "=== DMG Created Successfully ==="
echo "DMG path: $(pwd)/$DMG_PATH"
