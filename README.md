# CCManager

macOS 菜单栏应用，管理多个 AI CLI Provider 的配置，一键切换。

## 功能特性

- **Provider 管理**：支持 Claude Code 和 Codex，添加、编辑、删除 Provider 配置
- **一键切换**：从菜单栏快速切换当前激活的 Provider
- **深色/浅色主题**：支持跟随系统或手动选择，另有 12 种预设配色自定义主题
- **SQLite 存储**：本地安全存储 Provider 配置
- **Config 文件写入**：自动更新 Claude Code 等工具的配置文件

## 技术栈

- **SwiftUI** + **AppKit** (菜单栏集成)
- **SQLite.swift** 数据库
- **XcodeGen** 构建
- **SPM** 依赖管理

## 项目结构

```
CCManager/
├── Sources/
│   ├── App/           # AppDelegate, main.swift
│   ├── Models/        # Provider 数据模型
│   ├── Stores/        # ProviderStore (ObservableObject)
│   ├── Managers/      # ConfigWriter, EditorManager, ThemeManager
│   └── Views/         # SwiftUI 视图
├── Resources/
│   ├── Info.plist
│   ├── CCManager.entitlements
│   └── Assets.xcassets/
└── project.yml        # XcodeGen 配置
```

## 构建

```bash
# 生成 Xcode 项目
xcodegen generate

# 构建
xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Release build
```

或使用 Xcode 打开 `CCManager.xcodeproj` 直接运行。

## 使用

1. 启动后在菜单栏看到 CCManager 图标
2. 点击图标查看 Provider 列表
3. 选择 Provider 即切换为当前激活配置
4. 右键或点击编辑按钮管理 Provider

## 构建需求

- macOS 13.0+
- Xcode 15.0+
- XcodeGen