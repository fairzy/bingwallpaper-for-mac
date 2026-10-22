import BingWallpaperCore
import SwiftUI

struct SettingsPane: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("市场", selection: Binding(get: { model.prefs.market }, set: { model.selectMarket($0) })) {
                ForEach(Market.all) { market in
                    Text("\(market.localizedName)  \(market.code)").tag(market.code)
                }
            }
            .pickerStyle(.menu)

            Toggle("每日自动更换壁纸", isOn: Bindable(model.prefs).dailyRefreshEnabled)
            Toggle("过滤 AI 生成的图片", isOn: Binding(get: { model.prefs.bicFilterEnabled }, set: { model.setBicFilter($0) }))
            Toggle("登录时启动", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                .disabled(!LaunchAtLogin.isAvailable)
                .help(LaunchAtLogin.isAvailable ? Text(verbatim: "") : Text("需要以 .app 形式运行"))

            Button("在 Finder 中打开图片文件夹") {
                NSWorkspace.shared.open(model.imagesDirectory)
            }
            .buttonStyle(.link)
            .font(.caption)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }
}

extension Market {
    /// 菜单里的市场名跟着系统语言走。键是简体，缺翻译时仍显示简体。
    var localizedName: String {
        switch code {
        case "zh-CN": String(localized: "中国")
        case "en-US": String(localized: "美国")
        case "en-GB": String(localized: "英国")
        case "en-CA": String(localized: "加拿大")
        case "en-AU": String(localized: "澳大利亚")
        case "en-IN": String(localized: "印度")
        case "ja-JP": String(localized: "日本")
        case "de-DE": String(localized: "德国")
        case "fr-FR": String(localized: "法国")
        case "es-ES": String(localized: "西班牙")
        case "it-IT": String(localized: "意大利")
        case "pt-BR": String(localized: "巴西")
        default: name
        }
    }
}
