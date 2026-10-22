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
        // 沙盒里「桌面图片」读不到容器内的文件。图片文件夹的授权能写到真实的「图片」，系统读得了。
        let imageURL = try desktopURL(for: url)
        for screen in NSScreen.screens {
            try NSWorkspace.shared.setDesktopImageURL(imageURL, for: screen, options: options)
        }
    }

    private static func desktopURL(for url: URL) throws -> URL {
        guard ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil else { return url }
        let folder = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Pictures/每天一张", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appending(path: url.lastPathComponent)
        if !FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.copyItem(at: url, to: destination)
        }
        return destination
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
