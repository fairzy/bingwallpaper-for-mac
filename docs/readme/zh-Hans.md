[English](../../README.md) · **简体中文** · [繁體中文](zh-Hant.md) · [日本語](ja.md) · [Deutsch](de.md) · [Français](fr.md) · [Español](es.md)

# 必应每日壁纸 for Mac

**必应每天的一张图，自动换上你的 Mac。** 菜单栏里的小应用。免费，开源（MIT）。发布用的 DMG 用 Developer ID 签名，并经过 Apple 公证。

- 每天一张新图，自动换上桌面（大约每 30 分钟看一次）
- 只住在菜单栏：预览、暂停，或往前翻这几天
- 主题合集按天轮换
- 登录时启动。Apple 芯片和 Intel 通用二进制。macOS 14+

**[下载 DMG](https://github.com/fairzy/bingwallpaper-for-mac/releases/download/v1.0.0/BingWallpaper-1.0.0.dmg)** · **[宣传页](https://fairzy.github.io/bingwallpaper-for-mac/)** · **[GitHub](https://github.com/fairzy/bingwallpaper-for-mac)**

> 非官方开源项目，与 Microsoft 无关。Bing 和每日图片属于微软和拍摄者。

这个仓库是免费的开源版。你的 Mac 直接连接必应的公开接口。Mac App Store 上另有一个应用「每天一张」，即将上架。它是付费的（US$2.99），图片经过我们自己的服务器，可以和这个开源版同时安装。差别写在[宣传页](https://fairzy.github.io/bingwallpaper-for-mac/#store)。

行为对齐 Windows 版 1.1.469.0，依据 [实现笔记](../../BingWallpaper-实现笔记.md)。

## 构建与运行

需要 macOS 14+、Xcode 16+（Swift 6）。

```bash
swift test                                   # 单元测试，不联网
BW_LIVE_TESTS=1 swift test --filter LiveAPITests   # 联网测试
scripts/build-app.sh                         # 生成 build/BingWallpaper.app
open build/BingWallpaper.app
```

调试可以用 `swift run`。「登录时启动」只有真正的 `.app` 才可用。

不要设置 `WALLPAPER_API_BASE`。开源构建会使用必应的公开接口。

## 结构

```text
Sources/BingWallpaperCore/   与界面无关、可测试
  BingImage.swift            hpimages 记录：图片 ID、下载地址、文件名
  ThemeCategory.swift        主题目录、市场列表
  BingAPIClient.swift        services.bingapis.com v2
  Resilience.swift           指数退避重试、熔断（对应 Polly）
  ImageStore.swift           临时文件、长度和格式校验、索引、清理
  RefreshPolicy.swift        30 分钟周期、失败退避、抖动
Sources/BingWallpaper/       SwiftUI 菜单栏应用
  AppModel.swift             刷新周期、自动换图、用户操作
  Preferences.swift          UserDefaults
  SystemIntegration.swift    壁纸、登录启动、缩略图
  Views/                     弹出面板和设置
```

## 与 Windows 版的对应

| Windows | macOS |
| --- | --- |
| `BingHPImageService` 拼 `hpimages` 地址、下载、校验、Polly 重试 | `BingAPIClient` + `ImageStore` + `withRetry` / `CircuitBreaker` |
| `DailyRefreshService` 每 30 分钟（`MioFastRefreshEnabled` 时 5 分钟） | `AppModel.start()` 循环；`defaults write <bundle-id> FastRefreshEnabled -bool YES` |
| 上一轮未完成则跳过；空目录后退避 | `isCycleRunning`；`RefreshPolicy.retryDelay` |
| `RotateThemeImageDailyMessage` | 非 Bing 主题每天轮换一张 |
| `ImageCleanup`、按主题硬链接 | 所有主题共用 `images/`，按 `index.json` 清理 |
| 登录启动任务 `BingWallpaperStartupTask` | `SMAppService.mainApp`，首次启动自动开启 |
| 计划任务一天拉起两次 | 不需要：系统唤醒后立即刷新，`Task.sleep` 用连续时钟 |
| LiteDB `images.db` | `~/Library/Application Support/BingWallpaper/index.json` |

## 没有移植的部分

- `defaultBrowser` / `dhpSetToBing` / `dseSetToBing`：Windows 上的默认应用推广。Mac 上传空值和 `false`。
- 遥测、`MegaIntroOffer`、远程 `server_config.json`、热更新配置。
- 包内离线默认图。断网时沿用上次缓存的照片。
- 图库搜索、`bwc/metadata`、小组件。

## 已知限制

- macOS 只能改当前 Space 的壁纸。切到其他 Space 时会再补设。
- `scripts/build-app.sh` 的默认 bundle id 仍是占位的 `com.example.bingwallpaper`。已公证的发布包用的是 `com.fairzy.bingwallpaper`。

## 赞助

这些是我们的其他产品。

- [Wear.AI](https://wear-ai.online) — 用照片试穿。
- [Live.AI](https://livephoto-ai.online) — 把静态照片做成 Live Photo。
- [豆芽绘本百科](https://www.picturebookpedia.cn) — Picturebookpedia。
- [地球小百科](https://earthpedia.picturebookpedia.cn) — Little Earthpedia，给孩子的 3D 地球百科。
- [恐龙小百科](https://dino.picturebookpedia.cn) — DinoPedia，给孩子的恐龙百科。
- [动物好朋友](https://animalfriends.picturebookpedia.cn) — Animal Friends，小朋友和动物角色语音聊天。
- [Clean.AI](https://aiclean.picturebookpedia.cn) — Mac 上的 AI 磁盘清理。
