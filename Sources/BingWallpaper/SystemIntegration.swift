import AppKit
import ImageIO
import ServiceManagement

/// 设置桌面壁纸。macOS 只会改当前 Space，其他 Space 需要切过去后由「屏幕变化」通知补上。
@MainActor
enum WallpaperSetter {
    static func apply(_ url: URL) throws {
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: true,
        ]
        for screen in NSScreen.screens {
            try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: options)
        }
    }
}

/// 登录启动，对应 Windows 版的 `BingWallpaperStartupTask`。只有打包成 .app 后才可用。
@MainActor
enum LaunchAtLogin {
    static var isAvailable: Bool { Bundle.main.bundleURL.pathExtension == "app" }
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

enum Thumbnail {
    /// 用 ImageIO 直接解码缩略图，避免把 4K 原图整张读进内存。
    static func make(from url: URL, maxPixelSize: Int = 900) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}
