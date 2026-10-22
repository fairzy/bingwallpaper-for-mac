#!/usr/bin/env bash
# 打 Mac App Store 包：沙盒签名的 .app，再包成已签名的 .pkg。
# 用法：scripts/build-appstore.sh
# 需要钥匙串里的 Apple Distribution、Mac Installer Distribution，
# 以及匹配 BUNDLE_ID 的 Mac App Store 描述文件。
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
BUNDLE_ID="${BUNDLE_ID:-com.fairzy.oneaday}"
TEAM_ID="${TEAM_ID:-2J6974AZ9L}"
DISPLAY_NAME="${DISPLAY_NAME:-OnePaper}"

# 公开仓库不写死接口地址。商店包要走别的服务器时，由外部导出 WALLPAPER_API_BASE。
DISPLAY_NAME="$DISPLAY_NAME" \
BUNDLE_ID="$BUNDLE_ID" \
VERSION="$VERSION" \
BUILD_NUMBER="$BUILD_NUMBER" \
APP_ICON="Sources/BingWallpaper/Resources/AppIcon.icns" \
PRIVACY_MANIFEST="Sources/BingWallpaper/Resources/PrivacyInfo.xcprivacy" \
WALLPAPER_API_BASE="${WALLPAPER_API_BASE:-}" \
SIGN_IDENTITY="-" \
scripts/build-app.sh

APP="build/${DISPLAY_NAME}.app"
rm -rf "$APP"
mv build/BingWallpaper.app "$APP"

IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' '/Apple Distribution|3rd Party Mac Developer Application/ {print $2; exit}')"
INSTALLER="$(security find-identity -v | awk -F'"' '/3rd Party Mac Developer Installer|Mac Installer Distribution/ {print $2; exit}')"
[ -n "$IDENTITY" ] || { echo "钥匙串里没有 Apple Distribution 证书" >&2; exit 1; }
[ -n "$INSTALLER" ] || { echo "钥匙串里没有 Mac Installer Distribution 证书" >&2; exit 1; }

PROFILE="${APPSTORE_PROFILE:-}"
if [ -z "$PROFILE" ]; then
  for f in "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"/*.provisionprofile; do
    [ -f "$f" ] || continue
    PL="$(security cms -D -i "$f" 2>/dev/null)" || continue
    APPID="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.application-identifier' /dev/stdin <<<"$PL" 2>/dev/null || true)"
    if [ "$APPID" = "$TEAM_ID.$BUNDLE_ID" ] && ! /usr/libexec/PlistBuddy -c 'Print :ProvisionedDevices' /dev/stdin <<<"$PL" >/dev/null 2>&1; then
      PROFILE="$f"
      break
    fi
  done
fi
[ -n "$PROFILE" ] && [ -f "$PROFILE" ] || { echo "没有找到 $BUNDLE_ID 的 Mac App Store 描述文件" >&2; exit 1; }

ENT="$(mktemp)"
cat > "$ENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key><true/>
    <key>com.apple.security.network.client</key><true/>
    <key>com.apple.security.assets.pictures.read-write</key><true/>
    <key>com.apple.application-identifier</key><string>${TEAM_ID}.${BUNDLE_ID}</string>
    <key>com.apple.developer.team-identifier</key><string>${TEAM_ID}</string>
</dict>
</plist>
EOF

cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"
codesign --force --options runtime --timestamp --entitlements "$ENT" --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"
rm -f "$ENT"

PKG="build/OneADay-${VERSION}.pkg"
rm -f "$PKG"
productbuild --component "$APP" /Applications --sign "$INSTALLER" "$PKG"
echo "Built $PKG"
