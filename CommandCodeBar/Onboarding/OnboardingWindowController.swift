import AppKit
import SwiftUI

/// 承载初始引导的浮动窗口（Mos 风格的分步向导）
@MainActor
final class OnboardingWindowController {
    static let shared = OnboardingWindowController()

    private var window: NSWindow?

    func show(store: QuotaStore) {
        if window == nil {
            let size = NSSize(width: 620, height: 480)
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "欢迎使用 CommandCodeBar"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            let hosting = NSHostingController(rootView: OnboardingFlowView(store: store))
            hosting.sizingOptions = [] // 关闭自适应，保持固定窗口尺寸
            window.contentViewController = hosting
            window.setContentSize(size)
            window.contentMinSize = size
            window.contentMaxSize = size
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// 关闭并丢弃窗口，下次打开时重置到第一步
    func close() {
        window?.orderOut(nil)
        window = nil
    }
}
