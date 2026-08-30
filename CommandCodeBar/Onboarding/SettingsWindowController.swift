import AppKit
import SwiftUI

/// 设置窗口。不使用 SwiftUI Settings 场景：SettingsLink / showSettingsWindow:
/// 在 MenuBarExtra 面板场景下不可靠，独立 NSWindow 是已验证可用的方式。
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show(store: QuotaStore) {
        if window == nil {
            let size = NSSize(width: 460, height: 560)
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "CommandCodeBar 设置"
            window.isReleasedWhenClosed = false
            let hosting = NSHostingController(rootView: SettingsView(store: store))
            hosting.sizingOptions = []
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
}
