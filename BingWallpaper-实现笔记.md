# Bing Wallpaper 壁纸请求实现笔记

观察对象：本机 Microsoft Bing Wallpaper `1.1.469.0`（x86）  
观察日期：2026-10-18  
方法：用 [REA](https://github.com/morluto/rea) 6.7.0 对安装目录里的 `BingWallpaper.dll` 做静态检查，并对照本机缓存、计划任务和公开接口的实际响应。REA 没有加载或运行这个程序集。

安装位置：

```text
C:\Program Files\WindowsApps\Microsoft.BingWallpaper_1.1.469.0_x86__8wekyb3d8bbwe
```

用户数据：

```text
C:\Users\harmony02\AppData\Local\Packages\Microsoft.BingWallpaper_8wekyb3d8bbwe
```

## 1. 程序是什么

这是一个 .NET 9 的 WinUI 桌面应用，模板是 Template Studio 的 MenuBar，MVVM 用 CommunityToolkit。主逻辑在 `BingWallpaper.dll`，小组件在 `BingWallpaper.Widgets.dll`。运行时是自带的 .NET 9.0.21。HTTP 重试使用 Polly。图片索引存在本地 LiteDB 文件 `LocalState\images\images.db`。

REA `inspect-managed-artifact` 的结果：

| 项 | 值 |
| --- | --- |
| 程序集 | `BingWallpaper` 1.0.0.0 |
| 目标框架 | `.NETCoreApp,Version=v9.0` |
| 形态 | PE / CLI，ReadyToRun，x86 |
| 元数据 | 完整。2647 个类型，21731 个方法 |
| SHA-256 | `bfa6a0e87b0fd8065ca2159be48094e165e704f9980b525f4038a82dce272914` |

包清单声明了 `internetClient`、登录启动任务 `BingWallpaperStartupTask`，以及协议 `microsoft-bingwallpaper`。

和壁纸相关的类型：

| 类型 | 职责 |
| --- | --- |
| `BingWallpaper.Services.BingHPImageService` | 拼每日图目录地址、下载图片、校验、重试 |
| `BingWallpaper.Services.DailyRefreshService` | 进程内定时刷新 |
| `BingWallpaper.Services.ThemeCategoryService` | 拉主题目录和缩略图 |
| `BingWallpaper.Services.HotConfig.HotConfigEndpoint` | 热更新配置 |
| `BingWallpaper.Services.LocalSettingsService` | 保存 `LastDailyImageRefreshTime` |

## 2. 一次请求拿目录，再逐张下图

每日壁纸分两步。

### 2.1 目录

`BingHPImageService.GetBingImagesFromBwApi` 把下面几段拼成一个地址：

```text
https://services.bingapis.com/ge-apps/api/v2/bwc/hpimages?mkt=
&theme=
&defaultBrowser=
&dhpSetToBing=
&dseSetToBing=
&IsBicFilterEnabled=
```

各段的含义：

| 参数 | 作用 |
| --- | --- |
| `mkt` | 市场，决定文案语言和图片 ID 里的市场后缀 |
| `theme` | 主题。每日图的记录里主题是 `bing` |
| `defaultBrowser` | 当前默认浏览器 |
| `dhpSetToBing` | 主页是否已设为必应 |
| `dseSetToBing` | 默认搜索是否已设为必应 |
| `IsBicFilterEnabled` | 是否启用必应图像创作（BIC）过滤 |

这是公开的 GET。URL 里没有密钥。2026-10-18 用 `mkt=zh-CN` 请求，返回 HTTP 200，`Content-Type: application/json`，`imageCount` 为 8，日期覆盖 2026-10-11 到 2026-10-18。

本机 `LocalState\images\bing` 里正好是这 8 个文件，写入时间都是 2026-10-18 13:35。第一次启动会把这一窗历史一次拉完。

每条记录的主要字段：

| 字段 | 例子 |
| --- | --- |
| `startdate` / `enddate` | `20261018` / `20261019` |
| `urlbase` | 图片 CDN 地址，见下一节 |
| `title` / `headline` / `description` | 本地化文案 |
| `copyrighttext` / `copyrightlink` | 版权与“了解更多”搜索 |
| `quiz` | 首页测验链接 |
| `theme` | 例如 `["bing"]` |
| `sourceType` | 这次返回的是 `BingImageOfTheDay` |
| `detectedRegion` | 服务端看到的地区。这次响应是 `sg` |
| `OverrideMarket` | 单张图可以改搜索所用市场。这次是空的 |
| `travelUrl` / `mapLink` | 旅行和地图入口 |
| `imageHotspots` | 点击区域。每日图常见整张 3840×2160 |

图片 ID 有两种前缀：

- `OHR.`：必应首页每日图，文件名带市场，例如 `OHR.DolbadarnWales_ZH-CN3649667806_UHD.jpg`。
- `OBGA.`：图库或特别企划。2026-10-17 是 `OBGA.AdobeStock_115654445`。

### 2.2 图片文件

目录里的 `urlbase` 才是文件地址，例如：

```text
http://ts1.tc.mm.bing.net/th?id=OHR.DolbadarnWales_ZH-CN3649667806_UHD.jpg
```

`DownloadImageAsync` 再追加：

```text
qlt=85&o=4
```

CDN 主机不固定。同一次本地缓存里还出现过 `ts4.tc.mm.bing.net`。主题预览则用：

```text
https://www.bing.com/th?id=OBGA...._Preview
```

下载时会核对 Content-Length 和实际字节数，再做图片格式校验，通过后才设为壁纸。失败会重试。日志里有 “HTTP circuit is open”，熔断来自 Polly。临时文件先写到临时目录，成功后再留到目标路径。

## 3. 分区

市场和主题是两套目录，各请求一次。

### 3.1 市场

市场由查询参数 `mkt` 决定。本机缓存文件名带 `_ZH-CN`，标题是中文，当前市场是 `zh-CN`。

响应里的 `detectedRegion` 是另一件事。这次请求的市场是 `zh-CN`，响应里的 `detectedRegion` 是 `sg`。文案和图片 ID 跟着 `mkt` 走。

单张图的点击动作上还有 `OverrideMarket`，用来改那一次搜索的市场。

### 3.2 主题

`ThemeCategoryService.GetRegularThemesFromBwApiAsync` 请求：

```text
https://services.bingapis.com/ge-apps/api/v2/BWC/GetThemeCategories?mkt=
```

同样是公开 GET。`mkt=zh-CN` 的响应当时包含：

| 键 | 显示名 | 类型 |
| --- | --- | --- |
| `bing` | Bing | Regular |
| `abstract` | 摘要 | Regular |
| `cat` | 猫 | Regular |
| `dog` | 狗 | Regular |
| `flower` | 花形 | Regular |
| `ocean` | 海洋 | Regular |
| `space` | 空格 | Regular |
| `travel` | 旅游 | Regular |
| `wild animal` | 野生动物 | Regular |
| `animated` | 动画片 | Regular |
| `xbox` | xbox | ThemePack，`IsNew: true` |

每个主题带最多 3 张预览图。主题包在本地目录名前面加 `ThemePack__`，例如 `ThemePack__xbox`。部分主题还有 `*_NonBic` 目录，把必应图像创作的图和普通图分开。

安装包里的 `Assets\DefaultImages` 用 `SourceType` 区分来源：1 是图库照片，2 是图像创作，3 是必应每日图。网络失败时用这些内置图。

### 3.3 其他相关接口

| 用途 | 地址 | 方法 |
| --- | --- | --- |
| 图库搜索 | `https://services.bingapis.com/ge-apps/api/v2/BWC/imageSearch`，再加 `&mkt=` 和 `&IsBicFilterEnabled=` | 应用内搜索 |
| 搜索结果缩略图 | 图片地址后加 `w=384&h=216&c=4` | GET |
| 已选图片的补充元数据 | `https://services.bingapis.com/ge-apps/api/v2/bwc/metadata` | POST，`application/json`。GET 返回 405，响应头 `Allow: POST` |
| 热更新配置 | `https://bingwallpaperimages.microsoft.com/hotswap/v1/config.json` | GET |
| 旧版每日图入口 | 见下一节 | GET，经 fwlink 跳转 |

## 4. 地址是公开的，还留着一条旧入口

当前每日图目录、主题目录、图片 CDN、主题预览都不带密钥。直接 GET 就能拿到和本机缓存一致的数据。

`LocalState\server_config.json` 里还有：

```text
hpwpdownloadAPI = https://go.microsoft.com/fwlink/?linkid=2151983
```

这个短链接返回 302，目标是：

```text
https://bingwallpaper.microsoft.com/api/BWC/getHPImages
```

程序集里对应的类型叫 `BingHPImageInfo_Old_API`，字段仍是经典的 `UrlBase`、`StartDate`、`FullStartDate`、`CopyrightText`、`Quiz`。现在 `GetBingImagesFromBwApi` 走的是 v2 的 `services.bingapis.com`，旧地址还留在配置和类型里。

`server_config.json` 本身是远程功能开关，用来改界面和刷新速度，不必发新版本。合作方代码 `pc=W205` 出现在必应搜索和分享链接上，不参与壁纸接口鉴权。壁纸包的下载地址也带这个渠道：

```text
https://download.microsoft.com/download/5cfd1ba1-7480-447a-9536-e9be8cdcda0b/W205/0x00005001/BingWallpaper_1.1.469.0_x86.msix
```

## 5. 什么时候请求

进程活着的时候，由进程内定时器周期检查。计划任务只负责把进程拉起来。

### 5.1 30 分钟一轮的进程内定时器

`DailyRefreshService.StartDailyRefreshTimer` 的中间语言是：

```text
MioFastRefreshEnabled 为真 → 5
否则 → 30
把这个整数转成 TimeSpan.FromMinutes
用同一个 TimeSpan 作为定时器的首次触发和重复间隔
日志：Daily refresh timer started with {N}-minute interval.
```

默认间隔是 30 分钟。功能开关 `MioFastRefreshEnabled` 打开时改成 5 分钟。本次读到的 `server_config.json` 里没有把这个开关设为真。

每一轮 `RunDailyRefreshCycleAsync` 的阶段名是：

1. `CollectDailyTelemetry`
2. `FetchMegaIntroOfferData`
3. `ImageRefresh`
4. `BingMetadataRefresh`
5. `FlushUIQueue`
6. 发送 `RotateThemeImageDailyMessage`
7. `RefreshWidgetsVisibility`
8. `ImageCleanup`

上一轮还在跑时会记 “Skipping tick — previous cycle still running.” 并跳过。成功时间写入 `LastDailyImageRefreshTime`。目录空返回会增加 `EmptyRefreshCount`，再按 `GetRetryRefreshDelay` 后退，连续失败则记日志并安排 `ScheduleRetryRefresh`。

另一个定时器 `_trackDefaultsTimer` 用秒：`MegaIntroOfferEnabled` 为真时 5 秒，否则 30 秒。它跟踪默认浏览器和默认搜索，不负责下壁纸。

### 5.2 登录启动和一天两次的恢复任务

登录启动任务在包清单里，任务 ID 是 `BingWallpaperStartupTask`，安装后为启用。

计划任务名：

```text
\BingWallpaper_DailyCheck_S-1-5-21-912314001-3491519703-4029503976-1002
```

说明是 “Checks Bing Wallpaper status and starts it when appropriate.” 每天两个时间：

| 起点 | 重复 |
| --- | --- |
| 2026-10-19 08:29 | 每 1 天 |
| 2026-10-18 17:17 | 每 1 天 |

动作是 `UnInstDaemon.exe --daily-app-recovery`，限时 5 分钟，错过会补跑，电池状态下也允许启动。它检查进程还在不在，不自己请求壁纸 JSON。

所以时间模型是：登录后进程常驻，每 30 分钟看一次要不要刷新；计划任务每天两次，只在进程不在时把它拉起来。首次启动则一次取回约 8 天的目录并立刻下完全部文件。

## 6. 本地怎么存

| 位置 | 内容 |
| --- | --- |
| `LocalState\server_config.json` | 远程功能开关、推荐位、包升级地址 |
| `LocalState\images\images.db` | LiteDB 图片索引，约 200 KB |
| `LocalState\images\bing\` | 每日图原文件 |
| `LocalState\images\<theme>\` | 按主题硬链接过去的文件 |
| `LocalState\images\thumbnails\<theme>\` | `thumb_0.jpg` 这类预览 |
| `Assets\DefaultImages\` | 安装包内置的离线图和 `ImageMetadata.json` |

同一张图可以硬链接到多个主题目录。某个主题还引用着文件时，清理逻辑会跳过删除。未选中主题的图片由 `ImageCleanup` 清掉。

设置页可以开关每日刷新，对应本地项 `DailyRefreshEnabled` 和 `AutoRefreshEnabled`。

## 7. 值得学的设计

1. 目录和文件分开。一次 JSON 拿齐日期、文案和图片 ID，文件用 CDN 按质量参数另下，并校验长度和格式。
2. 市场和主题都是请求参数。主题还能再分成普通图和 BIC 图，而不是写死一组文件夹。
3. 定时器只负责周期检查。保活拆成登录启动和一天两次的进程恢复，计划任务不承担下载。
4. 远程一份 `server_config.json` 控制开关和刷新速度。热更新配置还有独立地址，并带 `RefreshSpreadSeconds`，避免所有客户端同一秒打过去。
5. 新接口旁边留着旧 API 模型。断网时用包内默认图，空响应有计数和后退，连续失败再退回默认主题。
6. 下载有临时文件、完整性检查、格式检查和熔断，失败不会把半张图设成壁纸。

## 8. 证据边界

- 程序集结论来自 REA 静态元数据，以及同一份 CLI 元数据里的用户字符串和中间语言。REA 明确没有反编译成 C#，也没有执行目标代码。
- 本机 Node.js 是 v24.5.0。REA 6.7.0 要求 `^22.19.0 || ^24.11.0 || >=26.0.0`，运行时有引擎警告，`inspect-managed-artifact` 仍然成功。
- `mkt=zh-CN` 的目录和主题响应是 2026-10-18 当天实请求的结果。图片主机、`imageCount` 和字段会随日期变化。
- `MioFastRefreshEnabled` 的 5 分钟分支在代码里存在。本次看到的服务器配置没有打开它，因此当前走 30 分钟。
- 本文没有记录机器标识、遥测密钥或 Cookie。
