# Bing Wallpaper for macOS

**Bing's daily photo, on your Mac — automatically.** A tiny menu-bar app that fetches the Bing daily wallpaper and sets it as your macOS desktop background. Free and open source (MIT).

- 🖼️ New Bing daily image every day, applied automatically (checks every 30 minutes)
- 🧭 Lives in the menu bar — preview, pause, or jump to previous days
- 🎨 Theme collections with daily rotation
- 🚀 Starts at login, Apple Silicon + Intel universal binary, macOS 14+

**[宣传页](https://fairzy.github.io/bingwallpaper-for-mac/)** · **[GitHub](https://github.com/fairzy/bingwallpaper-for-mac)**

> Unofficial open-source project. Not affiliated with Microsoft. Bing and the daily images are trademarks/content of Microsoft.

---

菜单栏常驻的必应每日壁纸。行为对齐 Windows 版 1.1.469.0，依据 [实现笔记](BingWallpaper-实现笔记.md)。

## 构建与运行

需要 macOS 14+、Xcode 16+（Swift 6）。

```bash
swift test                                   # 单元测试（不联网）
BW_LIVE_TESTS=1 swift test --filter LiveAPITests   # 联网集成测试
scripts/build-app.sh                         # 生成 build/BingWallpaper.app
open build/BingWallpaper.app
```

调试时也可以 `swift run`，但「登录时启动」只有 `.app` 形式才可用。

## 结构

```text
Sources/BingWallpaperCore/   与 UI 无关、可测试的部分
  BingImage.swift            hpimages 记录：图片 ID、下载地址、文件名
  ThemeCategory.swift        主题目录、市场列表
  BingAPIClient.swift        services.bingapis.com v2 接口
  Resilience.swift           指数退避重试、熔断（对应 Polly）
  ImageStore.swift           临时文件 → 长度/格式校验 → 落盘；目录索引；清理
  RefreshPolicy.swift        30 分钟周期、失败退避、随机抖动
Sources/BingWallpaper/       SwiftUI 菜单栏 App
  AppModel.swift             刷新周期、自动换图、用户操作
  Preferences.swift          UserDefaults 设置
  SystemIntegration.swift    设置壁纸、登录启动、缩略图
  Views/                     弹出面板与设置
```

## 与 Windows 版的对应

| Windows | macOS |
| --- | --- |
| `BingHPImageService` 拼 `hpimages` 地址、下载、校验、Polly 重试 | `BingAPIClient` + `ImageStore` + `withRetry` / `CircuitBreaker` |
| `DailyRefreshService` 30 分钟定时器（`MioFastRefreshEnabled` 时 5 分钟） | `AppModel.start()` 循环；`defaults write <bundle-id> FastRefreshEnabled -bool YES` |
| 上一轮未完成则跳过；空目录计数后退 | `isCycleRunning`；`RefreshPolicy.retryDelay` |
| `RotateThemeImageDailyMessage` | 非 Bing 主题每天轮换一张 |
| `ImageCleanup`、按主题硬链接 | 所有主题共用 `images/`，按 `index.json` 引用计数清理 |
| 登录启动任务 `BingWallpaperStartupTask` | `SMAppService.mainApp`，首次启动自动开启 |
| 计划任务一天两次拉起进程 | 不需要：监听系统唤醒立即刷新，`Task.sleep` 用连续时钟，睡眠期间也计时 |
| LiteDB `images.db` | `~/Library/Application Support/BingWallpaper/index.json` |

## 没有移植的部分

- `defaultBrowser` / `dhpSetToBing` / `dseSetToBing`：Windows 默认项推广，Mac 上传空值和 `false`。
- 遥测、`MegaIntroOffer`、`server_config.json` 远程开关、热更新配置。
- 包内离线默认图（版权需确认），断网时沿用上次缓存。
- 图库搜索、`bwc/metadata`、小组件。

## 已知限制

- macOS 只允许改当前 Space 的壁纸；切到其他 Space 时会自动补设。
- 默认 bundle ID 是占位的 `com.example.bingwallpaper`，正式发布前通过 `BUNDLE_ID`、`SIGN_IDENTITY` 换成正式值并公证。
