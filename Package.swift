// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BingWallpaper",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "BingWallpaper", targets: ["BingWallpaper"]),
    ],
    targets: [
        .target(name: "BingWallpaperCore"),
        .executableTarget(
            name: "BingWallpaper",
            dependencies: ["BingWallpaperCore"],
            exclude: [
                "BingWallpaper.entitlements",
                "Resources/AppIcon.icns",
            ]
        ),
        .testTarget(
            name: "BingWallpaperCoreTests",
            dependencies: ["BingWallpaperCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
