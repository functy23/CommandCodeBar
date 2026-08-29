import SwiftUI

// MARK: - 引导主流程（欢迎 → 连接 → 个性化 → 完成）

struct OnboardingFlowView: View {
    var store: QuotaStore

    @State private var step = 0
    @State private var movedForward = true
    private let stepCount = 4

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch step {
                case 0: WelcomeStep().transition(stepTransition)
                case 1: ConnectStep(store: store).transition(stepTransition)
                case 2: CustomizeStep(store: store).transition(stepTransition)
                default: FinishStep(store: store).transition(stepTransition)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
        }
        .background(gradientBackground.ignoresSafeArea())
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: step)
    }

    private var footer: some View {
        HStack {
            Button("上一步") {
                moveTo(step - 1)
            }
            .disabled(step == 0)
            .opacity(step == 0 ? 0.35 : 1)

            Spacer()
            DotsIndicator(count: stepCount, current: step)
            Spacer()

            if step == stepCount - 1 {
                Button("开始使用") {
                    finish()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            } else {
                Button("下一步") {
                    moveTo(step + 1)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 6)
        .padding(.bottom, 22)
    }

    // MARK: 导航

    private func moveTo(_ target: Int) {
        guard (0 ..< stepCount).contains(target) else { return }
        movedForward = target > step
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            step = target
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        OnboardingWindowController.shared.close()
        Task { await store.refreshIfNeeded() }
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: movedForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: movedForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private var gradientBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.12),
                    Color(red: 0.55, green: 0.35, blue: 0.85).opacity(0.08),
                    .clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - 第 1 步：欢迎

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 0) {
            PulsingLogo()
                .frame(width: 88, height: 88)
                .padding(.bottom, 26)
                .staggerAppear(0)

            Text("欢迎使用 CommandCodeBar")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .staggerAppear(1)
            Text("Command Code 的额度用量，常驻你的菜单栏")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
                .staggerAppear(2)

            VStack(alignment: .leading, spacing: 16) {
                featureRow("gauge.with.needle", "实时额度", "5 小时与每周用量窗口、剩余额度一目了然")
                featureRow("arrow.triangle.2.circlepath", "自动刷新", "后台定时同步，打开面板即刻看到最新数据")
                featureRow("lock.shield", "本地运行", "仅读取本机 CLI 登录凭据，无任何遥测")
            }
            .padding(.top, 30)
            .staggerAppear(3)
        }
        .padding(.horizontal, 48)
    }

    private func featureRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - 第 2 步：连接 Command Code

private struct ConnectStep: View {
    var store: QuotaStore

    @State private var phase: CheckPhase = .checking
    @State private var snapshot: QuotaSnapshot?
    @State private var keySource: String?
    @State private var manualKey = ""
    @State private var checkAttempt = 0

    enum CheckPhase: Equatable {
        case checking
        case success
        case missingKey
        case failed(String)
    }

    var body: some View {
        VStack(spacing: 22) {
            StepHeader(
                showsLogo: true,
                title: "连接 Command Code",
                subtitle: "自动检测本机 CLI 登录凭据，并拉取一次真实额度数据"
            )
            .staggerAppear(0)

            checkContent
                .frame(maxWidth: 430)
                .staggerAppear(1)
        }
        .task(id: checkAttempt) {
            await runCheck()
        }
    }

    @ViewBuilder
    private var checkContent: some View {
        switch phase {
        case .checking:
            VStack(spacing: 12) {
                ProgressView().controlSize(.regular)
                Text("正在检测 ~/.commandcode/auth.json …")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 46)

        case .success:
            VStack(spacing: 16) {
                AnimatedCheckmark()
                VStack(spacing: 0) {
                    infoRow("Key 来源", keySource ?? "—")
                    Divider().opacity(0.5)
                    infoRow("账户", snapshot?.accountName ?? "—")
                    Divider().opacity(0.5)
                    infoRow("套餐", store.planBadgeText ?? "—")
                    Divider().opacity(0.5)
                    infoRow("剩余额度", snapshot.map { "$" + Fmt.credits($0.creditsRemaining) } ?? "—")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))

                Text("连接成功，随时可以在菜单栏查看额度")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

        case .missingKey:
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 30))
                    .foregroundStyle(.orange)
                Text("未找到 Command Code API Key")
                    .font(.headline)
                Text("请先完成 Command Code CLI 登录（会生成 ~/.commandcode/auth.json），或在下方直接粘贴 API Key。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                manualKeyField
            }

        case .failed(let message):
            VStack(spacing: 14) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 30))
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                manualKeyField
                Button("重试") {
                    checkAttempt += 1
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var manualKeyField: some View {
        HStack(spacing: 8) {
            SecureField("粘贴 API Key（user_…）", text: $manualKey)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)
            Button("保存并重试") {
                UserDefaults.standard.set(
                    manualKey.trimmingCharacters(in: .whitespacesAndNewlines),
                    forKey: "customAPIKey"
                )
                manualKey = ""
                checkAttempt += 1
            }
            .disabled(manualKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func runCheck() async {
        phase = .checking
        let service = QuotaService()
        guard let (_, source) = service.resolveKey() else {
            phase = .missingKey
            return
        }
        keySource = source.summary
        do {
            let result = try await service.fetchQuota()
            snapshot = result.snapshot
            phase = .success
            await store.refresh()
        } catch {
            phase = .failed(
                (error as? QuotaError)?.errorDescription ?? error.localizedDescription
            )
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 9)
    }
}

// MARK: - 第 3 步：个性化菜单栏

private struct CustomizeStep: View {
    var store: QuotaStore

    @State private var metric: MenuBarMetric
    @State private var style: MenuBarDisplayStyle
    @State private var panelStyle: PanelHeroStyle
    @State private var interval: Double

    init(store: QuotaStore) {
        self.store = store
        let defaults = UserDefaults.standard
        _metric = State(
            initialValue: MenuBarMetric(
                rawValue: defaults.string(forKey: "menuBarMetric") ?? ""
            ) ?? .fiveHourRemaining
        )
        _style = State(
            initialValue: MenuBarDisplayStyle(
                rawValue: defaults.string(forKey: "menuBarDisplayStyle") ?? ""
            ) ?? .ringAndText
        )
        _panelStyle = State(
            initialValue: PanelHeroStyle(
                rawValue: defaults.string(forKey: "panelHeroStyle") ?? ""
            ) ?? .dualRings
        )
        let stored = defaults.double(forKey: "refreshInterval")
        _interval = State(initialValue: stored >= 30 ? stored : 60)
    }

    var body: some View {
        VStack(spacing: 20) {
            StepHeader(
                icon: "slider.horizontal.3",
                title: "个性化显示",
                subtitle: "菜单栏与面板会实时跟随你的选择"
            )
            .staggerAppear(0)

            VStack(spacing: 14) {
                MenuBarPreview(store: store, metric: metric, style: style)

                pickerRow("菜单栏 · 显示指标") {
                    Picker("", selection: $metric) {
                        ForEach(MenuBarMetric.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 240)
                    .onChange(of: metric) { _, newValue in
                        UserDefaults.standard.set(newValue.rawValue, forKey: "menuBarMetric")
                    }
                }

                pickerRow("菜单栏 · 显示样式") {
                    Picker("", selection: $style) {
                        ForEach(MenuBarDisplayStyle.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 240)
                    .disabled(metric == .iconOnly)
                    .opacity(metric == .iconOnly ? 0.45 : 1)
                    .onChange(of: style) { _, newValue in
                        UserDefaults.standard.set(newValue.rawValue, forKey: "menuBarDisplayStyle")
                    }
                }

                pickerRow("面板 · 用量展示") {
                    Picker("", selection: $panelStyle) {
                        ForEach(PanelHeroStyle.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 240)
                    .onChange(of: panelStyle) { _, newValue in
                        UserDefaults.standard.set(newValue.rawValue, forKey: "panelHeroStyle")
                    }
                }

                pickerRow("自动刷新间隔") {
                    Picker("", selection: $interval) {
                        Text("30 秒").tag(30.0)
                        Text("1 分钟").tag(60.0)
                        Text("2 分钟").tag(120.0)
                        Text("5 分钟").tag(300.0)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onChange(of: interval) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "refreshInterval")
                    }
                }
            }
            .frame(maxWidth: 430)
            .staggerAppear(1)
        }
    }

    private func pickerRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            content()
        }
    }
}

/// 菜单栏外观的模拟预览
private struct MenuBarPreview: View {
    var store: QuotaStore
    var metric: MenuBarMetric
    var style: MenuBarDisplayStyle

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: "applelogo")
                    Text("访达")
                }
                Spacer()
                HStack(spacing: 9) {
                    Text("周三 15:04")
                    Image(systemName: "wifi")
                    Image(systemName: "battery.75percent")
                    separator
                    previewLabel
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.black.opacity(0.88)))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: metric)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: style)

            Text("菜单栏实时预览")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(.white.opacity(0.25))
            .frame(width: 1, height: 14)
    }

    @ViewBuilder
    private var previewLabel: some View {
        switch metric {
        case .iconOnly:
            barsPreview
        case .creditsRemaining:
            switch style {
            case .textOnly:
                Text(store.creditsShortText)
            case .ringAndText:
                HStack(spacing: 4) {
                    barsPreview
                    Text(store.creditsShortText)
                }
            case .ringOnly:
                barsPreview
            }
        case .fiveHourRemaining:
            windowPreview(store.fiveHourRemainingFraction, store.fiveHourPercentText)
        case .weeklyRemaining:
            windowPreview(store.weeklyRemainingFraction, store.weeklyPercentText)
        }
    }

    @ViewBuilder
    private func windowPreview(_ remaining: Double, _ text: String) -> some View {
        switch style {
        case .textOnly:
            Text(text)
        case .ringAndText:
            HStack(spacing: 4) {
                ringPreview(remaining)
                Text(text)
            }
        case .ringOnly:
            ringPreview(remaining)
        }
    }

    private var barsPreview: some View {
        Image(systemName: "chart.bar.fill")
            .font(.system(size: 11))
    }

    private func ringPreview(_ remaining: Double) -> some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.35), lineWidth: 2)
            Circle()
                .trim(from: 0, to: max(0.02, min(remaining, 1)))
                .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 13, height: 13)
    }
}

// MARK: - 第 4 步：完成

private struct FinishStep: View {
    var store: QuotaStore

    var body: some View {
        VStack(spacing: 18) {
            AnimatedCheckmark(size: 72)
                .staggerAppear(0)

            Text("一切就绪！")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .staggerAppear(1)
            Text("CommandCodeBar 已开始在菜单栏为你值守")
                .font(.title3)
                .foregroundStyle(.secondary)
                .staggerAppear(2)

            if let snapshot = store.snapshot {
                VStack(spacing: 0) {
                    infoRow("账户", snapshot.accountName ?? "—")
                    Divider().opacity(0.5)
                    infoRow("套餐", store.planBadgeText ?? "—")
                    Divider().opacity(0.5)
                    infoRow("剩余额度", "$" + Fmt.credits(snapshot.creditsRemaining))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .frame(maxWidth: 340)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))
                .staggerAppear(3)
            }

            Text("提示：随时可在面板底部点「设置」重新运行此引导")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .staggerAppear(4)
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout.weight(.medium))
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 通用组件

private struct StepHeader: View {
    var icon: String?
    var showsLogo = false
    let title: String
    let subtitle: String

    init(icon: String, title: String, subtitle: String) {
        self.icon = icon
        self.showsLogo = false
        self.title = title
        self.subtitle = subtitle
    }

    init(showsLogo: Bool, title: String, subtitle: String) {
        self.icon = nil
        self.showsLogo = showsLogo
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if showsLogo {
                    Image("CommandCodeLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    Image(systemName: icon ?? "gearshape")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color(red: 0.55, green: 0.35, blue: 0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title2.weight(.bold))
                Text(subtitle).font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

private struct DotsIndicator: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: index == current ? 22 : 7, height: 7)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: current)
    }
}

/// 官方 Logo，带轻微呼吸缩放动画
private struct PulsingLogo: View {
    @State private var pulsing = false

    var body: some View {
        Image("CommandCodeLogo")
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            .scaleEffect(pulsing ? 1.045 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
    }
}

/// 打勾动画：圆环 + 对勾描边
private struct AnimatedCheckmark: View {
    var size: CGFloat = 52
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.green.opacity(0.25), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            CheckShape()
                .trim(from: 0, to: progress)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .padding(size * 0.24)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 0.55).delay(0.1)) {
                progress = 1
            }
        }
    }

    private struct CheckShape: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.05, y: rect.midY + rect.height * 0.05))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY - rect.height * 0.08))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.02, y: rect.minY + rect.height * 0.15))
            return path
        }
    }
}

/// 内容入场：淡入 + 上浮，按序号错峰
private struct StaggerAppear: ViewModifier {
    let index: Int
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(Double(index) * 0.08)) {
                    shown = true
                }
            }
    }
}

private extension View {
    func staggerAppear(_ index: Int) -> some View {
        modifier(StaggerAppear(index: index))
    }
}
