import Foundation
import SwiftUI

/// 菜单栏显示的指标
enum MenuBarMetric: String, CaseIterable, Identifiable {
    case fiveHourRemaining
    case weeklyRemaining
    case creditsRemaining
    case iconOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fiveHourRemaining: return "5 小时窗口剩余"
        case .weeklyRemaining: return "每周窗口剩余"
        case .creditsRemaining: return "剩余额度"
        case .iconOnly: return "仅图标"
        }
    }
}

/// 菜单栏显示样式
enum MenuBarDisplayStyle: String, CaseIterable, Identifiable {
    case textOnly
    case ringAndText
    case ringOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .textOnly: return "只显示文字百分比"
        case .ringAndText: return "文字与圆环"
        case .ringOnly: return "只显示圆环"
        }
    }
}

/// 面板主图的展示方式
enum PanelHeroStyle: String, CaseIterable, Identifiable {
    case dualRings
    case singleRing
    case dualBars

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dualRings: return "双圆环"
        case .singleRing: return "单圆环"
        case .dualBars: return "双条形"
        }
    }
}

@MainActor
@Observable
final class QuotaStore {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    /// 全局唯一实例：面板、引导页、设置共享同一份状态
    static let shared = QuotaStore()

    private(set) var snapshot: QuotaSnapshot?
    private(set) var phase: Phase = .idle
    private(set) var isRefreshing = false
    private(set) var lastErrorMessage: String?
    private(set) var lastErrorSuggestion: String?
    private(set) var keySourceSummary: String?
    private(set) var menuBarMetric: MenuBarMetric = .fiveHourRemaining
    private(set) var menuBarDisplayStyle: MenuBarDisplayStyle = .ringAndText
    private(set) var panelHeroStyle: PanelHeroStyle = .dualRings
    private(set) var refreshInterval: TimeInterval = 60
    /// 常驻后台：开启时后台定时刷新；关闭时仅打开面板才刷新
    private(set) var stayInBackground = true

    private let service = QuotaService()
    private var refreshTimer: Timer?
    private let snapshotKey = "lastGoodSnapshot"

    init() {
        if let data = UserDefaults.standard.data(forKey: snapshotKey),
           let cached = try? JSONDecoder().decode(QuotaSnapshot.self, from: data) {
            snapshot = cached
            phase = .loaded
        }
        reloadSettings()
        observeDefaults()
        scheduleAutoRefresh()
        Task { await refresh() }
    }

    // MARK: - 设置

    private func observeDefaults() {
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reloadSettings()
            }
        }
    }

    private func reloadSettings() {
        let defaults = UserDefaults.standard
        menuBarMetric = MenuBarMetric(
            rawValue: defaults.string(forKey: "menuBarMetric") ?? ""
        ) ?? .fiveHourRemaining
        menuBarDisplayStyle = MenuBarDisplayStyle(
            rawValue: defaults.string(forKey: "menuBarDisplayStyle") ?? ""
        ) ?? .ringAndText
        panelHeroStyle = PanelHeroStyle(
            rawValue: defaults.string(forKey: "panelHeroStyle") ?? ""
        ) ?? .dualRings

        let stored = defaults.double(forKey: "refreshInterval")
        let interval = stored >= 30 ? stored : 60.0
        if interval != refreshInterval {
            refreshInterval = interval
            scheduleAutoRefresh()
        }

        let backgroundRefresh = defaults.object(forKey: "stayInBackground") as? Bool ?? true
        if backgroundRefresh != stayInBackground {
            stayInBackground = backgroundRefresh
            scheduleAutoRefresh()
        }
    }

    private func scheduleAutoRefresh() {
        refreshTimer?.invalidate()
        guard stayInBackground else { return }
        let interval = refreshInterval
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    // MARK: - 刷新

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        if snapshot == nil { phase = .loading }
        defer { isRefreshing = false }

        do {
            let result = try await service.fetchQuota()
            snapshot = result.snapshot
            keySourceSummary = result.source.summary
            phase = .loaded
            lastErrorMessage = nil
            lastErrorSuggestion = nil
            if let data = try? JSONEncoder().encode(result.snapshot) {
                UserDefaults.standard.set(data, forKey: snapshotKey)
            }
        } catch {
            let quotaError = error as? QuotaError
            lastErrorMessage = quotaError?.errorDescription ?? error.localizedDescription
            lastErrorSuggestion = quotaError?.recoverySuggestion
            keySourceSummary = service.resolveKey()?.source.summary ?? QuotaService.KeySource.none.summary
            // 已有旧快照时保持展示旧数据，仅提示错误；否则进入失败态
            phase = snapshot == nil ? .failed : .loaded
        }
    }

    /// 面板打开时调用：数据太旧才刷新，避免每次点开都等网络
    func refreshIfNeeded(maxAge: TimeInterval = 15) async {
        if let fetchedAt = snapshot?.fetchedAt, Date().timeIntervalSince(fetchedAt) < maxAge {
            return
        }
        await refresh()
    }

    // MARK: - 派生指标

    var fiveHourWindow: QuotaWindow? { snapshot?.fiveHour }
    var weeklyWindow: QuotaWindow? { snapshot?.weekly }

    /// 两个窗口里用得最多的那个（当前最紧的约束）
    var tighterWindow: QuotaWindow? {
        switch (fiveHourWindow, weeklyWindow) {
        case let (five?, week?):
            return five.usedFraction >= week.usedFraction ? five : week
        case let (five?, nil): return five
        case let (nil, week?): return week
        default: return nil
        }
    }

    var tighterWindowIsFiveHour: Bool {
        guard let fiveHourWindow else { return false }
        return tighterWindow == fiveHourWindow
    }

    var fiveHourRemainingFraction: Double { fiveHourWindow?.remainingFraction ?? 1 }
    var weeklyRemainingFraction: Double { weeklyWindow?.remainingFraction ?? 1 }

    var fiveHourPercentText: String { windowPercentText(fiveHourWindow) }
    var weeklyPercentText: String { windowPercentText(weeklyWindow) }

    private func windowPercentText(_ window: QuotaWindow?) -> String {
        guard let window else { return "--" }
        return Fmt.percent(window.remainingFraction)
    }

    var creditsShortText: String {
        guard let snapshot else { return "--" }
        return "$" + Fmt.compact(snapshot.creditsRemaining)
    }

    /// 套餐徽标："individual-goat" → "GOAT"
    var planBadgeText: String? {
        guard let planId = snapshot?.planId else { return nil }
        let lowered = planId.lowercased()
        if lowered.contains("pro") { return "PRO" }
        if lowered.contains("max") { return "MAX" }
        if lowered.contains("free") { return "FREE" }
        if lowered.contains("team") { return "TEAM" }
        return planId.components(separatedBy: "-").last?.uppercased()
    }
}
