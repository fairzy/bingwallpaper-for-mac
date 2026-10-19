import Foundation

/// 指数退避重试，对应 Windows 版里 Polly 的重试策略。
public struct RetryPolicy: Sendable {
    public var maxAttempts: Int
    public var baseDelay: Duration

    public init(maxAttempts: Int = 3, baseDelay: Duration = .seconds(1)) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
    }

    /// 第 n 次失败后等待 base × 2^(n-1)。
    public func delay(afterFailure n: Int) -> Duration {
        baseDelay * (1 << max(0, n - 1))
    }

    /// 网络抖动和 5xx/429 值得重试；4xx、取消、校验失败不值得。
    public static func isTransient(_ error: Error) -> Bool {
        if let error = error as? URLError {
            switch error.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost,
                 .cannotFindHost, .dnsLookupFailed, .resourceUnavailable, .secureConnectionFailed:
                return true
            default:
                return false
            }
        }
        if case BingAPIError.badStatus(let code) = error {
            return code == 429 || (500..<600).contains(code)
        }
        if case ImageStoreError.incompleteDownload = error { return true }
        return false
    }
}

public func withRetry<T>(
    _ policy: RetryPolicy,
    isolation: isolated (any Actor)? = #isolation,
    _ operation: () async throws -> T
) async throws -> T {
    var attempt = 1
    while true {
        do {
            return try await operation()
        } catch where attempt < policy.maxAttempts && RetryPolicy.isTransient(error) {
            try await Task.sleep(for: policy.delay(afterFailure: attempt))
            attempt += 1
        }
    }
}

/// 连续失败达到阈值后熔断一段时间，避免断网时反复打接口。
public struct CircuitBreaker: Sendable {
    public let threshold: Int
    public let cooldown: TimeInterval
    public private(set) var consecutiveFailures = 0
    public private(set) var openUntil: Date?

    public init(threshold: Int = 5, cooldown: TimeInterval = 120) {
        self.threshold = threshold
        self.cooldown = cooldown
    }

    public func check(now: Date = .now) throws {
        if let openUntil, now < openUntil { throw BingAPIError.circuitOpen(until: openUntil) }
    }

    public mutating func recordSuccess() {
        consecutiveFailures = 0
        openUntil = nil
    }

    public mutating func recordFailure(now: Date = .now) {
        consecutiveFailures += 1
        if consecutiveFailures >= threshold { openUntil = now.addingTimeInterval(cooldown) }
    }
}
