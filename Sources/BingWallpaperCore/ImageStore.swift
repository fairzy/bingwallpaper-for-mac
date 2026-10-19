import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ImageStoreError: LocalizedError {
    case badURL
    case badStatus(Int)
    case incompleteDownload(expected: Int64, actual: Int64)
    case invalidImage

    public var errorDescription: String? {
        switch self {
        case .badURL: "图片地址无效"
        case .badStatus(let code): "图片下载失败（HTTP \(code)）"
        case .incompleteDownload(let expected, let actual): "图片不完整（\(actual)/\(expected) 字节）"
        case .invalidImage: "下载的文件不是有效图片"
        }
    }
}

/// 本地图片和目录索引。
///
/// 布局（`root` 默认是 `~/Library/Application Support/BingWallpaper`）：
/// - `images/<fileName>.jpg`：图片文件，所有主题共用一份，相当于 Windows 版的硬链接
/// - `index.json`：每个「市场/主题」最近一次拉到的目录
public actor ImageStore {
    public nonisolated let root: URL
    public nonisolated let imagesDirectory: URL
    private let indexURL: URL
    private let session: URLSession
    private let retry: RetryPolicy
    private var index: Index

    struct Index: Codable {
        var version = 1
        var catalogs: [String: [BingImage]] = [:]
    }

    public static var defaultRoot: URL {
        URL.applicationSupportDirectory.appending(path: "BingWallpaper", directoryHint: .isDirectory)
    }

    public static func catalogKey(market: String, theme: String) -> String { "\(market)/\(theme)" }

    public init(root: URL = ImageStore.defaultRoot, session: URLSession = .shared, retry: RetryPolicy = .init()) throws {
        self.root = root
        self.imagesDirectory = root.appending(path: "images", directoryHint: .isDirectory)
        self.indexURL = root.appending(path: "index.json")
        self.session = session
        self.retry = retry
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: indexURL), let index = try? JSONDecoder().decode(Index.self, from: data) {
            self.index = index
        } else {
            self.index = Index()
        }
    }

    // MARK: 目录

    public func catalog(for key: String) -> [BingImage] { index.catalogs[key] ?? [] }

    public func setCatalog(_ images: [BingImage], for key: String) throws {
        index.catalogs[key] = images
        try saveIndex()
    }

    private func saveIndex() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(index).write(to: indexURL, options: .atomic)
    }

    // MARK: 文件

    public nonisolated func fileURL(for image: BingImage) -> URL {
        imagesDirectory.appending(path: image.fileName)
    }

    public nonisolated func hasFile(for image: BingImage) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: image).path)
    }

    /// 先写临时文件，核对长度和图片格式，通过后才移到正式路径。半张图不会出现在正式路径上。
    @discardableResult
    public func ensureDownloaded(_ image: BingImage) async throws -> URL {
        let destination = fileURL(for: image)
        if FileManager.default.fileExists(atPath: destination.path) { return destination }
        guard let remote = image.downloadURL else { throw ImageStoreError.badURL }

        let staged = try await withRetry(retry) { try await download(remote) }
        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: staged)
        } else {
            try FileManager.default.moveItem(at: staged, to: destination)
        }
        return destination
    }

    private func download(_ url: URL) async throws -> URL {
        let (temporary, response) = try await session.download(for: URLRequest(url: url, timeoutInterval: 60))
        let staged = imagesDirectory.appending(path: ".partial-\(UUID().uuidString)")
        try FileManager.default.moveItem(at: temporary, to: staged)
        do {
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw ImageStoreError.badStatus(http.statusCode)
            }
            try Self.validate(fileAt: staged, expectedLength: response.expectedContentLength)
            return staged
        } catch {
            try? FileManager.default.removeItem(at: staged)
            throw error
        }
    }

    /// `expectedLength` 为 -1（服务器没给 Content-Length）时只做格式校验。
    public static func validate(fileAt url: URL, expectedLength: Int64) throws {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        if expectedLength > 0, size != expectedLength {
            throw ImageStoreError.incompleteDownload(expected: expectedLength, actual: size)
        }
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let typeID = CGImageSourceGetType(source) as String?,
            UTType(typeID)?.conforms(to: .image) == true,
            CGImageSourceGetCount(source) > 0,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int, width > 0,
            let height = properties[kCGImagePropertyPixelHeight] as? Int, height > 0
        else {
            throw ImageStoreError.invalidImage
        }
    }

    // MARK: 清理

    /// 只保留 `keepingCatalogs` 里的目录；删掉没有任何目录引用、也不在 `protectedFiles` 里的文件。
    /// 返回删除的文件数。
    @discardableResult
    public func cleanup(keepingCatalogs keep: Set<String>, protectedFiles: Set<String> = []) throws -> Int {
        index.catalogs = index.catalogs.filter { keep.contains($0.key) }
        try saveIndex()

        let referenced = Set(index.catalogs.values.joined().map(\.fileName)).union(protectedFiles)
        let staleCutoff = Date.now.addingTimeInterval(-3600)
        var removed = 0
        let files = try FileManager.default.contentsOfDirectory(
            at: imagesDirectory, includingPropertiesForKeys: [.contentModificationDateKey]
        )
        for file in files {
            let name = file.lastPathComponent
            let shouldRemove: Bool
            if name.hasPrefix(".partial-") {
                let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                shouldRemove = modified < staleCutoff
            } else {
                shouldRemove = name.hasSuffix(".jpg") && !referenced.contains(name)
            }
            if shouldRemove, (try? FileManager.default.removeItem(at: file)) != nil { removed += 1 }
        }
        return removed
    }
}
