#!/usr/bin/env bash
# 构建 BingWallpaper.app（arm64 + x86_64 通用二进制，ad-hoc 签名）。
# 用法：scripts/build-app.sh            输出 build/BingWallpaper.app
#      BUNDLE_ID=com.foo.bar VERSION=1.2.0 SIGN_IDENTITY="Developer ID Application: ..." scripts/build-app.sh
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="BingWallpaper"
DISPLAY_NAME="Bing Wallpaper"
BUNDLE_ID="${BUNDLE_ID:-com.example.bingwallpaper}"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

APP="build/${APP_NAME}.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${DISPLAY_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --options runtime --timestamp=none --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --strict "$APP"
lipo -archs "$APP/Contents/MacOS/$APP_NAME"
echo "Built $APP"
