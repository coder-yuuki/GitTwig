#!/usr/bin/env bash
set -euo pipefail

APP_NAME="GitTwig"
PRODUCT_NAME="GitTwig"
BUNDLE_ID="${BUNDLE_ID:-dev.coderyuuki.GitTwig}"
MARKETING_VERSION="${MARKETING_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || printf '1')}"
CONFIGURATION="${CONFIGURATION:-release}"
DIST_DIR="${DIST_DIR:-dist}"
ICON_SOURCE="${ICON_SOURCE:-Assets/AppIcon.icns}"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
STAGING_DIR="$DIST_DIR/staging"
ZIP_PATH="$DIST_DIR/$APP_NAME-$MARKETING_VERSION.zip"
DMG_PATH="$DIST_DIR/$APP_NAME-$MARKETING_VERSION.dmg"
SPARKLE_FRAMEWORK_PATH=""

create_archives() {
    rm -rf "$STAGING_DIR" "$ZIP_PATH" "$DMG_PATH"
    mkdir -p "$STAGING_DIR"
    cp -R "$APP_BUNDLE" "$STAGING_DIR/"
    ln -s /Applications "$STAGING_DIR/Applications"

    ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
    hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"
}

sign_bundle() {
    local target="$1"

    if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
        codesign --force --timestamp --options runtime --sign "$CODESIGN_IDENTITY" "$target"
    else
        codesign --force --sign - "$target"
    fi
}

sign_sparkle_framework() {
    local framework="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
    local version_dir="$framework/Versions/B"

    sign_bundle "$version_dir/Autoupdate"
    sign_bundle "$version_dir/Updater.app"
    sign_bundle "$version_dir/XPCServices/Downloader.xpc"
    sign_bundle "$version_dir/XPCServices/Installer.xpc"
    sign_bundle "$framework"
}

if [[ ! -f "$ICON_SOURCE" ]]; then
    printf 'Missing app icon: %s\n' "$ICON_SOURCE" >&2
    exit 1
fi

if [[ "${NOTARIZE:-0}" == "1" ]]; then
    : "${CODESIGN_IDENTITY:?CODESIGN_IDENTITY is required when NOTARIZE=1}"
    : "${NOTARY_KEYCHAIN_PROFILE:?NOTARY_KEYCHAIN_PROFILE is required when NOTARIZE=1}"
fi

swift build -c "$CONFIGURATION" --product "$PRODUCT_NAME"

SPARKLE_FRAMEWORK_PATH="$(
    find .build/artifacts -path '*/Sparkle.framework' -type d -print -quit
)"

if [[ -z "$SPARKLE_FRAMEWORK_PATH" ]]; then
    printf 'Missing Sparkle.framework in .build/artifacts\n' >&2
    exit 1
fi

rm -rf "$APP_BUNDLE" "$STAGING_DIR" "$ZIP_PATH" "$DMG_PATH"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$APP_BUNDLE/Contents/Frameworks"

cp ".build/$CONFIGURATION/$PRODUCT_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod 755 "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ICON_SOURCE" "$APP_BUNDLE/Contents/Resources/$APP_NAME.icns"
cp -R "$SPARKLE_FRAMEWORK_PATH" "$APP_BUNDLE/Contents/Frameworks/"

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
    <key>CFBundleIconFile</key>
    <string>$APP_NAME.icns</string>
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
    <string>Copyright © 2026 coder-yuuki</string>
    <key>SUFeedURL</key>
    <string>https://github.com/coder-yuuki/GitTwig/releases/latest/download/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>LtjngVaI/SxPM3ik39+ZxU8unE22ERWhwaBbvly0TEY=</string>
</dict>
</plist>
PLIST

/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP_BUNDLE/Contents/Info.plist" >/dev/null

sign_sparkle_framework
sign_bundle "$APP_BUNDLE"

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

create_archives

if [[ "${NOTARIZE:-0}" == "1" ]]; then
    xcrun notarytool submit "$ZIP_PATH" \
        --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
        --wait
    xcrun stapler staple "$APP_BUNDLE"
    xcrun stapler validate "$APP_BUNDLE"

    create_archives
    xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
        --wait
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
fi

printf '%s\n' "$ZIP_PATH"
printf '%s\n' "$DMG_PATH"
