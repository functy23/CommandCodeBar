import SwiftUI

struct SettingsView: View {
    var store: QuotaStore

    @AppStorage("menuBarMetric") private var menuBarMetricRaw = MenuBarMetric.fiveHourRemaining.rawValue
    @AppStorage("menuBarDisplayStyle") private var menuBarDisplayStyleRaw = MenuBarDisplayStyle.ringAndText.rawValue
    @AppStorage("panelHeroStyle") private var panelHeroStyleRaw = PanelHeroStyle.dualRings.rawValue
    @AppStorage("refreshInterval") private var refreshInterval = 60.0
    @State private var customKey = ""

    private var metricIsIconOnly: Bool {
        menuBarMetricRaw == MenuBarMetric.iconOnly.rawValue
    }

    var body: some View {
        Form {
            Section("菜单栏") {
                Picker("显示指标", selection: $menuBarMetricRaw) {
                    ForEach(MenuBarMetric.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                Picker("显示样式", selection: $menuBarDisplayStyleRaw) {
                    ForEach(MenuBarDisplayStyle.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                .disabled(metricIsIconOnly)
                if metricIsIconOnly {
                    Text("显示样式在「仅图标」指标下不生效")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Picker("自动刷新间隔", selection: $refreshInterval) {
                    Text("30 秒").tag(30.0)
                    Text("1 分钟").tag(60.0)
                    Text("2 分钟").tag(120.0)
                    Text("5 分钟").tag(300.0)
                }
            }

            Section("面板") {
                Picker("用量展示", selection: $panelHeroStyleRaw) {
                    ForEach(PanelHeroStyle.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                Text("「双圆环」并列展示 5 小时与每周窗口的剩余比例；「双条形」以条形量表展示；「单圆环」只显示较紧窗口，并在下方列出两个窗口的明细。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("API Key") {
                LabeledContent("当前来源", value: store.keySourceSummary ?? "尚未抓取")
                SecureField("手动指定 API Key（可选）", text: $customKey)
                HStack {
                    Button("保存并刷新") {
                        UserDefaults.standard.set(
                            customKey.trimmingCharacters(in: .whitespacesAndNewlines),
                            forKey: "customAPIKey"
                        )
                        customKey = ""
                        Task { await store.refresh() }
                    }
                    .disabled(customKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("清除手动 Key", role: .destructive) {
                        UserDefaults.standard.removeObject(forKey: "customAPIKey")
                        Task { await store.refresh() }
                    }
                }
                Text("默认自动读取 Command Code CLI 的登录凭据 ~/.commandcode/auth.json。手动指定的 Key 仅保存在本机偏好设置中，优先级高于凭据文件。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("关于") {
                LabeledContent("账户", value: store.snapshot?.accountName ?? "未知")
                LabeledContent("版本", value: shortVersion)
                LabeledContent("数据来源", value: "api.commandcode.ai")
                Button("重新运行初始设置") {
                    OnboardingWindowController.shared.show(store: store)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 460)
    }

    private var shortVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
