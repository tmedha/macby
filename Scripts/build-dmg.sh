#!/bin/bash
# Builds a Release, ad-hoc-signed Macby.app and packages it into a
# drag-to-Applications .dmg, ready to attach to a GitHub Release.
#
# Ad-hoc signed means Gatekeeper will show an "unidentified developer"
# warning on first launch for anyone who downloads it — they need to
# right-click the app and choose Open once. See README.md for what's
# involved in real Developer ID signing/notarization instead.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BUILD_DIR="$ROOT_DIR/build"
RELEASE_DIR="$BUILD_DIR/Release"
DMG_STAGING_DIR="$BUILD_DIR/dmg-staging"

VERSION=$(grep 'MARKETING_VERSION' project.yml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
DMG_NAME="Macby-${VERSION}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

echo "==> Building Macby ${VERSION} (Release, ad-hoc signed)"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen not found. Install it with: brew install xcodegen" >&2
  exit 1
fi

echo "==> Regenerating Xcode project"
xcodegen generate

echo "==> Cleaning previous build output"
rm -rf "$RELEASE_DIR" "$DMG_STAGING_DIR" "$DMG_PATH"
mkdir -p "$RELEASE_DIR" "$DMG_STAGING_DIR"

echo "==> Compiling Release build"
xcodebuild \
  -project Macby.xcodeproj \
  -scheme Macby \
  -configuration Release \
  -destination 'platform=macOS' \
  CONFIGURATION_BUILD_DIR="$RELEASE_DIR" \
  build

APP_PATH="$RELEASE_DIR/Macby.app"
if [ ! -d "$APP_PATH" ]; then
  echo "error: build did not produce $APP_PATH" >&2
  exit 1
fi

echo "==> Verifying code signature (ad-hoc)"
codesign --verify --verbose "$APP_PATH"

echo "==> Staging DMG contents"
cp -R "$APP_PATH" "$DMG_STAGING_DIR/"

if command -v create-dmg >/dev/null 2>&1; then
  echo "==> Creating $DMG_NAME with create-dmg"
  create-dmg \
    --volname "Macby" \
    --window-size 540 380 \
    --icon-size 128 \
    --icon "Macby.app" 140 170 \
    --app-drop-link 400 170 \
    --hide-extension "Macby.app" \
    "$DMG_PATH" \
    "$DMG_STAGING_DIR" \
    || true # create-dmg returns non-zero on benign AppleScript/Finder warnings
else
  echo "==> create-dmg not found, falling back to a plain hdiutil image"
  echo "    (install 'brew install create-dmg' for a nicer drag-to-Applications layout)"
  ln -s /Applications "$DMG_STAGING_DIR/Applications"
  hdiutil create -volname "Macby" -srcfolder "$DMG_STAGING_DIR" -ov -format UDZO "$DMG_PATH"
fi

if [ ! -f "$DMG_PATH" ]; then
  echo "error: $DMG_PATH was not created" >&2
  exit 1
fi

echo "==> Done: $DMG_PATH"
ls -lh "$DMG_PATH"
