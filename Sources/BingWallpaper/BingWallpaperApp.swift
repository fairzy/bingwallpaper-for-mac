import AppKit
import SwiftUI

@main
struct BingWallpaperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(model: appDelegate.model)
        } label: {
            Image(systemName: "photo.on.rectangle.angled")
        }
        .menuBarExtraStyle(.window)
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
