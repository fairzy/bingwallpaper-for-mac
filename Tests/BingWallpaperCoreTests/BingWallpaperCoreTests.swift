import Foundation
import Testing
@testable import BingWallpaperCore

private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

@Suite struct BingImageTests {
    @Test func decodesCatalog() throws {
        let response = try JSONDecoder().decode(HPImagesResponse.self, from: fixture("hpimages-zh-CN"))
        #expect(response.images.count == 3)
        let first = try #require(response.images.first)
        #expect(first.imageID == "OHR.VeniceSunrise_ZH-CN5251815339_UHD.jpg")
        #expect(first.isHomepageImage)
        #expect(first.headline == "水上通衢")
        #expect(first.summary?.isEmpty == false)
        #expect(first.theme == ["bing"])
        #expect(first.copyrightURL != nil)
    }

    @Test func linksKeepExistingEscapesAndOnlyEncodeQuotes() throws {
        let first = try #require(try JSONDecoder().decode(HPImagesResponse.self, from: fixture("hpimages-zh-CN")).images.first)
        let copyright = try #require(first.copyrightURL).absoluteString
        #expect(copyright.hasPrefix("https://www.bing.com/search?q=%e5%a8%81%e5%b0%bc"))
        #expect(!copyright.contains("%25"))
        #expect(copyright.contains("HpDate:%2220261018_1600%22"))
        #expect(first.quizURL?.absoluteString == "https://www.bing.com/search?q=Bing+homepage+quiz&filters=WQOskey:%22HPQuiz_20261019_VeniceSunrise%22&FORM=BGAQ")
    }

    @Test func downloadURLUpgradesToHTTPSAndAddsQuality() throws {
        let image = BingImage(startdate: "20261018", urlbase: "http://ts1.tc.mm.bing.net/th?id=OHR.DolbadarnWales_ZH-CN3649667806_UHD.jpg")
        let url = try #require(image.downloadURL)
        #expect(url.absoluteString == "https://ts1.tc.mm.bing.net/th?id=OHR.DolbadarnWales_ZH-CN3649667806_UHD.jpg&qlt=85&o=4")
    }

    @Test func fileNameIsSafeAndEndsWithJPG() {
        let daily = BingImage(startdate: "20261018", urlbase: "http://x/th?id=OHR.DolbadarnWales_ZH-CN3649667806_UHD.jpg")
        #expect(daily.fileName == "OHR.DolbadarnWales_ZH-CN3649667806_UHD.jpg")
        let stock = BingImage(startdate: "Cat_38", urlbase: "http://x/th?id=OBGA.AdobeStock_390801769")
        #expect(stock.fileName == "OBGA.AdobeStock_390801769.jpg")
        #expect(!stock.isHomepageImage)
        let weird = BingImage(startdate: "x", urlbase: "http://x/th?id=a/b%20c")
        #expect(weird.fileName == "a_b_c.jpg")
    }

    @Test func parsesDateOnlyForDailyImages() throws {
        let daily = BingImage(startdate: "20261019", urlbase: "http://x/th?id=a")
        let date = try #require(daily.date)
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        #expect(c.year == 2026 && c.month == 10 && c.day == 19)
        #expect(BingImage(startdate: "Cat_38", urlbase: "http://x/th?id=a").date == nil)
    }

    @Test func hpImagesURLMatchesWindowsClient() {
        let url = BingAPIClient.hpImagesURL(market: "zh-CN", theme: "wild animal", bicFilterEnabled: true)
        #expect(url.absoluteString == "https://services.bingapis.com/ge-apps/api/v2/bwc/hpimages?mkt=zh-CN&theme=wild%20animal&defaultBrowser=&dhpSetToBing=false&dseSetToBing=false&IsBicFilterEnabled=true")
    }
}

@Suite struct ThemeCategoryTests {
    @Test func decodesAndOrdersThemes() throws {
        let themes = try ThemeCategory.decodeList(from: fixture("themes-zh-CN"))
        #expect(themes.first?.key == "bing")
        #expect(themes.last?.isThemePack == true)
        let cat = try #require(themes.first { $0.key == "cat" })
        #expect(cat.name == "猫")
        #expect(cat.previewURLs.count == 3)
    }

    @Test func preferredMarketFallsBack() {
        #expect(Market.preferred(for: Locale(identifier: "zh_CN")) == "zh-CN")
        #expect(Market.preferred(for: Locale(identifier: "sw_KE")) == "en-US")
    }
}

@Suite struct ResilienceTests {
    @Test func retryDelayDoubles() {
        let policy = RetryPolicy(maxAttempts: 4, baseDelay: .seconds(1))
        #expect(policy.delay(afterFailure: 1) == .seconds(1))
        #expect(policy.delay(afterFailure: 3) == .seconds(4))
    }

    @Test func classifiesTransientErrors() {
        #expect(RetryPolicy.isTransient(URLError(.timedOut)))
        #expect(RetryPolicy.isTransient(BingAPIError.badStatus(503)))
        #expect(!RetryPolicy.isTransient(BingAPIError.badStatus(404)))
        #expect(!RetryPolicy.isTransient(ImageStoreError.invalidImage))
    }

    @Test func withRetryStopsOnPermanentError() async {
        var calls = 0
        await #expect(throws: BingAPIError.self) {
            try await withRetry(RetryPolicy(maxAttempts: 3, baseDelay: .zero)) {
                calls += 1
                throw BingAPIError.badStatus(404)
            }
        }
        #expect(calls == 1)
    }

    @Test func withRetryRetriesTransientError() async throws {
        var calls = 0
        let value = try await withRetry(RetryPolicy(maxAttempts: 3, baseDelay: .zero)) {
            calls += 1
            if calls < 3 { throw URLError(.timedOut) }
            return 42
        }
        #expect(value == 42 && calls == 3)
    }

    @Test func circuitOpensAfterThresholdAndResets() throws {
        var breaker = CircuitBreaker(threshold: 2, cooldown: 60)
        let now = Date(timeIntervalSince1970: 1_000)
        breaker.recordFailure(now: now)
        try breaker.check(now: now)
        breaker.recordFailure(now: now)
        #expect(throws: BingAPIError.self) { try breaker.check(now: now.addingTimeInterval(30)) }
        try breaker.check(now: now.addingTimeInterval(61))
        breaker.recordSuccess()
        #expect(breaker.consecutiveFailures == 0)
    }

    @Test func refreshBackoffIsCapped() {
        #expect(RefreshPolicy.retryDelay(afterFailures: 1) == .seconds(60))
        #expect(RefreshPolicy.retryDelay(afterFailures: 3) == .seconds(240))
        #expect(RefreshPolicy.retryDelay(afterFailures: 20) == .seconds(1800))
        #expect(RefreshPolicy.nextDelay(failures: 0, fastRefresh: false, spread: 0) == .seconds(1800))
        #expect(RefreshPolicy.nextDelay(failures: 0, fastRefresh: true, spread: 10) == .seconds(310))
    }
}

@Suite struct ImageStoreTests {
    private func makeStore() throws -> ImageStore {
        try ImageStore(root: FileManager.default.temporaryDirectory.appending(path: "bw-tests-\(UUID().uuidString)"))
    }

    @Test func persistsCatalogAcrossInstances() async throws {
        let store = try makeStore()
        let image = BingImage(startdate: "20261019", urlbase: "http://x/th?id=OHR.A_UHD.jpg")
        try await store.setCatalog([image], for: "zh-CN/bing")
        let reopened = try ImageStore(root: store.root)
        #expect(await reopened.catalog(for: "zh-CN/bing") == [image])
    }

    @Test func cleanupRemovesUnreferencedFilesButKeepsProtected() async throws {
        let store = try makeStore()
        let kept = BingImage(startdate: "1", urlbase: "http://x/th?id=OHR.Kept_UHD.jpg")
        let other = BingImage(startdate: "2", urlbase: "http://x/th?id=OBGA.Other")
        try await store.setCatalog([kept], for: "zh-CN/bing")
        try await store.setCatalog([other], for: "zh-CN/cat")
        for name in [kept.fileName, other.fileName, "Orphan.jpg", "Wallpaper.jpg"] {
            try Data([0]).write(to: store.imagesDirectory.appending(path: name))
        }

        let removed = try await store.cleanup(keepingCatalogs: ["zh-CN/bing"], protectedFiles: ["Wallpaper.jpg"])

        #expect(removed == 2)
        #expect(store.hasFile(for: kept))
        #expect(!store.hasFile(for: other))
        #expect(FileManager.default.fileExists(atPath: store.imagesDirectory.appending(path: "Wallpaper.jpg").path))
        #expect(await store.catalog(for: "zh-CN/cat").isEmpty)
    }

    @Test func validateRejectsTruncatedAndNonImageFiles() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "bw-validate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let text = dir.appending(path: "x.jpg")
        try Data("not an image".utf8).write(to: text)
        #expect(throws: ImageStoreError.self) { try ImageStore.validate(fileAt: text, expectedLength: -1) }
        #expect(throws: ImageStoreError.self) { try ImageStore.validate(fileAt: text, expectedLength: 9_999) }
    }
}

/// 联网测试，默认跳过：`BW_LIVE_TESTS=1 swift test --filter LiveAPITests`
@Suite(.enabled(if: ProcessInfo.processInfo.environment["BW_LIVE_TESTS"] == "1"))
struct LiveAPITests {
    @Test func fetchesCatalogAndDownloadsNewestImage() async throws {
        let api = BingAPIClient()
        let images = try await api.hpImages(market: "zh-CN", theme: "bing", bicFilterEnabled: false)
        #expect(images.count >= 1)
        let themes = try await api.themeCategories(market: "zh-CN")
        #expect(themes.first?.key == "bing")

        let store = try ImageStore(root: FileManager.default.temporaryDirectory.appending(path: "bw-live-\(UUID().uuidString)"))
        let url = try await store.ensureDownloaded(try #require(images.first))
        try ImageStore.validate(fileAt: url, expectedLength: -1)
    }
}
