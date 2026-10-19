import Foundation

/// `GetThemeCategories` 返回的一个主题。接口本身是以主题键为 key 的字典。
public struct ThemeCategory: Hashable, Identifiable, Sendable {
    public let key: String
    public let name: String
    /// `Regular` 或 `ThemePack`。
    public let type: String
    public let isNew: Bool
    public let previewURLs: [URL]

    public var id: String { key }
    public var isThemePack: Bool { type == "ThemePack" }

    public init(key: String, name: String, type: String = "Regular", isNew: Bool = false, previewURLs: [URL] = []) {
        self.key = key
        self.name = name
        self.type = type
        self.isNew = isNew
        self.previewURLs = previewURLs
    }

    public static let bing = ThemeCategory(key: "bing", name: "Bing")

    /// 字典解码后顺序丢失：`bing` 放第一，普通主题按键排序，主题包放最后。
    public static func decodeList(from data: Data) throws -> [ThemeCategory] {
        let raw = try JSONDecoder().decode([String: Raw].self, from: data)
        return raw.map { key, value in
            ThemeCategory(
                key: key,
                name: value.name,
                type: value.type ?? "Regular",
                isNew: value.isNew ?? false,
                previewURLs: (value.images ?? []).compactMap(URL.init(string:))
            )
        }
        .sorted { lhs, rhs in
            func rank(_ t: ThemeCategory) -> Int { t.key == "bing" ? 0 : (t.isThemePack ? 2 : 1) }
            return (rank(lhs), lhs.key) < (rank(rhs), rhs.key)
        }
    }

    private struct Raw: Decodable {
        let name: String
        let type: String?
        let isNew: Bool?
        let images: [String]?

        enum CodingKeys: String, CodingKey {
            case name = "Name", type = "Type", isNew = "IsNew", images = "Images"
        }
    }
}

/// 市场决定文案语言和图片 ID 的市场后缀。
public struct Market: Hashable, Identifiable, Sendable {
    public let code: String
    public let name: String
    public var id: String { code }

    public static let all: [Market] = [
        Market(code: "zh-CN", name: "中国"),
        Market(code: "en-US", name: "美国"),
        Market(code: "en-GB", name: "英国"),
        Market(code: "en-CA", name: "加拿大"),
        Market(code: "en-AU", name: "澳大利亚"),
        Market(code: "en-IN", name: "印度"),
        Market(code: "ja-JP", name: "日本"),
        Market(code: "de-DE", name: "德国"),
        Market(code: "fr-FR", name: "法国"),
        Market(code: "es-ES", name: "西班牙"),
        Market(code: "it-IT", name: "意大利"),
        Market(code: "pt-BR", name: "巴西"),
    ]

    /// 按系统语言地区挑一个支持的市场，找不到就用 en-US。
    public static func preferred(for locale: Locale = .current) -> String {
        let language = locale.language.languageCode?.identifier ?? "en"
        let region = locale.region?.identifier ?? "US"
        let code = "\(language)-\(region)"
        return all.contains { $0.code.caseInsensitiveCompare(code) == .orderedSame } ? code : "en-US"
    }
}
