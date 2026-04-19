# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

# Build And Test

```bash
# 修改 project.yml 后重新生成 Xcode 项目
xcodegen generate

# 构建 GUI 应用
xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Release build

# 构建 CLI 工具
xcodebuild -project CCManager.xcodeproj -scheme CCManagerCLI -configuration Release build
```

---

# Architecture Boundaries

```
┌─────────────────────────────────────────────────────────┐
│                        GUI App                          │
│  SwiftUI Views ← ProviderStore ← Database ← SQLite     │
│                    (ObservableObject)                   │
│                                                         │
│  StatusBarController ← LaunchAtLoginManager             │
│  ConfigWriter ← writes → ~/.claude/settings.json        │
│               ← writes → ~/.codex/config.toml           │
└─────────────────────────────────────────────────────────┘
                          ↑ shared
┌─────────────────────────────────────────────────────────┐
│                        CLI Tool                         │
│  CCManagerCLI/main.swift ← Database ← SQLite            │
│  ConfigWriter (reused)                                  │
└─────────────────────────────────────────────────────────┘

Shared Layer (Sources/Shared):
  - Database.swift      SQLite 封装，GUI 和 CLI 共用
  - ConfigWriter.swift  写入 Provider 配置到目标 CLI 配置文件
  - ProviderTester.swift API 连接测试

Manager 单例 (Sources/Managers/):
  - StatusBarController    菜单栏状态和右键菜单
  - LaunchAtLoginManager     SMAppService 开机自启
  - ThemeManager             主题配色管理
  - UpdateManager            Sparkle 自动更新
  - CLIInstallationManager   CCManagerCLI 安装/卸载
  - EditorManager            外部编辑器启动
```

---

# UI

@DESIGN.md

# NEVER

- 禁止修改 `project.yml` 以外的 Xcode 项目文件（`.xcodeproj` 由 xcodegen 生成）
- 禁止在 `AppDelegate` 以外的入口创建 NSApplication 实例
- 禁止在 Shared 层使用 AppKit/SwiftUI 相关 API
- 禁止跳过 `xcodegen generate` 直接提交修改后的 `project.pbxproj`

---

# ALWAYS

- 使用 `@EnvironmentObject` 注入 ProviderStore、ThemeManager 等共享状态
- Manager 类使用 `static let shared` 单例模式
- 数据库操作在 `dbQueue` 串行队列上执行
- 修改 `project.yml` 后立即执行 `xcodegen generate`
- 偏好值类型（struct），除非需要引用语义
- 配置文件写入使用 `atomic` 选项防止数据损坏

---

# Verification

- 构建成功：Xcode build 无 error
- 菜单栏图标正常显示，右键菜单可切换 Provider
- CLI 工具 `ccmanager` 命令可正常执行

---

# Compact Instructions

> 架构决策 > 修改文件 > 验证状态 > 待办事项

1. **架构决策**：任何新功能先确认放在 Shared 层还是 GUI 专属层；CLI 和 GUI 共用的逻辑必须放在 `Sources/Shared`
2. **修改文件**：优先修改 `Sources/Models` 和 `Sources/Shared`，UI 相关才动 `Sources/Views`
3. **验证状态**：构建验证优先于运行时测试
4. **待办事项**：使用 `// TODO:` 标记，避免引入新的技术债务
