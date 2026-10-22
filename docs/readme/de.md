[English](../../README.md) · [简体中文](zh-Hans.md) · [繁體中文](zh-Hant.md) · [日本語](ja.md) · **Deutsch** · [Français](fr.md) · [Español](es.md)

# Bing Wallpaper für macOS

**Bings Foto des Tages, automatisch auf dem Mac.** Eine kleine App in der Menüleiste. Kostenlos und Open Source (MIT). Das veröffentlichte DMG ist mit einer Developer ID signiert und von Apple beglaubigt.

- Jeden Tag ein neues Bild, automatisch gesetzt (Prüfung etwa alle 30 Minuten)
- Lebt in der Menüleiste: Vorschau, Pause, zurück zu den letzten Tagen
- Themen-Sammlungen wechseln einmal am Tag
- Start bei der Anmeldung. Universal-Binary für Apple-Chip und Intel. macOS 14+

**[DMG laden](https://github.com/fairzy/bingwallpaper-for-mac/releases/download/v1.0.0/BingWallpaper-1.0.0.dmg)** · **[Website](https://fairzy.github.io/bingwallpaper-for-mac/)** · **[GitHub](https://github.com/fairzy/bingwallpaper-for-mac)**

> Inoffizielles Open-Source-Projekt. Nicht mit Microsoft verbunden. Bing und die täglichen Bilder gehören Microsoft und den Fotografen.

Dieses Repository ist die kostenlose Ausgabe. Der Mac spricht direkt mit der öffentlichen Bing-API. Eine eigene Mac-App-Store-App, OnePaper - 必应同源每日壁纸, kommt bald. Der Name in der Menüleiste ist OnePaper. Sie kostet 2,99 US-Dollar, lädt Bilder über unseren eigenen Dienst und lässt sich neben dieser Version installieren. Der Unterschied steht auf der [Website](https://fairzy.github.io/bingwallpaper-for-mac/#store).

Das Verhalten folgt der Windows-App 1.1.469.0. Die Notizen stehen in [BingWallpaper-实现笔记.md](../../BingWallpaper-实现笔记.md) (Chinesisch).

## Bauen und starten

macOS 14+, Xcode 16+ (Swift 6).

```bash
swift test                                   # Tests, offline
BW_LIVE_TESTS=1 swift test --filter LiveAPITests   # Tests gegen die echte API
scripts/build-app.sh                         # schreibt build/BingWallpaper.app
open build/BingWallpaper.app
```

`swift run` reicht zum Debuggen. Der Start bei der Anmeldung funktioniert nur als echtes `.app`.

`WALLPAPER_API_BASE` nicht setzen. Der Open-Source-Build nutzt dann die öffentliche Bing-API.

## Aufbau

```text
Sources/BingWallpaperCore/   testbarer Code, ohne UI
  BingImage.swift            hpimages-Eintrag: ID, Download-URL, Dateiname
  ThemeCategory.swift        Themen und Märkte
  BingAPIClient.swift        services.bingapis.com v2
  Resilience.swift           Wiederholung mit Backoff, Circuit Breaker (Polly)
  ImageStore.swift           Temp-Datei, Größen- und Formatprüfung, Index, Aufräumen
  RefreshPolicy.swift        30-Minuten-Takt, Backoff, Jitter
Sources/BingWallpaper/       SwiftUI-App in der Menüleiste
  AppModel.swift             Aktualisierung, automatisches Setzen, Aktionen
  Preferences.swift          UserDefaults
  SystemIntegration.swift    Schreibtischbild, Anmeldeobjekt, Vorschaubilder
  Views/                     Popover und Einstellungen
```

## Windows-App

| Windows | macOS |
| --- | --- |
| `BingHPImageService` baut die `hpimages`-URL, lädt, prüft, wiederholt mit Polly | `BingAPIClient` + `ImageStore` + `withRetry` / `CircuitBreaker` |
| `DailyRefreshService` alle 30 Minuten (5 bei `MioFastRefreshEnabled`) | Schleife in `AppModel.start()`; `defaults write <bundle-id> FastRefreshEnabled -bool YES` |
| Überspringen, solange der letzte Lauf läuft; Backoff bei leerem Katalog | `isCycleRunning`; `RefreshPolicy.retryDelay` |
| `RotateThemeImageDailyMessage` | Themen außer Bing wechseln ein Bild pro Tag |
| `ImageCleanup`, Hardlinks je Thema | Ein gemeinsamer Ordner `images/`, aufgeräumt nach `index.json` |
| Startaufgabe `BingWallpaperStartupTask` | `SMAppService.mainApp`, beim ersten Start an |
| Geplante Aufgabe startet den Prozess zweimal am Tag | Nicht nötig: Refresh beim Aufwachen, `Task.sleep` nutzt eine fortlaufende Uhr |
| LiteDB `images.db` | `~/Library/Application Support/BingWallpaper/index.json` |

## Nicht übernommen

- `defaultBrowser` / `dhpSetToBing` / `dseSetToBing`: Hinweise zu Standard-Apps unter Windows. Der Mac sendet einen leeren Wert und `false`.
- Telemetrie, `MegaIntroOffer`, entferntes `server_config.json`, heiße Konfiguration.
- Ein mitgeliefertes Offline-Standardbild. Ohne Netz bleibt das letzte zwischengespeicherte Foto.
- Galeriesuche, `bwc/metadata`, Widgets.

## Grenzen

- macOS ändert nur das Schreibtischbild des aktuellen Space. Andere Spaces werden beim Wechsel gesetzt.
- `scripts/build-app.sh` verwendet noch die Platzhalter-Bundle-ID `com.example.bingwallpaper`. Die beglaubigte Veröffentlichung nutzt `com.fairzy.bingwallpaper`.

## Unterstützen

Das sind unsere anderen Produkte.

- [Picturebookpedia](https://www.picturebookpedia.cn) — 豆芽绘本百科. 300.000 Bilderbücher. Das Buch für heute Abend nach dem Alter des Kindes aussuchen.
- [Little Earthpedia](https://earthpedia.picturebookpedia.cn) — 地球小百科. 1.800 Orte auf einem Globus, den ein Kind drehen kann, wenn es fragt, wo das ist.
- [DinoPedia](https://dino.picturebookpedia.cn) — 恐龙小百科. 2.200 Dinosaurier und ein 3D-Modell, wenn es fragt, welche Art das ist.
- [Animal Friends](https://animalfriends.picturebookpedia.cn) — 动物好朋友. Ein Bilderbuch antwortet nicht. Antippen, und ein Kind kann einen Löwen anrufen.
- [Wear.AI](https://wear-ai.online) — Die Kleider erst auf dem eigenen Foto sehen, dann kaufen.
- [Live.AI](https://livephoto-ai.online) — Ein Standfoto gedrückt halten, und es bewegt sich. Als echtes Live Photo sichern.
- [Clean.AI](https://aiclean.picturebookpedia.cn) — Die Festplatte ist wieder voll. Die KI markiert, was weg kann. Gelöscht wird erst nach deinem Ja.
