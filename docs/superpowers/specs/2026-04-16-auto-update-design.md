---
name: Auto Update Feature
description: 为 CCManager 添加基于 Sparkle 的自动更新功能
type: project
---

# CCManager 自动更新功能设计

## 概述

为 CCManager macOS 应用添加自动更新功能，使用 Sparkle 2.x 框架实现。支持定时自动检查、手动检查、标准更新弹窗，以及 GitHub Actions 自动化发布流程。

## 需求总结

- **更新源**：Sparkle 框架 + GitHub Releases
- **检查时机**：定时检查（间隔 1 小时）+ 手动检查按钮
- **弹窗样式**：Sparkle 标准弹窗
- **发布流程**：GitHub Actions 自动构建、打包、发布

## 架构

### 组件结构

```
Sources/
├── Managers/
│   └── UpdateManager.swift       # 更新管理器
├── Views/
│   └── ThemeSettingsView.swift   # 修改：添加版本和更新按钮
└── Resources/
    └── Info.plist                # 修改：添加 Sparkle 配置

.github/
└── workflows/
    └── release.yml               # 新增：自动发布流水线

docs/
└── appcast.xml                   # 新增：Sparkle 更新源
```

### 依赖

添加 Sparkle SPM 依赖：

```yaml
# project.yml
packages:
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle.git
    from: "2.6.0"
```

## 核心组件

### 1. UpdateManager

**职责**：封装 Sparkle 更新逻辑，提供 UI 绑定接口

```swift
import Sparkle

final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    @Published var canCheckForUpdates: Bool = false

    private let updaterController: SPUStandardUpdaterController

    private init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}
```

### 2. ThemeSettingsView 修改

在 "DATA MANAGEMENT" 区域下方添加 "ABOUT" 区域：

```
┌─────────────────────────────────────┐
│ ABOUT                               │
├─────────────────────────────────────┤
│  Version 1.0.0          [检查更新]  │
└─────────────────────────────────────┘
```

**UI 细节**：
- 版本显示：`Version {currentVersion}`，monospaced 字体
- 检查更新按钮：胶囊形状，品牌色背景，绑定 `canCheckForUpdates` 状态

### 3. Info.plist 配置

添加 Sparkle 所需键值：

| Key | Value |
|-----|-------|
| `SUFeedURL` | `https://raw.githubusercontent.com/<user>/CCManager/main/docs/appcast.xml` |
| `SUEnableAutomaticChecks` | `true` |
| `SUScheduledCheckInterval` | `3600` |

### 4. appcast.xml

放置在 `docs/appcast.xml`，Sparkle 更新源文件。由 GitHub Actions 自动更新。

## CI/CD 自动发布

### 触发条件

推送 tag（格式：`v*.*.*`，如 `v1.0.0`）

### 工作流步骤

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  build-and-release:
    runs-on: macos-latest
    steps:
      # 1. 检出代码
      - uses: actions/checkout@v4

      # 2. 安装 XcodeGen
      - name: Install XcodeGen
        run: brew install xcodegen

      # 3. 生成 Xcode 项目
      - name: Generate Xcode Project
        run: xcodegen generate

      # 4. 构建 Release
      - name: Build
        run: xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Release -derivedDataPath build

      # 5. 打包 .app
      - name: Package App
        run: |
          cd build/Build/Products/Release
          zip -r CCManager.zip CCManager.app

      # 6. 生成 appcast.xml
      - name: Generate Appcast
        run: |
          # 下载 Sparkle 工具或使用已安装的
          # 生成 appcast 条目
          # 更新 docs/appcast.xml

      # 7. 创建 GitHub Release
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: build/Build/Products/Release/CCManager.zip
          generate_release_notes: true

      # 8. 提交更新的 appcast.xml
      - name: Update Appcast
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add docs/appcast.xml
          git commit -m "chore: update appcast.xml for ${{ github.ref_name }}"
          git push
```

### Secrets 配置

- `SPARKLE_PRIVATE_KEY`（可选）：用于签名更新包

## 发布流程

1. 更新 `project.yml` 中的 `MARKETING_VERSION`
2. 提交代码并推送
3. 创建 tag：`git tag v1.0.0 && git push --tags`
4. GitHub Actions 自动执行构建、打包、发布
5. `appcast.xml` 自动更新并提交到仓库

## 文件清单

| 文件 | 操作 |
|------|------|
| `project.yml` | 修改：添加 Sparkle 依赖 |
| `Sources/Managers/UpdateManager.swift` | 新增 |
| `Sources/Views/ThemeSettingsView.swift` | 修改：添加版本和更新按钮 |
| `Resources/Info.plist` | 修改：添加 Sparkle 配置 |
| `.github/workflows/release.yml` | 新增 |
| `docs/appcast.xml` | 新增 |

## 注意事项

- `SUFeedURL` 需要在实现时替换为实际的 GitHub 仓库地址
- Sparkle 签名是可选的，但推荐用于生产环境
- 首次发布需要手动创建 `appcast.xml` 模板
