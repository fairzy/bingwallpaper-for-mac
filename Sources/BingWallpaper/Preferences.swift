import BingWallpaperCore
import Foundation
import Observation

/// UserDefaults 里的设置和运行状态。键名尽量沿用 Windows 版。
@MainActor
@Observable
final class Preferences {
    private enum Key {
        static let market = "Market"
        static let theme = "Theme"
        static let dailyRefreshEnabled = "DailyRefreshEnabled"
        static let bicFilterEnabled = "IsBicFilterEnabled"
        static let fastRefreshEnabled = "FastRefreshEnabled"
        static let lastDailyImageRefreshTime = "LastDailyImageRefreshTime"
        static let currentImageID = "CurrentImageID"
        static let lastAutoAppliedImageID = "LastAutoAppliedImageID"
        static let lastRotationDay = "LastRotationDay"
        static let didFirstLaunchSetup = "DidFirstLaunchSetup"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var market: String { didSet { defaults.set(market, forKey: Key.market) } }
    var theme: String { didSet { defaults.set(theme, forKey: Key.theme) } }
    var dailyRefreshEnabled: Bool { didSet { defaults.set(dailyRefreshEnabled, forKey: Key.dailyRefreshEnabled) } }
    var bicFilterEnabled: Bool { didSet { defaults.set(bicFilterEnabled, forKey: Key.bicFilterEnabled) } }
    var lastDailyImageRefreshTime: Date? { didSet { defaults.set(lastDailyImageRefreshTime, forKey: Key.lastDailyImageRefreshTime) } }
    var currentImageID: String? { didSet { defaults.set(currentImageID, forKey: Key.currentImageID) } }
    var lastAutoAppliedImageID: String? { didSet { defaults.set(lastAutoAppliedImageID, forKey: Key.lastAutoAppliedImageID) } }
    var lastRotationDay: String? { didSet { defaults.set(lastRotationDay, forKey: Key.lastRotationDay) } }
    var didFirstLaunchSetup: Bool { didSet { defaults.set(didFirstLaunchSetup, forKey: Key.didFirstLaunchSetup) } }

    /// 隐藏开关：`defaults write <bundle-id> FastRefreshEnabled -bool YES`。
    var fastRefreshEnabled: Bool { defaults.bool(forKey: Key.fastRefreshEnabled) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.dailyRefreshEnabled: true,
            Key.bicFilterEnabled: false,
        ])
        market = defaults.string(forKey: Key.market) ?? Market.preferred()
        theme = defaults.string(forKey: Key.theme) ?? ThemeCategory.bing.key
        dailyRefreshEnabled = defaults.bool(forKey: Key.dailyRefreshEnabled)
        bicFilterEnabled = defaults.bool(forKey: Key.bicFilterEnabled)
        lastDailyImageRefreshTime = defaults.object(forKey: Key.lastDailyImageRefreshTime) as? Date
        currentImageID = defaults.string(forKey: Key.currentImageID)
        lastAutoAppliedImageID = defaults.string(forKey: Key.lastAutoAppliedImageID)
        lastRotationDay = defaults.string(forKey: Key.lastRotationDay)
        didFirstLaunchSetup = defaults.bool(forKey: Key.didFirstLaunchSetup)
    }

    var catalogKey: String { ImageStore.catalogKey(market: market, theme: theme) }
}
