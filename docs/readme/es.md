[English](../../README.md) · [简体中文](zh-Hans.md) · [繁體中文](zh-Hant.md) · [日本語](ja.md) · [Deutsch](de.md) · [Français](fr.md) · **Español**

# Bing Wallpaper para macOS

**La foto del día de Bing, en el Mac, sola.** Una app pequeña en la barra de menús. Gratis y de código abierto (MIT). El DMG publicado está firmado con un Developer ID y notarizado por Apple.

- Una imagen nueva cada día, aplicada sola (comprueba más o menos cada 30 minutos)
- Vive en la barra de menús: vista previa, pausa, o volver a los días recientes
- Colecciones de temas que cambian una imagen al día
- Arranque al iniciar sesión. Binario universal para Apple silicon e Intel. macOS 14+

**[Descargar DMG](https://github.com/fairzy/bingwallpaper-for-mac/releases/download/v1.1.0/BingWallpaper-1.1.0.dmg)** · **[Sitio](https://fairzy.github.io/bingwallpaper-for-mac/)** · **[GitHub](https://github.com/fairzy/bingwallpaper-for-mac)**

> Proyecto de código abierto no oficial. No está vinculado a Microsoft. Bing y las imágenes diarias pertenecen a Microsoft y a quienes las fotografiaron.

Este repositorio es la edición gratuita. El Mac habla directamente con la API pública de Bing. Otra app de la Mac App Store, OnePaper - 必应同源每日壁纸, llegará pronto. En la barra de menús se llama OnePaper. Es de pago (2,99 USD), carga las imágenes a través de nuestro propio servicio y se puede instalar junto a esta. La diferencia está en el [sitio](https://fairzy.github.io/bingwallpaper-for-mac/#store).

El comportamiento sigue la app de Windows 1.1.469.0. Las notas están en [BingWallpaper-实现笔记.md](../../BingWallpaper-实现笔记.md) (chino).

## Compilar y ejecutar

macOS 14+, Xcode 16+ (Swift 6).

```bash
swift test                                   # pruebas unitarias, sin red
BW_LIVE_TESTS=1 swift test --filter LiveAPITests   # pruebas contra la API real
scripts/build-app.sh                         # escribe build/BingWallpaper.app
open build/BingWallpaper.app
```

`swift run` sirve para depurar. El arranque al iniciar sesión solo funciona en una `.app` de verdad.

No definas `WALLPAPER_API_BASE`. La versión de código abierto usa entonces la API pública de Bing.

## Estructura

```text
Sources/BingWallpaperCore/   código que se puede probar, sin interfaz
  BingImage.swift            ficha de hpimages: id, URL, nombre de archivo
  ThemeCategory.swift        temas y mercados
  BingAPIClient.swift        services.bingapis.com v2
  Resilience.swift           reintento con espera, cortacircuitos (Polly)
  ImageStore.swift           archivo temporal, tamaño, formato, índice, limpieza
  RefreshPolicy.swift        ciclo de 30 minutos, espera tras un fallo, jitter
Sources/BingWallpaper/       app SwiftUI en la barra de menús
  AppModel.swift             bucle, aplicación automática, acciones
  Preferences.swift          UserDefaults
  SystemIntegration.swift    fondo, ítem de inicio, miniaturas
  Views/                     panel y ajustes
```

## App de Windows

| Windows | macOS |
| --- | --- |
| `BingHPImageService` arma la URL `hpimages`, descarga, comprueba y reintenta con Polly | `BingAPIClient` + `ImageStore` + `withRetry` / `CircuitBreaker` |
| `DailyRefreshService` cada 30 minutos (5 si `MioFastRefreshEnabled`) | bucle de `AppModel.start()`; `defaults write <bundle-id> FastRefreshEnabled -bool YES` |
| Saltar si la pasada anterior sigue en curso; esperar si el catálogo llega vacío | `isCycleRunning`; `RefreshPolicy.retryDelay` |
| `RotateThemeImageDailyMessage` | los temas que no son Bing cambian una imagen al día |
| `ImageCleanup`, enlaces duros por tema | una carpeta `images/` compartida, limpia según `index.json` |
| Tarea de arranque `BingWallpaperStartupTask` | `SMAppService.mainApp`, activada en el primer lanzamiento |
| Tarea programada, dos arranques al día | no hace falta: se actualiza al despertar, y `Task.sleep` usa un reloj continuo |
| LiteDB `images.db` | `~/Library/Application Support/BingWallpaper/index.json` |

## No portado

- `defaultBrowser` / `dhpSetToBing` / `dseSetToBing`: avisos de apps predeterminadas en Windows. En el Mac la petición envía un valor vacío y `false`.
- Telemetría, `MegaIntroOffer`, `server_config.json` remoto, configuración en caliente.
- Una imagen sin conexión incluida en el paquete. Sin red, se queda la última foto en caché.
- Búsqueda en la galería, `bwc/metadata`, widgets.

## Límites

- macOS solo cambia el fondo del Space actual. Los demás se rellenan al cambiar a ellos.
- `scripts/build-app.sh` sigue usando el identificador provisional `com.example.bingwallpaper`. La versión notarizada usa `com.fairzy.bingwallpaper`.

## Apoyar

Estos son nuestros otros productos.

- [Picturebookpedia](https://www.picturebookpedia.cn) — 豆芽绘本百科. 300.000 álbumes ilustrados. Elegir el de esta noche según la edad del niño, en vez de adivinar por la portada.
- [Little Earthpedia](https://earthpedia.picturebookpedia.cn) — 地球小百科. 1.800 lugares en un globo que un niño puede girar, cuando pregunta dónde es eso.
- [DinoPedia](https://dino.picturebookpedia.cn) — 恐龙小百科. 2.200 dinosaurios, y un modelo 3D cuando pregunta cuál es.
- [Animal Friends](https://animalfriends.picturebookpedia.cn) — 动物好朋友. Un álbum no contesta. Un toque, y un niño puede llamar a un león.
- [Wear.AI](https://wear-ai.online) — Ver la ropa en la propia foto antes de comprarla.
- [Live.AI](https://livephoto-ai.online) — Mantener pulsada una foto quieta y se mueve. Guardarla como un Live Photo de verdad.
- [Clean.AI](https://aiclean.picturebookpedia.cn) — El disco está lleno otra vez. La IA marca lo que puede irse. No se borra nada hasta que tú digas que sí.
