[English](../../README.md) · [简体中文](zh-Hans.md) · [繁體中文](zh-Hant.md) · **日本語** · [Deutsch](de.md) · [Français](fr.md) · [Español](es.md)

# Bing Wallpaper for macOS

**Bing の今日の一枚を、Mac のデスクトップへ。** メニューバーに住む小さなアプリです。無料のオープンソース（MIT）。配布 DMG は Developer ID で署名し、Apple の公証を通しています。

- 毎日新しい画像を、約 30 分ごとに確認して自動で設定
- メニューバーからプレビュー、一時停止、過去の日へ戻る
- テーマ集は 1 日 1 枚ずつ入れ替え
- ログイン時に起動。Apple シリコンと Intel のユニバーサルバイナリ。macOS 14 以降

**[DMG をダウンロード](https://github.com/fairzy/bingwallpaper-for-mac/releases/download/v1.0.0/BingWallpaper-1.0.0.dmg)** · **[ウェブサイト](https://fairzy.github.io/bingwallpaper-for-mac/)** · **[GitHub](https://github.com/fairzy/bingwallpaper-for-mac)**

> 非公式のオープンソースです。Microsoft とは関係ありません。Bing と毎日の画像の権利は Microsoft と撮影者にあります。

このリポジトリは無料版です。Mac は Bing の公開 API に直接接続します。Mac App Store 向けの別アプリ「OnePaper - 必应同源每日壁纸」は近日公開です。メニューバーの名前は OnePaper です。有料（US$2.99）で、画像は私たちのサーバー経由です。この無料版と同時にインストールできます。違いは[ウェブサイト](https://fairzy.github.io/bingwallpaper-for-mac/#store)に書いてあります。

動作は Windows 版 1.1.469.0 に合わせています。メモは [BingWallpaper-实现笔记.md](../../BingWallpaper-实现笔记.md)（中国語）です。

## ビルドと実行

macOS 14 以降、Xcode 16 以降（Swift 6）。

```bash
swift test                                   # ユニットテスト。オフライン
BW_LIVE_TESTS=1 swift test --filter LiveAPITests   # ライブ API テスト
scripts/build-app.sh                         # build/BingWallpaper.app を書き出す
open build/BingWallpaper.app
```

デバッグには `swift run` も使えます。ログイン時起動は、本物の `.app` でだけ動きます。

`WALLPAPER_API_BASE` は設定しないでください。オープンソース版は Bing の公開 API を使います。

## 構成

```text
Sources/BingWallpaperCore/   UI のないテスト可能な部分
  BingImage.swift            hpimages の 1 件：ID、ダウンロード URL、ファイル名
  ThemeCategory.swift        テーマとマーケット一覧
  BingAPIClient.swift        services.bingapis.com v2
  Resilience.swift           バックオフ再試行、サーキットブレーカー（Polly）
  ImageStore.swift           一時ファイル、サイズと形式の確認、索引、削除
  RefreshPolicy.swift        30 分周期、失敗時の待機、ゆらぎ
Sources/BingWallpaper/       SwiftUI のメニューバーアプリ
  AppModel.swift             更新ループ、自動適用、操作
  Preferences.swift          UserDefaults
  SystemIntegration.swift    壁紙、ログイン項目、サムネイル
  Views/                     ポップオーバーと設定
```

## Windows 版との対応

| Windows | macOS |
| --- | --- |
| `BingHPImageService` が `hpimages` の URL を作り、ダウンロード、検証、Polly で再試行 | `BingAPIClient` + `ImageStore` + `withRetry` / `CircuitBreaker` |
| `DailyRefreshService` は 30 分ごと（`MioFastRefreshEnabled` なら 5 分） | `AppModel.start()` のループ。`defaults write <bundle-id> FastRefreshEnabled -bool YES` |
| 前回が終わっていなければ飛ばす。空の一覧では待機を延ばす | `isCycleRunning`、`RefreshPolicy.retryDelay` |
| `RotateThemeImageDailyMessage` | Bing 以外のテーマは 1 日 1 枚 |
| `ImageCleanup`、テーマごとのハードリンク | `images/` を共有し、`index.json` を見て削除 |
| スタートアップタスク `BingWallpaperStartupTask` | `SMAppService.mainApp`。初回起動でオン |
| スケジュールで 1 日 2 回起動 | 不要。スリープ解除ですぐ更新し、`Task.sleep` は連続時計 |
| LiteDB `images.db` | `~/Library/Application Support/BingWallpaper/index.json` |

## 移植していないもの

- `defaultBrowser` / `dhpSetToBing` / `dseSetToBing`：Windows の既定アプリ促進。Mac では空文字と `false` を送ります。
- テレメトリ、`MegaIntroOffer`、リモートの `server_config.json`、設定のホット更新。
- 同梱のオフライン既定画像。圏外のときは前回のキャッシュを使い続けます。
- ギャラリー検索、`bwc/metadata`、ウィジェット。

## 制限

- macOS は現在の Space の壁紙しか変えられません。ほかの Space は切り替えたときに設定します。
- `scripts/build-app.sh` の既定 bundle id は仮の `com.example.bingwallpaper` です。公証済みのリリースは `com.fairzy.bingwallpaper` です。

## スポンサー

私たちが作っているほかの製品です。

- [Wear.AI](https://wear-ai.online) — 写真の上で服を試す。
- [Live.AI](https://livephoto-ai.online) — 静止画を Live Photo にする。
- [Picturebookpedia](https://www.picturebookpedia.cn) — 豆芽绘本百科。絵本ガイド。
- [Little Earthpedia](https://earthpedia.picturebookpedia.cn) — 地球小百科。子どものための 3D 地球百科。
- [DinoPedia](https://dino.picturebookpedia.cn) — 恐龙小百科。子どものための恐竜百科。
- [Animal Friends](https://animalfriends.picturebookpedia.cn) — 动物好朋友。小さな子どもと動物キャラクターの音声チャット。
- [Clean.AI](https://aiclean.picturebookpedia.cn) — Mac 向けの AI ディスク整理。
