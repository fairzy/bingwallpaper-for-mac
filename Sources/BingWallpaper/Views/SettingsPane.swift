import BingWallpaperCore
import SwiftUI

struct SettingsPane: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("市场", selection: Binding(get: { model.prefs.market }, set: model.selectMarket)) {
                ForEach(Market.all) { market in
                    Text("\(market.name)  \(market.code)").tag(market.code)
                }
            }
            .pickerStyle(.menu)

            Toggle("每日自动更换壁纸", isOn: Bindable(model.prefs).dailyRefreshEnabled)
            Toggle("过滤 AI 生成的图片", isOn: Binding(get: { model.prefs.bicFilterEnabled }, set: model.setBicFilter))
            Toggle("登录时启动", isOn: Binding(get: { model.launchAtLogin }, set: model.setLaunchAtLogin))
                .disabled(!LaunchAtLogin.isAvailable)
                .help(LaunchAtLogin.isAvailable ? "" : "需要以 .app 形式运行")

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
