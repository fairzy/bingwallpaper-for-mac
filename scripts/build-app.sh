#!/usr/bin/env bash
# 构建 BingWallpaper.app（arm64 + x86_64 通用二进制）。
# ad-hoc 签名不能加时间戳；Developer ID 必须加，否则公证会被拒。
# 用法：scripts/build-app.sh            输出 build/BingWallpaper.app
#      BUNDLE_ID=com.foo.bar VERSION=1.2.0 SIGN_IDENTITY="Developer ID Application: ..." scripts/build-app.sh
# 不设置 WALLPAPER_API_BASE 时，应用连必应官方接口。设置了才会写入 Info.plist。
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="BingWallpaper"
DISPLAY_NAME="${DISPLAY_NAME:-Bing Wallpaper}"
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
    <key>CFBundleDevelopmentRegion</key><string>zh-Hans</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>zh-Hans</string>
        <string>zh-Hant</string>
        <string>en</string>
        <string>ja</string>
        <string>de</string>
        <string>fr</string>
        <string>es</string>
        <string>it</string>
        <string>pt-BR</string>
    </array>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleName</key><string>${DISPLAY_NAME}</string>
    <key>CFBundleDisplayName</key><string>${DISPLAY_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>ITSAppUsesNonExemptEncryption</key><false/>
</dict>
</plist>
PLIST

if [ -n "${WALLPAPER_API_BASE:-}" ]; then
  /usr/libexec/PlistBuddy -c "Add :WallpaperAPIBaseURL string ${WALLPAPER_API_BASE}" "$APP/Contents/Info.plist"
fi

for lproj in Sources/BingWallpaper/Resources/*.lproj; do
  cp -R "$lproj" "$APP/Contents/Resources/"
done

# 仓库里的图标是默认应用图标。调用方仍可用 APP_ICON 换一张。
APP_ICON="${APP_ICON:-Sources/BingWallpaper/Resources/AppIcon.icns}"
if [ -n "$APP_ICON" ] && [ -f "$APP_ICON" ]; then
  cp "$APP_ICON" "$APP/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "$APP/Contents/Info.plist"
fi
if [ -n "${PRIVACY_MANIFEST:-}" ]; then
  cp "$PRIVACY_MANIFEST" "$APP/Contents/Resources/PrivacyInfo.xcprivacy"
fi

if [ "$SIGN_IDENTITY" = "-" ]; then
  codesign --force --options runtime --timestamp=none --sign "$SIGN_IDENTITY" "$APP"
else
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi
codesign --verify --strict "$APP"
lipo -archs "$APP/Contents/MacOS/$APP_NAME"
echo "Built $APP"
