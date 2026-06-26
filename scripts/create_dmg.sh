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

if ! command -v create-dmg &>/dev/null; then
  echo "Error: create-dmg not found. Install with: brew install create-dmg" >&2
  exit 1
fi

echo "=== Packaging Application ==="

DMG_PATH="build/Drawl.dmg"
rm -f "$DMG_PATH"

create-dmg \
  --volname "Drawl" \
  --window-pos 200 120 \
  --window-size 540 380 \
  --icon-size 100 \
  --icon "Drawl.app" 140 190 \
  --hide-extension "Drawl.app" \
  --app-drop-link 400 190 \
  "$DMG_PATH" \
  "$APP_PATH"

echo "=== DMG Created Successfully ==="
echo "DMG path: $(pwd)/$DMG_PATH"
