[English](../../README.md) · [简体中文](zh-Hans.md) · [繁體中文](zh-Hant.md) · [日本語](ja.md) · [Deutsch](de.md) · **Français** · [Español](es.md)

# Bing Wallpaper pour macOS

**La photo du jour de Bing, sur le Mac, toute seule.** Une petite app dans la barre des menus. Gratuite et open source (MIT). Le DMG publié est signé avec un Developer ID et notarié par Apple.

- Une nouvelle image chaque jour, posée automatiquement (vérification toutes les 30 minutes environ)
- Elle vit dans la barre des menus : aperçu, pause, ou retour sur les jours récents
- Des thèmes qui changent une image par jour
- Lancement à l'ouverture de session. Binaire universel Apple silicon et Intel. macOS 14+

**[Télécharger le DMG](https://github.com/fairzy/bingwallpaper-for-mac/releases/download/v1.1.0/BingWallpaper-1.1.0.dmg)** · **[Site](https://fairzy.github.io/bingwallpaper-for-mac/)** · **[GitHub](https://github.com/fairzy/bingwallpaper-for-mac)**

> Projet open source non officiel. Sans lien avec Microsoft. Bing et les images du jour appartiennent à Microsoft et aux photographes.

Ce dépôt est l'édition gratuite. Le Mac parle directement à l'API publique de Bing. Une autre app Mac App Store, OnePaper - 必应同源每日壁纸, arrive bientôt. Dans la barre des menus, elle s'appelle OnePaper. Elle est payante (2,99 USD), charge les images via notre propre service, et s'installe à côté de celle-ci. La différence est sur le [site](https://fairzy.github.io/bingwallpaper-for-mac/#store).

Le comportement suit l'app Windows 1.1.469.0. Les notes sont dans [BingWallpaper-实现笔记.md](../../BingWallpaper-实现笔记.md) (chinois).

## Compiler et lancer

macOS 14+, Xcode 16+ (Swift 6).

```bash
swift test                                   # tests unitaires, hors ligne
BW_LIVE_TESTS=1 swift test --filter LiveAPITests   # tests sur l'API réelle
scripts/build-app.sh                         # écrit build/BingWallpaper.app
open build/BingWallpaper.app
```

`swift run` suffit pour déboguer. Le lancement à l'ouverture de session ne marche que dans une vraie `.app`.

Ne pas définir `WALLPAPER_API_BASE`. La version open source utilise alors l'API publique de Bing.

## Structure

```text
Sources/BingWallpaperCore/   code testable, sans interface
  BingImage.swift            fiche hpimages : id, URL, nom de fichier
  ThemeCategory.swift        thèmes et marchés
  BingAPIClient.swift        services.bingapis.com v2
  Resilience.swift           nouvel essai avec délai, coupe-circuit (Polly)
  ImageStore.swift           fichier temporaire, taille, format, index, nettoyage
  RefreshPolicy.swift        cycle de 30 minutes, délai après échec, jitter
Sources/BingWallpaper/       app SwiftUI dans la barre des menus
  AppModel.swift             boucle, application automatique, actions
  Preferences.swift          UserDefaults
  SystemIntegration.swift    fond d'écran, ouverture de session, vignettes
  Views/                     fenêtre et réglages
```

## App Windows

| Windows | macOS |
| --- | --- |
| `BingHPImageService` construit l'URL `hpimages`, télécharge, vérifie, réessaie avec Polly | `BingAPIClient` + `ImageStore` + `withRetry` / `CircuitBreaker` |
| `DailyRefreshService` toutes les 30 minutes (5 si `MioFastRefreshEnabled`) | boucle `AppModel.start()` ; `defaults write <bundle-id> FastRefreshEnabled -bool YES` |
| Sauter si le passage précédent tourne encore ; attendre si le catalogue est vide | `isCycleRunning` ; `RefreshPolicy.retryDelay` |
| `RotateThemeImageDailyMessage` | les thèmes autres que Bing changent une image par jour |
| `ImageCleanup`, liens physiques par thème | un dossier `images/` partagé, nettoyé d'après `index.json` |
| Tâche de démarrage `BingWallpaperStartupTask` | `SMAppService.mainApp`, activé au premier lancement |
| Tâche planifiée, deux lancements par jour | inutile : rafraîchissement au réveil, `Task.sleep` sur une horloge continue |
| LiteDB `images.db` | `~/Library/Application Support/BingWallpaper/index.json` |

## Non porté

- `defaultBrowser` / `dhpSetToBing` / `dseSetToBing` : incitations aux apps par défaut sous Windows. Sur Mac, la requête envoie une valeur vide et `false`.
- Télémétrie, `MegaIntroOffer`, `server_config.json` distant, configuration à chaud.
- Image hors ligne fournie dans le paquet. Sans réseau, la dernière photo en cache reste.
- Recherche dans la galerie, `bwc/metadata`, widgets.

## Limites

- macOS ne change que le fond de l'Espace actuel. Les autres Espaces sont remplis quand on y passe.
- `scripts/build-app.sh` utilise encore l'identifiant provisoire `com.example.bingwallpaper`. La version notariée utilise `com.fairzy.bingwallpaper`.

## Soutenir

Voici nos autres produits.

- [Picturebookpedia](https://www.picturebookpedia.cn) — 豆芽绘本百科. 300 000 albums. Choisir celui de ce soir selon l'âge de l'enfant, au lieu de deviner à la couverture.
- [Little Earthpedia](https://earthpedia.picturebookpedia.cn) — 地球小百科. 1 800 lieux sur un globe qu'un enfant peut tourner, au moment où il demande où c'est.
- [DinoPedia](https://dino.picturebookpedia.cn) — 恐龙小百科. 2 200 dinosaures, et un modèle 3D quand il demande lequel c'est.
- [Animal Friends](https://animalfriends.picturebookpedia.cn) — 动物好朋友. Un album ne répond pas. Une tape, et un enfant peut appeler un lion.
- [Wear.AI](https://wear-ai.online) — Voir les vêtements sur sa propre photo avant de les acheter.
- [Live.AI](https://livephoto-ai.online) — Maintenir une photo immobile, elle bouge. L'enregistrer en vrai Live Photo.
- [Clean.AI](https://aiclean.picturebookpedia.cn) — Le disque est encore plein. L'IA marque ce qui peut partir. Rien n'est effacé sans votre accord.
