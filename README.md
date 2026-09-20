<div align="center">

# 📊 CommandCodeBar

**A macOS menu bar app showing your Command Code CLI quota in real time — 5-hour window, weekly window and remaining credits.**

[![CommandCodeBar](https://img.shields.io/badge/CommandCodeBar-CCB-orange.svg)](https://github.com/functy23/CommandCodeBar)
[![Swift](https://img.shields.io/badge/Swift-5.0%2B-red.svg?logo=swift&logoColor=white)](https://swift.org/)
[![Top Language](https://img.shields.io/github/languages/top/functy23/CommandCodeBar?style=flat)](https://github.com/functy23/CommandCodeBar)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey.svg?logo=apple&logoColor=white)](https://github.com/functy23/CommandCodeBar)

[![Release](https://img.shields.io/github/v/release/functy23/CommandCodeBar?style=flat&logo=github)](https://github.com/functy23/CommandCodeBar/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/functy23/CommandCodeBar/total?label=Downloads&logo=github)](https://github.com/functy23/CommandCodeBar/releases)
[![Stars](https://img.shields.io/github/stars/functy23/CommandCodeBar?style=flat&logo=github)](https://github.com/functy23/CommandCodeBar/stargazers)
[![Repo Size](https://img.shields.io/github/repo-size/functy23/CommandCodeBar?style=flat&logo=github)](https://github.com/functy23/CommandCodeBar)
[![Contributors](https://img.shields.io/github/contributors/functy23/CommandCodeBar?color=ee8449&logo=githubsponsors)](https://github.com/functy23/CommandCodeBar/graphs/contributors)

[Issues](https://github.com/functy23/CommandCodeBar/issues) • [AGENTS.md](AGENTS.md) • [Releases](https://github.com/functy23/CommandCodeBar/releases)

**English** | [简体中文](doc/README_zh-CN.md)
</div>

---

## Overview

A macOS-only menu bar app that shows the quota usage of the [Command Code](https://commandcode.ai) CLI in real time. The UI style is inspired by [TokenBar](https://github.com/Nanako0129/TokenBar), but only Command Code is supported.

Tech stack: **SwiftUI** (`MenuBarExtra` window style) + `@Observable`, targeting macOS 14+, universal Apple Silicon / Intel, with no third-party dependencies.

## Features

- **Menu bar status item**, adjustable in two places:
  - **Displayed metric**: 5-hour window remaining / weekly window remaining / remaining credits / icon only
  - **Display style**: text percentage only / text and ring (default) / ring only
  - Remaining credits have no window cap and cannot be drawn as a ring, so under non-text styles they are shown as a bar icon
- **Click to expand the panel**:
  - Plan badge (shown according to the actual `planId` returned by the API, such as GOAT / PRO / …) and a refresh button at the top
  - Three ways to display the main graphic (selectable in Settings, dual rings by default):
    - **Dual rings**: the 5-hour and weekly windows side by side, each showing its remaining ratio
    - **Dual bars**: a bar gauge for each of the two windows
    - **Single ring**: only the remaining ratio of the tighter window
  - Details for the two windows: used / cap, reset countdown
  - Remaining credits card: total plus monthly / purchased / free breakdown
  - Current period usage: consumed credits, request count, total Tokens, billing period start and end
- **Initial onboarding** (a step-by-step wizard modeled after Mos, shown automatically on first launch and re-runnable from Settings):
  1. Welcome — animated logo + feature overview
  2. Connect Command Code — automatically detects credentials and fetches real data once (on failure you can paste an API Key on the page and retry)
  3. Personalize display — menu bar simulation preview + displayed metric / display style / panel usage display / refresh interval (the real menu bar updates accordingly)
  4. Done — summary confirmation, finishing with "Get Started"
  All animations use native SwiftUI APIs (TimelineView undulating bar logo, spring step transitions, stroked checkmark, staggered entrance, dot indicators), with zero third-party dependencies
- **Never blank on failure**: when a refresh fails, the last successful data keeps being displayed, with a banner indicating the error
- **Automatic refresh**: 60 seconds by default, adjustable (30 seconds ~ 5 minutes); opening the panel fetches once more automatically if the data is too old
- **Settings window** (opened by the "Settings" button at the bottom of the panel): System Settings style — a category navigation on the left (Menu Bar / Panel / API Key / About) and the corresponding settings on the right; the window can be resized freely
- No Dock icon (`LSUIElement`), runs locally, no telemetry
- The panel header and the initial onboarding use the **official Command Code logo** (the ⌘ symbol mark, extracted from the locally installed Command Code.app)

## Data Sources

Reads the API Key from `~/.commandcode/auth.json` (the same login credentials as the Command Code CLI) and requests the following endpoints:

```
GET https://api.commandcode.ai/alpha/whoami
GET https://api.commandcode.ai/alpha/billing/credits?orgId=…
GET https://api.commandcode.ai/alpha/billing/subscriptions?orgId=…
GET https://api.commandcode.ai/alpha/usage/summary?orgId=…
```

The auth header is `Authorization: Bearer <apiKey>`. Key resolution priority:

1. Environment variable `COMMAND_CODE_API_KEY`
2. A Key specified manually in Settings (stored in local preferences)
3. Credentials file: `~/.commandcode/auth.json` (also compatible with `~/.pi/agent/auth.json` and `~/.omp/agent/auth.json`, supporting the three JSON shapes `{"apiKey": …}` / `{"command-code": {"key": …}}` / `{"commandcode": …}`)

## Build and Run

Open `CommandCodeBar.xcodeproj` in Xcode and just Run; or from the command line:

```bash
xcodebuild -project CommandCodeBar.xcodeproj -scheme CommandCodeBar \
  -configuration Debug -derivedDataPath build build

open build/Build/Products/Debug/CommandCodeBar.app
```

Signing is ad-hoc (`CODE_SIGN_IDENTITY = "-"`), so it runs directly locally; configure developer signing and notarization yourself if you need to distribute it.

## Project Structure

```
CommandCodeBar/
├── CommandCodeBarApp.swift   # Entry point: MenuBarExtra scene + menu bar icon/text
├── QuotaModels.swift         # API response models + domain snapshot (QuotaSnapshot)
├── QuotaService.swift        # API Key resolution + clients for the 4 quota endpoints
├── QuotaStore.swift          # @Observable state hub: auto refresh, snapshot cache, derived metrics
├── MenuBarPanelView.swift    # Panel UI (ring charts, window details, credits, usage)
├── RingGaugeView.swift       # Progress ring component
├── SettingsView.swift        # Settings window
├── Onboarding/
│   ├── OnboardingWindowController.swift  # Floating onboarding window
│   └── OnboardingFlowView.swift          # 4-step onboarding wizard (welcome/connect/personalize/done)
├── Support/
│   ├── Fmt.swift             # Number / percentage / countdown formatting
│   └── StatusItemIcon.swift  # Menu bar template icon (bar / progress ring) drawing
└── Assets.xcassets           # AppIcon, AccentColor, CommandCodeLogo (official logo)
```

## Notes

- Quota units match Command Code billing (1 credit ≈ $1), and the used/cap of a window use the same unit
- Panel data comes from the subscription billing period (`usage/summary` returns the current billing period by default)
- "Tighter window" means the usage window with the higher used ratio; the menu bar progress ring and the main progress ring take it as their primary reference
