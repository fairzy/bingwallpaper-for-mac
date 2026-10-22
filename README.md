**English** · [简体中文](docs/readme/zh-Hans.md) · [繁體中文](docs/readme/zh-Hant.md) · [日本語](docs/readme/ja.md) · [Deutsch](docs/readme/de.md) · [Français](docs/readme/fr.md) · [Español](docs/readme/es.md)

# Bing Wallpaper for macOS

**Bing's daily photo, on your Mac — automatically.** A small menu-bar app that fetches the Bing daily wallpaper and sets it as your desktop. Free and open source (MIT). The release DMG is Developer ID signed and notarized.

- New Bing daily image every day, applied automatically (checks every 30 minutes)
- Lives in the menu bar — preview, pause, or step back through recent days
- Theme collections that rotate once a day
- Starts at login. Universal binary for Apple silicon and Intel. macOS 14+

**[Download DMG](https://github.com/fairzy/bingwallpaper-for-mac/releases/download/v1.0.0/BingWallpaper-1.0.0.dmg)** · **[Website](https://fairzy.github.io/bingwallpaper-for-mac/)** · **[GitHub](https://github.com/fairzy/bingwallpaper-for-mac)**

> Unofficial open-source project. Not affiliated with Microsoft. Bing and the daily images belong to Microsoft and the photographers.

This repository is the free edition. Your Mac talks to Bing's public API directly. A separate Mac App Store app, OnePaper - 必应同源每日壁纸, is coming soon. The menu-bar name is OnePaper. It is paid (US$2.99), loads images through our own service, and can be installed next to this one. See the [website](https://fairzy.github.io/bingwallpaper-for-mac/#store) for the difference.

Behavior follows the Windows app 1.1.469.0. Notes are in [BingWallpaper-实现笔记.md](BingWallpaper-实现笔记.md) (Chinese).

## Build and run

macOS 14+, Xcode 16+ (Swift 6).

```bash
swift test                                   # unit tests, offline
BW_LIVE_TESTS=1 swift test --filter LiveAPITests   # live API tests
scripts/build-app.sh                         # writes build/BingWallpaper.app
open build/BingWallpaper.app
```

`swift run` works for debugging. Login at startup only works when the app is a real `.app`.

Leave `WALLPAPER_API_BASE` unset. The open-source build then uses Bing's public API.

## Layout

```text
Sources/BingWallpaperCore/   testable code, no UI
  BingImage.swift            hpimages record: id, download URL, file name
  ThemeCategory.swift        themes and the market list
  BingAPIClient.swift        services.bingapis.com v2
  Resilience.swift           retry with backoff, circuit breaker (Polly)
  ImageStore.swift           temp file, size and format checks, index, cleanup
  RefreshPolicy.swift        30-minute cycle, failure backoff, jitter
Sources/BingWallpaper/       SwiftUI menu-bar app
  AppModel.swift             refresh loop, automatic apply, user actions
  Preferences.swift          UserDefaults
  SystemIntegration.swift    wallpaper, login item, thumbnails
  Views/                     popover and settings
```

## Windows app

| Windows | macOS |
| --- | --- |
| `BingHPImageService` builds the `hpimages` URL, downloads, checks, retries with Polly | `BingAPIClient` + `ImageStore` + `withRetry` / `CircuitBreaker` |
| `DailyRefreshService` every 30 minutes (5 when `MioFastRefreshEnabled`) | `AppModel.start()` loop; `defaults write <bundle-id> FastRefreshEnabled -bool YES` |
| Skip when the previous pass is still running; back off on an empty catalog | `isCycleRunning`; `RefreshPolicy.retryDelay` |
| `RotateThemeImageDailyMessage` | Non-Bing themes rotate one image a day |
| `ImageCleanup`, hard links per theme | One shared `images/` folder, cleaned from `index.json` |
| Startup task `BingWallpaperStartupTask` | `SMAppService.mainApp`, turned on at first launch |
| Scheduled task launches the process twice a day | Not needed: refresh on wake, and `Task.sleep` uses a continuous clock |
| LiteDB `images.db` | `~/Library/Application Support/BingWallpaper/index.json` |

## Not ported

- `defaultBrowser` / `dhpSetToBing` / `dseSetToBing`: Windows default-app prompts. On Mac the request sends an empty value and `false`.
- Telemetry, `MegaIntroOffer`, remote `server_config.json`, hot config updates.
- A bundled offline default image. When the network is down, the last cached photo stays.
- Gallery search, `bwc/metadata`, widgets.

## Limits

- macOS can change the wallpaper of the current Space only. Other Spaces are filled when you switch to them.
- `scripts/build-app.sh` still defaults to the placeholder bundle id `com.example.bingwallpaper`. The notarized release uses `com.fairzy.bingwallpaper`.

## Sponsor

These are the other products we make.

- [Wear.AI](https://wear-ai.online) — try clothes on a photo.
- [Live.AI](https://livephoto-ai.online) — turn a still photo into a Live Photo.
- [Picturebookpedia](https://www.picturebookpedia.cn) — 豆芽绘本百科, a picture-book guide.
- [Little Earthpedia](https://earthpedia.picturebookpedia.cn) — 地球小百科, a 3D earth encyclopedia for children.
- [DinoPedia](https://dino.picturebookpedia.cn) — 恐龙小百科, a dinosaur encyclopedia for children.
- [Animal Friends](https://animalfriends.picturebookpedia.cn) — 动物好朋友, voice chats with animal characters for young children.
- [Clean.AI](https://aiclean.picturebookpedia.cn) — AI disk cleanup for Mac.
