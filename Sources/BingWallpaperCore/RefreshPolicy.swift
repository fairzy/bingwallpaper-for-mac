import Foundation

/// 刷新节奏，对应 Windows 版 `DailyRefreshService`。
public enum RefreshPolicy {
    /// 默认 30 分钟检查一次。
    public static let normalInterval: Duration = .seconds(30 * 60)
    /// 对应 `MioFastRefreshEnabled`，调试用。
    public static let fastInterval: Duration = .seconds(5 * 60)
    /// 每轮额外加 0…120 秒随机抖动，对应 `RefreshSpreadSeconds`，避免所有客户端同一秒请求。
    public static let maxSpreadSeconds = 120

    /// 目录为空或请求失败后的退避：1、2、4、8、16 分钟，封顶 30 分钟。
    public static func retryDelay(afterFailures failures: Int) -> Duration {
        guard failures > 0 else { return normalInterval }
        let minutes = min(30, 1 << min(failures - 1, 5))
        return .seconds(minutes * 60)
    }

    public static func nextDelay(failures: Int, fastRefresh: Bool, spread: Int = .random(in: 0...maxSpreadSeconds)) -> Duration {
        let base = failures > 0 ? retryDelay(afterFailures: failures) : (fastRefresh ? fastInterval : normalInterval)
        return base + .seconds(spread)
    }

    /// 主题图每天轮换一次，用本地日期做键。
    public static func dayKey(for date: Date = .now, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
