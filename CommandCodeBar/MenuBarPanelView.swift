import AppKit
import SwiftUI

/// 点击菜单栏图标展开的面板（MenuBarExtra .window 风格）
struct MenuBarPanelView: View {
    var store: QuotaStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let message = store.lastErrorMessage {
                errorBanner(message, suggestion: store.lastErrorSuggestion)
            }

            if let snapshot = store.snapshot {
                content(snapshot)
            } else if store.phase == .loading {
                HStack {
                    Spacer()
                    ProgressView().controlSize(.small)
                    Text("正在获取额度…").foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 36)
            } else {
                emptyState
            }

            Divider()
            footer
        }
        .padding(16)
        .frame(width: 340)
        .onAppear {
            Task { await store.refreshIfNeeded() }
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 8) {
            Image("CommandCodeLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text("Command Code")
                .font(.headline)
            if let plan = store.planBadgeText {
                Text(plan)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                    .foregroundStyle(Color.accentColor)
            }
            Spacer()
            if store.isRefreshing {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("立即刷新")
            }
        }
    }

    // MARK: - 主体内容

    private func content(_ snapshot: QuotaSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            hero
            // 单圆环模式主图只覆盖较紧窗口，下方保留两窗口明细；其余模式明细已并入主图，避免重复
            if store.panelHeroStyle == .singleRing {
                windowRow("5 小时窗口", window: store.fiveHourWindow)
                windowRow("每周窗口", window: store.weeklyWindow)
            }
            creditsCard(snapshot)
            usageCard(snapshot)
            Text("更新于 \(Fmt.clock(snapshot.fetchedAt)) · 每 \(Int(store.refreshInterval)) 秒自动刷新")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - 主图（双圆环 / 单圆环 / 双条形）

    @ViewBuilder
    private var hero: some View {
        switch store.panelHeroStyle {
        case .dualRings: dualRingsHero
        case .singleRing: singleRingHero
        case .dualBars: dualBarsHero
        }
    }

    /// 双圆环：5 小时与每周窗口并列展示（默认）
    private var dualRingsHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("窗口剩余")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 0) {
                heroRingUnit("5 小时窗口", window: store.fiveHourWindow)
                heroRingUnit("每周窗口", window: store.weeklyWindow)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
    }

    private func heroRingUnit(_ name: String, window: QuotaWindow?) -> some View {
        let remaining = window?.remainingFraction ?? 1
        return VStack(spacing: 8) {
            ZStack {
                RingGaugeView(remaining: remaining)
                    .frame(width: 72, height: 72)
                Text(Fmt.percent(remaining))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            VStack(spacing: 2) {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let window {
                    Text("已用 \(Fmt.compact(window.used)) / \(Fmt.compact(window.cap))")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                    if let reset = window.resetAt {
                        Text(Fmt.countdown(until: reset))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text("无数据")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 单圆环：较紧窗口的剩余比例
    private var singleRingHero: some View {
        let window = store.tighterWindow
        let remaining = window?.remainingFraction ?? 1
        let caption = window == nil
            ? "当前套餐未返回窗口限额"
            : (store.tighterWindowIsFiveHour ? "较紧：5 小时窗口" : "较紧：每周窗口")

        return VStack(spacing: 14) {
            ZStack {
                RingGaugeView(remaining: remaining)
                    .frame(width: 96, height: 96)
                VStack(spacing: 0) {
                    Text(Fmt.percent(remaining))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("剩余")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }

    /// 双条形：两个窗口的剩余条形量表
    private var dualBarsHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("窗口剩余")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            heroBarRow("5 小时窗口", window: store.fiveHourWindow)
            heroBarRow("每周窗口", window: store.weeklyWindow)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
    }

    private func heroBarRow(_ name: String, window: QuotaWindow?) -> some View {
        let remaining = window?.remainingFraction ?? 1
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.caption.weight(.medium))
                Spacer()
                Text(Fmt.percent(remaining))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(remainingColor(remaining))
                        .frame(width: geometry.size.width * remaining)
                }
            }
            .frame(height: 8)
            if let window {
                HStack {
                    Text("已用 \(Fmt.compact(window.used)) / \(Fmt.compact(window.cap))")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                    Spacer()
                    if let reset = window.resetAt {
                        Text(Fmt.countdown(until: reset))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func remainingColor(_ remaining: Double) -> Color {
        if remaining > 0.5 { return .green }
        if remaining > 0.2 { return .orange }
        return .red
    }

    private func windowRow(_ title: String, window: QuotaWindow?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.weight(.medium))
                Spacer()
                if let window {
                    Text("\(Fmt.compact(window.used)) / \(Fmt.compact(window.cap))")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else {
                    Text("无数据")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(usageColor(window?.usedFraction ?? 0))
                        .frame(width: geometry.size.width * (window?.usedFraction ?? 0))
                }
            }
            .frame(height: 6)
            if let reset = window?.resetAt {
                Text(Fmt.countdown(until: reset))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func creditsCard(_ snapshot: QuotaSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "creditcard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("剩余额度")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("$" + Fmt.credits(snapshot.creditsRemaining))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            HStack(spacing: 6) {
                chip("月度", value: snapshot.monthlyCreditsRemaining)
                chip("购买", value: snapshot.purchasedCreditsRemaining)
                chip("免费", value: snapshot.freeCreditsRemaining)
                Spacer()
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
    }

    private func chip(_ name: String, value: Double) -> some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(Fmt.credits(value))
                .font(.caption2.weight(.medium))
                .monospacedDigit()
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
    }

    private func usageCard(_ snapshot: QuotaSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("本期用量（当前账期）")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 0) {
                usageItem(value: snapshot.periodCostText ?? "--", title: "消耗额度")
                usageItem(value: snapshot.periodRequestsText ?? "--", title: "请求数")
                usageItem(value: snapshot.periodTokensText ?? "--", title: "总 Tokens")
            }
            if let start = snapshot.periodStart, let end = snapshot.periodEnd {
                Text("\(Fmt.date(start)) – \(Fmt.date(end))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
    }

    private func usageItem(value: String, title: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.callout.weight(.medium))
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 错误 / 空状态

    private func errorBanner(_ message: String, suggestion: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
            if let suggestion {
                Text(suggestion)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)
            Text("无法获取 Command Code 额度")
                .font(.callout.weight(.medium))
            Text("请先完成 Command Code CLI 登录（生成 ~/.commandcode/auth.json），或在设置中粘贴 API Key。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button("重试") {
                    Task { await store.refresh() }
                }
                Button("打开认证目录") {
                    let url = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent(".commandcode")
                    NSWorkspace.shared.open(url)
                }
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - 底部按钮

    private var footer: some View {
        HStack {
            Spacer()
            Button {
                openSettings()
            } label: {
                Label("设置", systemImage: "gearshape")
            }
            Button {
                NSApp.terminate(nil)
            } label: {
                Label("退出", systemImage: "power")
            }
        }
        .controlSize(.small)
        .buttonStyle(.borderless)
        .labelStyle(.titleAndIcon)
    }

    /// SettingsLink / showSettingsWindow: 在 MenuBarExtra 面板中不可靠，改用独立设置窗口
    private func openSettings() {
        SettingsWindowController.shared.show(store: store)
    }

    // MARK: - 颜色

    private func usageColor(_ usedFraction: Double) -> Color {
        if usedFraction >= 0.8 { return .red }
        if usedFraction >= 0.5 { return .orange }
        return .accentColor
    }
}
