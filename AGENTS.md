# AGENTS.md — CommandCodeBar 开发指南

本文件面向在本仓库工作的 AI 编码代理（也对人类贡献者有用）。改动前请先读完"已知坑"一节。

## 项目概述

macOS 菜单栏应用，实时显示 Command Code CLI 的额度用量。

- UI：SwiftUI，`MenuBarExtra(.window)` 面板 + 独立 NSWindow（设置/引导）
- 目标：macOS 14+，Swift 5 语言模式，`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- 零第三方依赖；Bundle ID `com.functy.CommandCodeBar`；ad-hoc 签名
- 数据来源：`https://api.commandcode.ai` 的 4 个 alpha 接口（详见下文）

## 常用命令

```bash
# 构建（零警告是基线）
xcodebuild -project CommandCodeBar.xcodeproj -scheme CommandCodeBar \
  -configuration Debug -derivedDataPath build build

# 运行 / 重启
pkill -x CommandCodeBar; sleep 1
open build/Build/Products/Debug/CommandCodeBar.app
```

注意：本仓库**没有共享 scheme 文件**。Xcode 27 beta 解析手写 .xcscheme 会直接崩溃（SIGTRAP），构建依赖 xcodebuild 自动生成的 scheme。不要提交 .xcscheme。

## 架构与数据流

```
QuotaService（API 客户端 + Key 解析）
  → QuotaStore.shared（@MainActor @Observable 单例：自动刷新/快照缓存/派生指标）
    → MenuBarLabelView（菜单栏图标+文字）
    → MenuBarPanelView（面板：主图双圆环/双条形/单圆环 + 额度 + 用量）
    → SettingsView（设置窗口内容）
    → OnboardingFlowView（4 步引导：欢迎/连接/个性化/完成）
```

| 文件 | 职责 |
|---|---|
| QuotaModels.swift | API 响应 DTO（nonisolated）+ QuotaSnapshot 领域模型 |
| QuotaService.swift | Key 解析、4 接口并发抓取、错误类型 |
| QuotaStore.swift | 状态中心 + MenuBarMetric/DisplayStyle/PanelHeroStyle 设置模型 |
| MenuBarPanelView.swift | 面板 UI（主图、明细卡片、页脚） |
| SettingsView.swift | 设置表单（由 SettingsWindowController 承载） |
| Onboarding/* | 首启引导窗口与向导 |
| Support/StatusItemIcon.swift | 菜单栏 template 图标绘制与"图标+文字"合成 |
| Support/Fmt.swift | 数字/百分比/倒计时格式化 |

### UserDefaults 键

| 键 | 含义 | 默认 |
|---|---|---|
| menuBarMetric | 菜单栏指标（fiveHourRemaining/weeklyRemaining/creditsRemaining/iconOnly） | fiveHourRemaining |
| menuBarDisplayStyle | 菜单栏样式（textOnly/ringAndText/ringOnly） | ringAndText |
| panelHeroStyle | 面板主图（dualRings/singleRing/dualBars） | dualRings |
| refreshInterval | 自动刷新秒数（≥30） | 60 |
| customAPIKey | 手动指定的 API Key | 无 |
| lastGoodSnapshot | 上次成功快照（JSON，刷新失败兜底） | 无 |
| hasCompletedOnboarding | 引导是否完成 | false |

设置写入统一走 UserDefaults；QuotaStore 监听 `didChangeNotification` 后由 `reloadSettings()` 同步，不要绕过。

## 数据来源与认证

```
GET https://api.commandcode.ai/alpha/whoami
GET https://api.commandcode.ai/alpha/billing/credits?orgId=…
GET https://api.commandcode.ai/alpha/billing/subscriptions?orgId=…
GET https://api.commandcode.ai/alpha/usage/summary?orgId=…
Authorization: Bearer <apiKey>
```

Key 解析优先级：环境变量 `COMMAND_CODE_API_KEY` → 设置中手动 Key → 凭据文件
（`~/.commandcode/auth.json`，兼容 `~/.pi/agent/auth.json`、`~/.omp/agent/auth.json`；
JSON 形状：`{"apiKey":…}` / `{"command-code":{"key":…}}` / `{"commandcode":…}`）。
凭据文件在仓库外，切勿把真实 Key 写进任何提交。

## 已知坑（务必遵守）

1. **App Sandbox 必须保持关闭**（`ENABLE_APP_SANDBOX = NO`）——应用要读 `~/.commandcode/auth.json`。
2. **MenuBarExtra 里不要用 SettingsLink**，`NSApp.sendAction(showSettingsWindow:)` 同样不可靠；设置窗口必须用 `SettingsWindowController`（独立 NSWindow，已实测可用）。
3. **菜单栏"图标+文字"必须用 `StatusItemIcon` 的 combinedIcon 预合成单张 template 图**（Core Text 按字体 capHeight 计算基线）。`HStack{Image, Text}` 在 MenuBarExtra 中无法垂直对齐，这是 SwiftUI 缺陷，别改回去。
4. **AppIcon 用多尺寸 idiom=mac 格式**；`"platform": "macos"` 单尺寸 catalog 在本机 Xcode 27 beta 会产生构建告警。
5. QuotaModels 里的 API 响应结构体必须标 `nonisolated`（解码在并发上下文执行）；`async let` 读取要 `try await`。
6. 刷新失败时**不得清空旧快照**（TokenBar 行为：失败不空白，仅横幅提示）。
7. 面板主图（双圆环/双条形）模式下不要再渲染下方窗口明细行（单圆环模式除外），避免重复。

## 验证方式

- 编译零警告为基线；`grep -E "error:|warning:"` 过滤 `appintentsmetadataprocessor` 的无关提示。
- GUI 验证：本机未授予屏幕录制权限，用 System Events（AX 树读文本/控件）+ Swift CGEvent 脚本（真实鼠标事件）。
  - AX 坐标是全局点；AppleScript 把 `{x,y}` 转字符串会吞逗号，需手动拼 `item 1`/`item 2`。
  - 菜单栏状态项可能被刘海挤到左侧且位置会漂移，每次点击前重新读 `AXPosition`。
  - SwiftUI 面板的 AX 树偶发为空，重试 + delay 即可，不是 app 缺陷。

## 发布

当前 ad-hoc 签名仅本机可跑；对外分发需开发者证书签名 + 公证（Developer ID + notarization）。
