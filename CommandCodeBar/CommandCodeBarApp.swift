import AppKit
import SwiftUI

@main
struct CommandCodeBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = QuotaStore.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanelView(store: store)
        } label: {
            MenuBarLabelView(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

/// 首次启动弹出初始引导（完成后不再出现，可在设置里重新运行）
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            OnboardingWindowController.shared.show(store: QuotaStore.shared)
        }
    }
}

/// 菜单栏图标 + 可选文本（进度环随所选指标变化）
struct MenuBarLabelView: View {
    var store: QuotaStore

    var body: some View {
        switch store.menuBarMetric {
        case .iconOnly:
            Image(nsImage: StatusItemIcon.bars)
        case .creditsRemaining:
            creditsLabel
        case .fiveHourRemaining:
            windowLabel(
                remaining: store.fiveHourRemainingFraction,
                text: store.fiveHourPercentText
            )
        case .weeklyRemaining:
            windowLabel(
                remaining: store.weeklyRemainingFraction,
                text: store.weeklyPercentText
            )
        }
    }

    /// 额度没有窗口上限、画不了环：文字样式只显示文字，其余样式用柱状图标
    @ViewBuilder
    private var creditsLabel: some View {
        switch store.menuBarDisplayStyle {
        case .textOnly:
            Text(store.creditsShortText)
        case .ringAndText:
            Image(nsImage: StatusItemIcon.barsWithText(text: store.creditsShortText))
                .accessibilityLabel("剩余额度 \(store.creditsShortText)")
        case .ringOnly:
            Image(nsImage: StatusItemIcon.bars)
                .accessibilityLabel("剩余额度 \(store.creditsShortText)")
        }
    }

    @ViewBuilder
    private func windowLabel(remaining: Double, text: String) -> some View {
        switch store.menuBarDisplayStyle {
        case .textOnly:
            Text(text)
        case .ringAndText:
            Image(nsImage: StatusItemIcon.ringWithText(remaining: remaining, text: text))
                .accessibilityLabel(text)
        case .ringOnly:
            Image(nsImage: StatusItemIcon.ring(remaining: remaining))
                .accessibilityLabel(text)
        }
    }
}
