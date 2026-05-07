#!/bin/bash
# Build, notarize, staple, and package CodeOrb locally without GitHub/Sparkle/website publishing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
EXPORT_PATH="$BUILD_DIR/export"
RELEASE_DIR="$PROJECT_DIR/releases"
APP_NAME="CodeOrb"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"
KEYCHAIN_PROFILE="${CODEORB_KEYCHAIN_PROFILE:-CodeOrb}"
DMG_SIGN_IDENTITY="${CODEORB_DMG_SIGN_IDENTITY:-Developer ID Application: Peter Hu (95Z5ATAPUT)}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

cd "$PROJECT_DIR"

if [ "${SKIP_BUILD:-0}" != "1" ]; then
  echo "=== Build ==="
  PATH="$HOME/.gem/ruby/2.6.0/bin:$PATH" "$SCRIPT_DIR/build.sh"
fi

if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: App not found at $APP_PATH" >&2
  exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PATH/Contents/Info.plist")
mkdir -p "$RELEASE_DIR"

echo "=== Signing Check ==="
codesign -dv --verbose=2 "$APP_PATH" 2>&1 | sed -n '1,80p'

echo "=== Notarize App ==="
ZIP_PATH="$BUILD_DIR/$APP_NAME-$VERSION-$BUILD-$TIMESTAMP.zip"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait

xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

echo "=== Create DMG ==="
DMG_PATH="$RELEASE_DIR/$APP_NAME-$VERSION-$BUILD-$TIMESTAMP.dmg"
STAGING_DIR="$BUILD_DIR/dmg-staging"
MOUNT_DIR="$BUILD_DIR/dmg-mount"
RW_DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION-$BUILD-$TIMESTAMP-rw.dmg"
VOLUME_NAME="$APP_NAME"

rm -rf "$STAGING_DIR" "$MOUNT_DIR" "$RW_DMG_PATH" "$DMG_PATH"
mkdir -p "$STAGING_DIR" "$MOUNT_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov -format UDRW \
  "$RW_DMG_PATH"

MOUNT_OUTPUT=$(hdiutil attach "$RW_DMG_PATH" -readwrite -noverify -noautoopen -mountpoint "$MOUNT_DIR")
DEVICE=$(printf '%s\n' "$MOUNT_OUTPUT" | awk '/Apple_HFS|Apple_APFS/ {print $1; exit}')
MOUNT_PATH="$MOUNT_DIR"

if [ -n "$MOUNT_PATH" ] && [ -d "$MOUNT_PATH" ]; then
  osascript <<EOF || true
tell application "Finder"
  tell folder POSIX file "$MOUNT_PATH"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {100, 100, 620, 420}
    set arrangement of icon view options of container window to not arranged
    set icon size of icon view options of container window to 96
    set position of item "$APP_NAME.app" of container window to {155, 150}
    set position of item "Applications" of container window to {365, 150}
    close
  end tell
end tell
EOF
  # Give Finder time to flush .DS_Store layout metadata into the mounted image.
  sleep 2
  for attempt in 1 2 3 4 5; do
    if hdiutil detach "$DEVICE"; then
      break
    fi
    sleep 1
  done
fi

hdiutil convert "$RW_DMG_PATH" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH"

codesign --force --sign "$DMG_SIGN_IDENTITY" --timestamp "$DMG_PATH"

echo "=== Notarize DMG ==="
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl -a -vvv -t open --context context:primary-signature "$DMG_PATH"

echo "=== Complete ==="
echo "DMG: $DMG_PATH"
