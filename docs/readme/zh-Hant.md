[English](../../README.md) · [简体中文](zh-Hans.md) · **繁體中文** · [日本語](ja.md) · [Deutsch](de.md) · [Français](fr.md) · [Español](es.md)

# 必應每日桌布 for Mac

**必應每天的一張圖，自動換上你的 Mac。** 選單列裡的小程式。免費，開源（MIT）。發布用的 DMG 以 Developer ID 簽署，並經過 Apple 公證。

- 每日一張新圖，自動換上桌面（大約每 30 分鐘看一次）
- 只住在選單列：預覽、暫停，或往前翻這幾天
- 主題合集按天輪換
- 登入時啟動。Apple 晶片與 Intel 通用二進位。macOS 14+

**[下載 DMG](https://github.com/fairzy/bingwallpaper-for-mac/releases/download/v1.1.0/BingWallpaper-1.1.0.dmg)** · **[網站](https://fairzy.github.io/bingwallpaper-for-mac/)** · **[GitHub](https://github.com/fairzy/bingwallpaper-for-mac)**

> 非官方開源專案，與 Microsoft 無關。Bing 和每日圖片屬於微軟和拍攝者。

這個倉庫是免費的開源版。你的 Mac 直接連接必應的公開介面。Mac App Store 上另有一個 App「OnePaper - 必应同源每日壁纸」，即將上架。選單列顯示的名字是 OnePaper。它是付費的（US$2.99），圖片經過我們自己的伺服器，可以和這個開源版同時安裝。差別寫在[網站](https://fairzy.github.io/bingwallpaper-for-mac/#store)。

行為對齊 Windows 版 1.1.469.0，依據 [實現筆記](../../BingWallpaper-实现笔记.md)（簡體中文）。

## 建置與執行

需要 macOS 14+、Xcode 16+（Swift 6）。

```bash
swift test                                   # 單元測試，不連網
BW_LIVE_TESTS=1 swift test --filter LiveAPITests   # 連網測試
scripts/build-app.sh                         # 產生 build/BingWallpaper.app
open build/BingWallpaper.app
```

除錯可以用 `swift run`。「登入時啟動」只有真正的 `.app` 才可用。

不要設定 `WALLPAPER_API_BASE`。開源建置會使用必應的公開介面。

## 結構

```text
Sources/BingWallpaperCore/   與介面無關、可測試
  BingImage.swift            hpimages 紀錄：圖片 ID、下載網址、檔名
  ThemeCategory.swift        主題目錄、市場清單
  BingAPIClient.swift        services.bingapis.com v2
  Resilience.swift           指數退避重試、熔斷（對應 Polly）
  ImageStore.swift           暫存檔、長度與格式檢查、索引、清理
  RefreshPolicy.swift        30 分鐘週期、失敗退避、抖動
Sources/BingWallpaper/       SwiftUI 選單列 App
  AppModel.swift             重新整理週期、自動換圖、使用者操作
  Preferences.swift          UserDefaults
  SystemIntegration.swift    桌布、登入啟動、縮圖
  Views/                     彈出面板與設定
```

## 與 Windows 版的對應

| Windows | macOS |
| --- | --- |
| `BingHPImageService` 組 `hpimages` 網址、下載、檢查、Polly 重試 | `BingAPIClient` + `ImageStore` + `withRetry` / `CircuitBreaker` |
| `DailyRefreshService` 每 30 分鐘（`MioFastRefreshEnabled` 時 5 分鐘） | `AppModel.start()` 迴圈；`defaults write <bundle-id> FastRefreshEnabled -bool YES` |
| 上一輪未完成就跳過；空目錄則退避 | `isCycleRunning`；`RefreshPolicy.retryDelay` |
| `RotateThemeImageDailyMessage` | 非 Bing 主題每天輪換一張 |
| `ImageCleanup`、按主題硬連結 | 所有主題共用 `images/`，依 `index.json` 清理 |
| 登入啟動工作 `BingWallpaperStartupTask` | `SMAppService.mainApp`，第一次啟動自動開啟 |
| 排程工作一天拉起兩次 | 不需要：系統喚醒後立刻重新整理，`Task.sleep` 用連續時鐘 |
| LiteDB `images.db` | `~/Library/Application Support/BingWallpaper/index.json` |

## 沒有移植的部分

- `defaultBrowser` / `dhpSetToBing` / `dseSetToBing`：Windows 上的預設應用程式推廣。Mac 送出空值和 `false`。
- 遙測、`MegaIntroOffer`、遠端 `server_config.json`、熱更新設定。
- 套件內的離線預設圖。斷網時沿用上次快取的照片。
- 圖庫搜尋、`bwc/metadata`、小工具。

## 已知限制

- macOS 只能改目前 Space 的桌布。切到其他 Space 時會再補上。
- `scripts/build-app.sh` 的預設 bundle id 仍是占位的 `com.example.bingwallpaper`。已公證的發布包用的是 `com.fairzy.bingwallpaper`。

## 贊助

這些是我們的其他產品。

- [豆芽繪本百科](https://www.picturebookpedia.cn) — 不知道今晚讀哪本？30 萬本繪本，按孩子現在的年齡直接挑。
- [地球小百科](https://earthpedia.picturebookpedia.cn) — 孩子問「這是哪兒」。1800 多個地標，轉一下地球就能指給他看。
- [恐龍小百科](https://dino.picturebookpedia.cn) — 「這是什麼龍」問到你答不上。2200 多種恐龍，轉個 3D 模型給他看。
- [動物好朋友](https://animalfriends.picturebookpedia.cn) — 繪本不會回話。點一下，孩子就能給小獅子打電話。
- [Wear.AI](https://wear-ai.online) — 喜歡的衣服，先穿到自己的照片上，再決定買不買。
- [Live.AI](https://livephoto-ai.online) — 按住一張不會動的照片，它就變成真正的 Live Photo。
- [Clean.AI](https://aiclean.picturebookpedia.cn) — 磁碟又滿了。AI 先標出能刪的，你點頭才清。
