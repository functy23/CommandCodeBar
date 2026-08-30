import SwiftUI

struct SettingsView: View {
    var store: QuotaStore

    @AppStorage("menuBarMetric") private var menuBarMetricRaw = MenuBarMetric.fiveHourRemaining.rawValue
    @AppStorage("menuBarDisplayStyle") private var menuBarDisplayStyleRaw = MenuBarDisplayStyle.ringAndText.rawValue
    @AppStorage("panelHeroStyle") private var panelHeroStyleRaw = PanelHeroStyle.dualRings.rawValue
    @AppStorage("refreshInterval") private var refreshInterval = 60.0
    @AppStorage("stayInBackground") private var stayInBackground = true
    @AppStorage("launchAtLoginEnabled") private var launchAtLoginEnabled = false
    @State private var launchRegistered = LaunchAtLogin.isEnabled
    @State private var launchAtLoginError: String?

    /// 任一开关开启，系统里就要保留「允许在后台」注册
    private var needsSystemRegistration: Bool {
        launchAtLoginEnabled || stayInBackground
    }

    /// 把系统注册同步到两个开关的共同期望，失败时回读真实状态并报错
    private func syncRegistration() {
        do {
            try LaunchAtLogin.sync(enabled: needsSystemRegistration)
            launchRegistered = LaunchAtLogin.isEnabled
            launchAtLoginError = nil
        } catch {
            launchRegistered = LaunchAtLogin.isEnabled
            launchAtLoginError = error.localizedDescription
        }
    }
    @State private var customKey = ""

    private var metricIsIconOnly: Bool {
        menuBarMetricRaw == MenuBarMetric.iconOnly.rawValue
    }

    var body: some View {
        Form {
            Section("通用") {
                Toggle("开机自启动", isOn: Binding(
                    get: { launchAtLoginEnabled },
                    set: { newValue in
                        launchAtLoginEnabled = newValue
                        syncRegistration()
                    }
                ))
                Text("登录系统时自动启动。注册到系统设置 → 通用 → 登录项与扩展的「允许在后台」列表；若系统提示需要批准，请在系统设置中放行。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("常驻后台运行", isOn: Binding(
                    get: { stayInBackground },
                    set: { newValue in
                        stayInBackground = newValue
                        syncRegistration()
                    }
                ))
                Text("开启时向系统注册「允许在后台」权限，并按设定的间隔在后台持续刷新额度；关闭时不向系统注册，仅在打开面板时刷新，更省电。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !needsSystemRegistration && launchRegistered {
                    Text("系统注册将在注销后完全移除。")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                if let launchAtLoginError {
                    Label(launchAtLoginError, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

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
        .frame(width: 460, height: 560)
    }

    private var shortVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
