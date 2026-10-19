import Foundation

public enum BingAPIError: LocalizedError, Equatable {
    case badStatus(Int)
    case invalidResponse
    case circuitOpen(until: Date)

    public var errorDescription: String? {
        switch self {
        case .badStatus(let code): "服务器返回 HTTP \(code)"
        case .invalidResponse: "服务器响应无效"
        case .circuitOpen: "网络连续失败，稍后自动重试"
        }
    }
}

/// `services.bingapis.com` v2 接口。都是公开 GET，不带密钥。
public actor BingAPIClient {
    public static let baseURL = URL(string: "https://services.bingapis.com/ge-apps/api/v2/")!

    private let session: URLSession
    private let retry: RetryPolicy
    private var breaker: CircuitBreaker

    public init(session: URLSession = .shared, retry: RetryPolicy = .init(), breaker: CircuitBreaker = .init()) {
        self.session = session
        self.retry = retry
        self.breaker = breaker
    }

    /// 每日图或主题图目录。每日图一次返回约 8 天。
    public func hpImages(market: String, theme: String, bicFilterEnabled: Bool) async throws -> [BingImage] {
        let url = Self.hpImagesURL(market: market, theme: theme, bicFilterEnabled: bicFilterEnabled)
        let data = try await get(url)
        return try JSONDecoder().decode(HPImagesResponse.self, from: data).images
    }

    public func themeCategories(market: String) async throws -> [ThemeCategory] {
        var components = URLComponents(url: Self.baseURL.appending(path: "BWC/GetThemeCategories"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "mkt", value: market)]
        return try ThemeCategory.decodeList(from: try await get(components.url!))
    }

    /// `defaultBrowser` / `dhpSetToBing` / `dseSetToBing` 是 Windows 上的默认项状态，Mac 上不适用，保持空值。
    public static func hpImagesURL(market: String, theme: String, bicFilterEnabled: Bool) -> URL {
        var components = URLComponents(url: baseURL.appending(path: "bwc/hpimages"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "mkt", value: market),
            URLQueryItem(name: "theme", value: theme),
            URLQueryItem(name: "defaultBrowser", value: ""),
            URLQueryItem(name: "dhpSetToBing", value: "false"),
            URLQueryItem(name: "dseSetToBing", value: "false"),
            URLQueryItem(name: "IsBicFilterEnabled", value: bicFilterEnabled ? "true" : "false"),
        ]
        return components.url!
    }

    private func get(_ url: URL) async throws -> Data {
        try breaker.check()
        do {
            let data = try await withRetry(retry) {
                var request = URLRequest(url: url, timeoutInterval: 30)
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw BingAPIError.invalidResponse }
                guard (200..<300).contains(http.statusCode) else { throw BingAPIError.badStatus(http.statusCode) }
                return data
            }
            breaker.recordSuccess()
            return data
        } catch {
            if !(error is CancellationError) { breaker.recordFailure() }
            throw error
        }
    }
}
