# CCManager ✨

> macOS 菜单栏小工具，管理 AI CLI Provider 配置，一键切换超方便！

<img width="1702" height="1228" alt="image" src="https://github.com/user-attachments/assets/370eda37-0bff-46d8-95bb-346595eb58a5" />


---

## 🤔 为什么要做这个项目

之前用过 CC Switch 等类似工具，功能很全，但用下来有几个痛点：

- 每个供应商都有单独的配置窗口，配置合并逻辑复杂，经常出现**覆盖配置**的问题
- 软件本身越来越重，塞进了太多功能

CCManager 的核心理念很简单：

> **只改端点 URL、API Key 和自定义模型名称，其他配置一概不碰。**

如果确实需要修改其他配置，点击底部 ✏️ 按钮就能**一键打开配置文件**，用你喜欢的编辑器（VS Code、Xcode 等）直接改，体验更好。

另外新增了 CLI 模式，让 AI 在执行 bash 命令时自动切换供应商。至于 skills 管理这类需求，交给 `npx skills` 这种专业工具就好，**不要什么都做，专业的事交给专业的软件**。

---

## 😎 功能一览

### Provider 管理
支持 **Claude Code** 和 **Codex** 两大 CLI 工具

- 🟢 Claude Code：GLM、MiniMax、Kimi、Anthropic、OpenRouter 等
- 🔵 Codex：OpenAI、OpenRouter 等

每个 Provider 都能独立配置：
- 🔑 API Key
- 🌐 Base URL
- 🤖 主模型
- ⚡ 独立配置 Sonnet / Opus / Haiku / Thinking 模型

内置多个常用预设，开箱即用！

### ⚡ 一键切换

<img width="676" height="904" alt="image" src="https://github.com/user-attachments/assets/956d9829-cc80-4056-8499-3c60dc5751a9" />


右键点击菜单栏，展示切换面板 ✨

CCManager 自动将配置写入 `~/.claude/settings.json`（Claude Code）或 `~/.codex/config.toml`（Codex），**无需手动改文件**。

### 🧪 连接测试
添加或编辑 Provider 时，可实时测试 API 连接是否正常，避免配置错误白忙活~

### 🎨 主题定制
- 💡 跟随系统自动切换深色/浅色模式
- 🌈 500+ 种预设配色方案，随心切换
- 🍎 纯 SwiftUI 原生 UI，简洁又好看

### 🔄 自动更新
- ✅ 启动时自动检查更新，运行期间定时后台检查
- 🆕 发现新版本后展示自定义更新弹窗和 Markdown 更新内容
- 📦 点击安装后下载更新包、校验、替换应用并自动重启

### 📥 配置导入导出
- 💾 一键导出所有 Provider 配置为 JSON 文件
- 📤 从 JSON 文件导入 Provider 配置，方便迁移和备份

---

## ⚙️ Settings 功能

点击底部 ⚙️ 按钮打开设置面板：

### 🎭 外观
- **主题模式**：跟随系统 / 浅色 / 深色
- **主题配色**：500+ 种预设配色，按色彩风格分组（青、赤、黄、白等）

### 📝 编辑器
选择外部编辑器（VS Code、Xcode 等），用于直接打开 Provider 的配置文件。

### 💾 数据管理
- **Export**：将所有 Provider 配置导出为 JSON
- **Import**：从 JSON 文件导入 Provider 配置

### 🚀 开机自启
开启后，CCManager 将在每次登录时自动启动。

### 💻 CLI
安装或移除 CCManagerCLI 命令行工具，配合 Git hooks 可在 commit 时自动切换 Provider。

### ℹ️ 关于
- 查看当前版本号
- 手动检查更新（自动检查默认开启，发现新版本后弹窗提示）

---

## 🌟 为什么选择 CCManager

| 特性 | 说明 |
|------|------|
| 🪶 **轻量** | 菜单栏常驻，占用资源极少 |
| 🍎 **原生 UI** | 纯 SwiftUI 开发，视觉效果出色 |
| 🔒 **安全** | 配置本地 SQLite 存储，API Key 不外泄 |
| ⚡ **高效** | 无需编辑配置文件，一键切换立即生效 |

---

## 📦 系统需求

- macOS 13.0+

## 🔨 构建

```bash
xcodegen generate
xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Release build
```

或使用 Xcode 打开 `CCManager.xcodeproj` 直接运行。

## 📖 使用

1. �菜单栏启动后在看到 CCManager 图标
2. 👆 点击图标查看 Provider 列表
3. ✅ 选择 Provider 即切换为当前激活配置
4. ✏️ 右键或点击编辑按钮管理 Provider
