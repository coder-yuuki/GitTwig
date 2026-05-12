#!/usr/bin/env bash
set -euo pipefail

APP_NAME="GitTwig"
PRODUCT_NAME="GitTwig"
BUNDLE_ID="${BUNDLE_ID:-dev.coderyuuki.GitTwig}"
MARKETING_VERSION="${MARKETING_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || printf '1')}"
CONFIGURATION="${CONFIGURATION:-release}"
DIST_DIR="${DIST_DIR:-dist}"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
STAGING_DIR="$DIST_DIR/staging"
ZIP_PATH="$DIST_DIR/$APP_NAME-$MARKETING_VERSION.zip"
DMG_PATH="$DIST_DIR/$APP_NAME-$MARKETING_VERSION.dmg"

swift build -c "$CONFIGURATION" --product "$PRODUCT_NAME"

rm -rf "$APP_BUNDLE" "$STAGING_DIR" "$ZIP_PATH" "$DMG_PATH"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp ".build/$CONFIGURATION/$PRODUCT_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod 755 "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$MARKETING_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 coder-yuuki. All rights reserved.</string>
</dict>
</plist>
PLIST

/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP_BUNDLE/Contents/Info.plist" >/dev/null

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    codesign --force --timestamp --options runtime --sign "$CODESIGN_IDENTITY" "$APP_BUNDLE"
else
    codesign --force --sign - "$APP_BUNDLE"
fi

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"

if [[ "${NOTARIZE:-0}" == "1" ]]; then
    : "${NOTARY_KEYCHAIN_PROFILE:?NOTARY_KEYCHAIN_PROFILE is required when NOTARIZE=1}"

    xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
        --wait
    xcrun stapler staple "$DMG_PATH"
fi

printf '%s\n' "$ZIP_PATH"
printf '%s\n' "$DMG_PATH"
