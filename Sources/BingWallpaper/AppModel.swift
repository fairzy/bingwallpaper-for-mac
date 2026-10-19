import AppKit
import BingWallpaperCore
import Observation
import os

private let log = Logger(subsystem: "BingWallpaper", category: "refresh")

/// 应用状态和刷新周期，对应 Windows 版的 `DailyRefreshService` + `BingHPImageService`。
@MainActor
@Observable
final class AppModel {
    enum Status: Equatable {
        case idle
        case refreshing
        case failed(String)
    }

    let prefs = Preferences()
    private(set) var images: [BingImage] = []
    private(set) var themes: [ThemeCategory] = [.bing]
    private(set) var status: Status = .idle
    private(set) var preview: NSImage?
    private(set) var launchAtLogin = LaunchAtLogin.isEnabled

    @ObservationIgnored private let api = BingAPIClient()
    @ObservationIgnored private let store: ImageStore
    @ObservationIgnored private var loopTask: Task<Void, Never>?
    @ObservationIgnored private var isCycleRunning = false
    @ObservationIgnored private var failureCount = 0
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init() {
        do {
            store = try ImageStore()
        } catch {
            // Application Support 不可写时退到临时目录，至少能跑起来。
            log.error("ImageStore init failed: \(error.localizedDescription, privacy: .public)")
            store = try! ImageStore(root: FileManager.default.temporaryDirectory.appending(path: "BingWallpaper"))
        }
    }

    var currentImage: BingImage? {
        images.first { $0.id == prefs.currentImageID } ?? images.first
    }

    private var currentIndex: Int? {
        images.firstIndex { $0.id == currentImage?.id }
    }

    var canGoNewer: Bool { (currentIndex ?? 0) > 0 }
    var canGoOlder: Bool { (currentIndex ?? images.count) < images.count - 1 }
    var imagesDirectory: URL { store.imagesDirectory }

    // MARK: 生命周期

    func start() {
        guard loopTask == nil else { return }

        if !prefs.didFirstLaunchSetup {
            prefs.didFirstLaunchSetup = true
            if LaunchAtLogin.isAvailable { setLaunchAtLogin(true) }
        }

        Task { await loadCachedCatalog() }

        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.runCycle()
                let delay = RefreshPolicy.nextDelay(failures: self.failureCount, fastRefresh: self.prefs.fastRefreshEnabled)
                log.info("Next refresh in \(delay, privacy: .public)")
                try? await Task.sleep(for: delay)
            }
        }

        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                _ = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(15)) // 等网络恢复
                    await self?.runCycle()
                }
            }
        })
        // 接新显示器、切换 Space 后把当前壁纸补上去。
        let reapply: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.reapplyCurrent() }
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main, using: reapply))
        observers.append(workspace.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main, using: reapply))
    }

    // MARK: 刷新周期

    /// 一轮：拉主题 → 拉目录 → 下载全部图片 → 自动换图 → 清理。
    /// `manual` 为真时忽略「每日自动更换」开关，并且总是应用最新一张。
    func runCycle(manual: Bool = false) async {
        guard !isCycleRunning else {
            log.info("Skipping tick — previous cycle still running.")
            return
        }
        guard manual || prefs.dailyRefreshEnabled else {
            log.info("Daily refresh disabled; skipping.")
            return
        }
        isCycleRunning = true
        defer { isCycleRunning = false }
        status = .refreshing

        let market = prefs.market
        let theme = prefs.theme
        let key = prefs.catalogKey

        if let fetched = try? await api.themeCategories(market: market), !fetched.isEmpty {
            themes = fetched
        }

        do {
            let fetched = try await api.hpImages(market: market, theme: theme, bicFilterEnabled: prefs.bicFilterEnabled)
            guard !fetched.isEmpty else {
                failureCount += 1
                log.warning("Empty catalog (count=\(self.failureCount))")
                status = .failed("目录为空，稍后重试")
                return
            }
            try await store.setCatalog(fetched, for: key)

            var downloadErrors: [Error] = []
            for image in fetched {
                do { try await store.ensureDownloaded(image) } catch { downloadErrors.append(error) }
            }

            // 用户在这一轮里切了主题/市场，就不要用旧结果覆盖界面。
            guard key == prefs.catalogKey else { return }
            images = fetched.filter { store.hasFile(for: $0) }
            if images.isEmpty, let error = downloadErrors.first { throw error }

            applyAutomaticSelection(force: manual)
            prefs.lastDailyImageRefreshTime = .now
            failureCount = 0
            status = downloadErrors.isEmpty ? .idle : .failed("有 \(downloadErrors.count) 张图片下载失败")

            let protected = Set([currentImage?.fileName].compactMap { $0 })
            let removed = try await store.cleanup(keepingCatalogs: [key], protectedFiles: protected)
            if removed > 0 { log.info("ImageCleanup removed \(removed) files") }
        } catch is CancellationError {
            status = .idle
        } catch {
            failureCount += 1
            log.error("Refresh failed: \(error.localizedDescription, privacy: .public)")
            status = .failed(error.localizedDescription)
        }
    }

    /// 每日图：出现新的最新一张时换上。其他主题：每天轮换到下一张。
    private func applyAutomaticSelection(force: Bool) {
        guard let newest = images.first else { return }
        if prefs.theme == ThemeCategory.bing.key {
            if force || newest.id != prefs.lastAutoAppliedImageID {
                prefs.lastAutoAppliedImageID = newest.id
                apply(newest)
            }
        } else {
            let today = RefreshPolicy.dayKey()
            let currentInCatalog = images.contains { $0.id == prefs.currentImageID }
            if force || today != prefs.lastRotationDay || !currentInCatalog {
                prefs.lastRotationDay = today
                let next = currentIndex.map { images[($0 + 1) % images.count] } ?? newest
                apply(currentInCatalog ? next : newest)
            }
        }
        if preview == nil { loadPreview() }
    }

    private func loadCachedCatalog() async {
        images = await store.catalog(for: prefs.catalogKey).filter { store.hasFile(for: $0) }
        loadPreview()
    }

    // MARK: 用户操作

    func apply(_ image: BingImage) {
        let url = store.fileURL(for: image)
        do {
            try WallpaperSetter.apply(url)
            prefs.currentImageID = image.id
            loadPreview()
        } catch {
            log.error("Set wallpaper failed: \(error.localizedDescription, privacy: .public)")
            status = .failed("设置壁纸失败：\(error.localizedDescription)")
        }
    }

    func showNewer() {
        guard let i = currentIndex, i > 0 else { return }
        apply(images[i - 1])
    }

    func showOlder() {
        guard let i = currentIndex, i < images.count - 1 else { return }
        apply(images[i + 1])
    }

    func refreshNow() {
        Task { await runCycle(manual: true) }
    }

    func selectTheme(_ key: String) {
        guard key != prefs.theme else { return }
        prefs.theme = key
        catalogDidChange()
    }

    func selectMarket(_ code: String) {
        guard code != prefs.market else { return }
        prefs.market = code
        catalogDidChange()
    }

    func setBicFilter(_ enabled: Bool) {
        prefs.bicFilterEnabled = enabled
        refreshNow()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
        } catch {
            log.error("Launch at login failed: \(error.localizedDescription, privacy: .public)")
            status = .failed("登录启动设置失败：\(error.localizedDescription)")
        }
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    func reapplyCurrent() {
        guard let image = currentImage, store.hasFile(for: image) else { return }
        try? WallpaperSetter.apply(store.fileURL(for: image))
    }

    private func catalogDidChange() {
        prefs.lastAutoAppliedImageID = nil
        prefs.lastRotationDay = nil
        Task {
            await loadCachedCatalog()
            await runCycle(manual: true)
        }
    }

    private func loadPreview() {
        preview = currentImage.flatMap { Thumbnail.make(from: store.fileURL(for: $0)) }
    }
}
