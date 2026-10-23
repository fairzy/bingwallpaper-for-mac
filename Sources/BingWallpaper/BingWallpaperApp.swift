import AppKit
import SwiftUI

@main
struct BingWallpaperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(model: appDelegate.model)
        } label: {
            Image(nsImage: MenuBarIcon.image)
        }
        .menuBarExtraStyle(.window)
    }
}

/// 菜单栏只用亭子的剪影。模板图跟着菜单栏的深浅色变，不放白底应用图标。
private enum MenuBarIcon {
    static let image: NSImage = {
        let image = load()
        image.isTemplate = true
        image.size = NSSize(width: 22, height: 15)
        return image
    }()

    private static func load() -> NSImage {
        // 正式包里的图在 Contents/Resources。Bundle.module 找不到开发资源包时会直接中断启动，所以只有主包没有图才去问它。
        if let image = image(in: Bundle.main) {
            return image
        }
        if let image = image(in: Bundle.module) {
            return image
        }
        let fallback = NSImage(systemSymbolName: "photo.on.rectangle.angled", accessibilityDescription: nil) ?? NSImage()
        fallback.isTemplate = true
        return fallback
    }

    private static func image(in bundle: Bundle) -> NSImage? {
        guard let url = bundle.url(forResource: "MenuBarIcon", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 用 `swift run` 直接跑时没有 Info.plist 的 LSUIElement，这里兜底隐藏 Dock 图标。
        NSApp.setActivationPolicy(.accessory)
        model.start()
    }
}
