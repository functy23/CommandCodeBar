import Foundation
import ServiceManagement

/// 开机自启动 / 常驻后台共用的系统注册（macOS 13+ SMAppService）。
/// 注册后 app 出现在系统设置 → 通用 → 登录项与扩展 →「允许在后台」，可在系统中直接开关。
/// 两个开关共用这一条注册：任一开启即注册，全部关闭才注销。
@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 把注册状态同步到期望值（任一设置开关开启即视为需要注册）
    static func sync(enabled: Bool) throws {
        let status = SMAppService.mainApp.status
        let registered = status == .enabled || status == .requiresApproval
        if enabled && !registered {
            try SMAppService.mainApp.register()
            if SMAppService.mainApp.status == .requiresApproval {
                // 已注册但还没被批准，跳到系统设置对应页让用户放行
                SMAppService.openSystemSettingsLoginItems()
            }
        } else if !enabled && registered {
            try SMAppService.mainApp.unregister()
        }
    }
}
