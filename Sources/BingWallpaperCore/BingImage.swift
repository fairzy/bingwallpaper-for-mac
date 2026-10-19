import Foundation

/// `hpimages` 目录里的一条记录。字段名与接口保持一致，只解码用得到的部分。
public struct BingImage: Codable, Hashable, Identifiable, Sendable {
    /// 每日图是 `yyyyMMdd`；主题图是 `Cat_38` 这类序号。
    public let startdate: String
    public let enddate: String?
    public let urlbase: String
    public let title: String?
    public let headline: String?
    public let summary: String?
    public let copyrighttext: String?
    public let copyrightlink: String?
    public let quiz: String?
    public let theme: [String]?
    public let sourceType: String?

    enum CodingKeys: String, CodingKey {
        case startdate, enddate, urlbase, title, headline
        case summary = "description"
        case copyrighttext, copyrightlink, quiz, theme, sourceType
    }

    public init(
        startdate: String, enddate: String? = nil, urlbase: String,
        title: String? = nil, headline: String? = nil, summary: String? = nil,
        copyrighttext: String? = nil, copyrightlink: String? = nil, quiz: String? = nil,
        theme: [String]? = nil, sourceType: String? = nil
    ) {
        self.startdate = startdate
        self.enddate = enddate
        self.urlbase = urlbase
        self.title = title
        self.headline = headline
        self.summary = summary
        self.copyrighttext = copyrighttext
        self.copyrightlink = copyrightlink
        self.quiz = quiz
        self.theme = theme
        self.sourceType = sourceType
    }

    public var id: String { imageID }

    /// `urlbase` 中 `id=` 的值，例如 `OHR.VeniceSunrise_ZH-CN5251815339_UHD.jpg`。
    public var imageID: String {
        URLComponents(string: urlbase)?.queryItems?.first { $0.name == "id" }?.value ?? urlbase
    }

    /// `OHR.` 是必应首页每日图，`OBGA.` 是图库或特别企划。
    public var isHomepageImage: Bool { imageID.hasPrefix("OHR.") }

    public var date: Date? {
        guard startdate.count == 8, let value = Int(startdate) else { return nil }
        var components = DateComponents()
        components.year = value / 10_000
        components.month = value / 100 % 100
        components.day = value % 100
        return Calendar(identifier: .gregorian).date(from: components)
    }

    /// CDN 地址：http 升级为 https，再追加与 Windows 版相同的 `qlt=85&o=4`。
    public var downloadURL: URL? {
        guard var components = URLComponents(string: urlbase) else { return nil }
        if components.scheme == "http" { components.scheme = "https" }
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "qlt", value: "85"),
            URLQueryItem(name: "o", value: "4"),
        ]
        return components.url
    }

    /// 本地文件名，只保留安全字符，统一 `.jpg` 结尾。
    public var fileName: String {
        var name = imageID
        if name.lowercased().hasSuffix(".jpg") { name.removeLast(4) }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let safe = name.unicodeScalars.map { allowed.contains($0) ? String($0) : "_" }.joined()
        return safe + ".jpg"
    }

    public var copyrightURL: URL? { copyrightlink.flatMap(URL.init(string:)) }
    public var quizURL: URL? { quiz.flatMap(URL.init(string:)) }
}

public struct HPImagesResponse: Decodable, Sendable {
    public let images: [BingImage]
    public let imageCount: Int?
}
