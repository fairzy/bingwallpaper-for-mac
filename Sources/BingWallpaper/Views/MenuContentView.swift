import BingWallpaperCore
import SwiftUI

struct MenuContentView: View {
    @Bindable var model: AppModel
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PreviewCard(model: model)
            if let image = model.currentImage {
                CaptionView(image: image)
            }
            Divider()
            themePicker
            if showSettings {
                SettingsPane(model: model)
            }
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 380)
    }

    private var themePicker: some View {
        Picker("主题", selection: Binding(get: { model.prefs.theme }, set: model.selectTheme)) {
            ForEach(model.themes) { theme in
                Text(theme.isNew ? "\(theme.name)（新）" : theme.name).tag(theme.key)
            }
        }
        .pickerStyle(.menu)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            StatusLabel(status: model.status, lastRefresh: model.prefs.lastDailyImageRefreshTime)
            Spacer()
            Button {
                model.refreshNow()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("立即刷新")
            .disabled(model.status == .refreshing)
            Button {
                withAnimation(.snappy) { showSettings.toggle() }
            } label: {
                Image(systemName: showSettings ? "gearshape.fill" : "gearshape")
            }
            .help("设置")
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .help("退出")
        }
        .buttonStyle(.borderless)
        .imageScale(.large)
    }
}

private struct PreviewCard: View {
    let model: AppModel

    var body: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            if let preview = model.preview {
                Image(nsImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if model.status == .refreshing {
                ProgressView()
            } else {
                Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
            }
        }
        .frame(height: 198)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .leading) {
            NavButton(systemName: "chevron.left", help: "上一张（更早）", enabled: model.canGoOlder, action: model.showOlder)
        }
        .overlay(alignment: .trailing) {
            NavButton(systemName: "chevron.right", help: "下一张（更新）", enabled: model.canGoNewer, action: model.showNewer)
        }
    }
}

private struct NavButton: View {
    let systemName: String
    let help: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(.semibold))
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .padding(8)
        .opacity(enabled ? 1 : 0)
        .disabled(!enabled)
        .help(help)
    }
}

private struct CaptionView: View {
    let image: BingImage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 4) {
                if let headline = image.headline, !headline.isEmpty {
                    Text(headline).font(.headline)
                }
                if let title = image.title {
                    Text(title).font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    if let date = image.date {
                        Text(date, format: .dateTime.year().month().day())
                    }
                    if let copyright = image.copyrighttext {
                        Text(copyright).lineLimit(1).truncationMode(.tail)
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
            .textSelection(.enabled)
            HStack(spacing: 14) {
                if let url = image.copyrightURL {
                    LinkButton(title: "了解更多", url: url)
                }
                if let url = image.quizURL {
                    LinkButton(title: "每日测验", url: url)
                }
            }
            .font(.caption)
            .padding(.top, 2)
        }
    }
}

/// 用按钮代替 `Link`，点击范围只限各自的文字，两个链接挨着时不会串。
private struct LinkButton: View {
    let title: String
    let url: URL

    var body: some View {
        Button(title) { NSWorkspace.shared.open(url) }
            .buttonStyle(.link)
            .fixedSize()
            .contentShape(Rectangle())
            .help(url.absoluteString)
    }
}

private struct StatusLabel: View {
    let status: AppModel.Status
    let lastRefresh: Date?

    var body: some View {
        Group {
            switch status {
            case .refreshing:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("正在刷新…")
                }
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            case .idle:
                if let lastRefresh {
                    Text("更新于 \(lastRefresh, format: .relative(presentation: .named))")
                } else {
                    Text("尚未刷新")
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
