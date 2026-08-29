# CommandCodeBar

一款仅限 macOS 的菜单栏（Menu Bar）应用，实时显示 [Command Code](https://commandcode.ai) CLI 的额度用量。UI 风格参考 [TokenBar](https://github.com/Nanako0129/TokenBar)，但只支持 Command Code。

技术栈：**SwiftUI**（`MenuBarExtra` window 风格）+ `@Observable`，目标 macOS 14+，Apple Silicon / Intel 通用，无第三方依赖。

## 功能

- **菜单栏状态项**，两处可调：
  - **显示指标**：5 小时窗口剩余 / 每周窗口剩余 / 剩余额度 / 仅图标
  - **显示样式**：只显示文字百分比 / 文字与圆环（默认）/ 只显示圆环
  - 剩余额度无窗口上限、画不了环，非文字样式下以柱状图标表示
- **点击展开面板**：
  - 套餐徽标（按 API 实际 planId 显示，如 GOAT / PRO / …）与顶部刷新按钮
  - 主图三种展示方式（设置中可选，默认双圆环）：
    - **双圆环**：5 小时与每周窗口并列，各显示剩余比例
    - **双条形**：两个窗口的条形量表
    - **单圆环**：仅较紧窗口的剩余比例
  - 两个窗口的明细：已用 / 上限、重置倒计时
  - 剩余额度卡片：总额 + 月度 / 购买 / 免费分项
  - 本期用量：消耗额度、请求数、总 Tokens、账期起止
- **初始引导**（仿 Mos 的分步向导，首次启动自动弹出，可在设置里重新运行）：
  1. 欢迎 —— 动画 Logo + 功能速览
  2. 连接 Command Code —— 自动检测凭据并拉取一次真实数据（失败可在页内粘贴 API Key 重试）
  3. 个性化显示 —— 菜单栏模拟预览 + 显示指标 / 显示样式 / 面板用量展示 / 刷新间隔（真实菜单栏同步变化）
  4. 完成 —— 摘要确认，"开始使用"收尾
  动画全部使用原生 SwiftUI API（TimelineView 起伏柱状 Logo、spring 分步转场、描边打勾、错峰入场、圆点指示器），零第三方依赖
- **失败不空白**：刷新失败时继续显示上一次成功的数据，并以横幅提示错误
- **自动刷新**：默认 60 秒，可调（30 秒 ~ 5 分钟）；打开面板时数据过旧会自动补一次
- **设置窗口**（面板底部"设置"按钮打开）：系统设置风格——左侧分类导航（菜单栏 / 面板 / API Key / 关于），右侧对应设置项；窗口可自由调整大小
- 无 Dock 图标（`LSUIElement`），本地运行、无遥测
- 面板头部与初始引导使用 **Command Code 官方 logo**（⌘ 符号标识，从本机安装的 Command Code.app 提取）

## 数据来源

读取 `~/.commandcode/auth.json` 中的 API Key（与 Command Code CLI 登录凭据相同），请求以下接口：

```
GET https://api.commandcode.ai/alpha/whoami
GET https://api.commandcode.ai/alpha/billing/credits?orgId=…
GET https://api.commandcode.ai/alpha/billing/subscriptions?orgId=…
GET https://api.commandcode.ai/alpha/usage/summary?orgId=…
```

认证头为 `Authorization: Bearer <apiKey>`。Key 的解析优先级：

1. 环境变量 `COMMAND_CODE_API_KEY`
2. 设置中手动指定的 Key（保存在本机偏好设置）
3. 凭据文件：`~/.commandcode/auth.json`（也兼容 `~/.pi/agent/auth.json`、`~/.omp/agent/auth.json`，支持 `{"apiKey": …}` / `{"command-code": {"key": …}}` / `{"commandcode": …}` 三种 JSON 形状）

## 构建与运行

用 Xcode 打开 `CommandCodeBar.xcodeproj`，直接 Run；或命令行：

```bash
xcodebuild -project CommandCodeBar.xcodeproj -scheme CommandCodeBar \
  -configuration Debug -derivedDataPath build build

open build/Build/Products/Debug/CommandCodeBar.app
```

签名采用 ad-hoc（`CODE_SIGN_IDENTITY = "-"`），本地直接可跑；如需分发请自行配置开发者签名与公证。

## 项目结构

```
CommandCodeBar/
├── CommandCodeBarApp.swift   # 入口：MenuBarExtra 场景 + 菜单栏图标/文本
├── QuotaModels.swift         # API 响应模型 + 领域快照（QuotaSnapshot）
├── QuotaService.swift        # API Key 解析 + 4 个额度接口客户端
├── QuotaStore.swift          # @Observable 状态中心：自动刷新、快照缓存、派生指标
├── MenuBarPanelView.swift    # 面板 UI（环形图、窗口明细、额度、用量）
├── RingGaugeView.swift       # 进度环组件
├── SettingsView.swift        # 设置窗口
├── Onboarding/
│   ├── OnboardingWindowController.swift  # 引导浮动窗口
│   └── OnboardingFlowView.swift          # 4 步引导向导（欢迎/连接/个性化/完成）
├── Support/
│   ├── Fmt.swift             # 数字 / 百分比 / 倒计时格式化
│   └── StatusItemIcon.swift  # 菜单栏 template 图标（柱状 / 进度环）绘制
└── Assets.xcassets           # AppIcon、AccentColor、CommandCodeLogo（官方 logo）
```

## 说明

- 额度单位与 Command Code 计费一致（1 credit ≈ $1），窗口的 used/cap 同单位
- 面板数据来自订阅账期（`usage/summary` 默认返回当前账期）
- "较紧窗口"指已用比例更高的那个用量窗口，菜单栏进度环与主进度环以它为主要参考
