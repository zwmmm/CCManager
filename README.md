# CCManager

> macOS 菜单栏 Provider 管理工具，为 Claude Code 和 Codex 快速切换 API 配置。

[![Release](https://img.shields.io/github/v/release/zwmmm/CCManager?style=flat-square)](https://github.com/zwmmm/CCManager/releases)
[![macOS](https://img.shields.io/badge/macOS-13.0%2B-black?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift)](https://swift.org/)
[![Homebrew](https://img.shields.io/badge/Homebrew-cask-FBB040?style=flat-square&logo=homebrew&logoColor=000)](https://brew.sh/)
[![XcodeGen](https://img.shields.io/badge/project-XcodeGen-blue?style=flat-square)](https://github.com/yonaskolb/XcodeGen)

<img width="1702" height="1228" alt="CCManager 主界面" src="https://github.com/user-attachments/assets/370eda37-0bff-46d8-95bb-346595eb58a5" />

## 下载与安装

### Homebrew

```bash
brew install --cask zwmmm/tap/ccmanager
```

如果已经 tap 过仓库：

```bash
brew tap zwmmm/tap
brew install --cask ccmanager
```

升级或卸载：

```bash
brew upgrade --cask ccmanager
brew uninstall --cask ccmanager
```

### GitHub Releases

也可以从 [Releases](https://github.com/zwmmm/CCManager/releases) 下载最新版本。

> Homebrew 仅安装 GUI 应用 `CCManager.app`；CLI 命令 `ccmanager` 请在应用内的设置面板安装。

## 快速使用

1. 启动 CCManager，在菜单栏找到应用图标。
2. 添加 Claude Code 或 Codex Provider。
3. 右键菜单栏图标，选择要激活的 Provider。
4. CCManager 会写入对应配置文件：`~/.claude/settings.json` 或 `~/.codex/config.toml`。

<img width="676" height="904" alt="菜单栏 Provider 切换面板" src="https://github.com/user-attachments/assets/956d9829-cc80-4056-8499-3c60dc5751a9" />

## 核心功能

- **Provider 管理**：支持 Claude Code、Codex，以及 OpenAI、Anthropic、GLM、MiniMax、Kimi、OpenRouter 等常用预设。
- **一键切换**：只更新端点 URL、API Key 和模型配置，不覆盖其它手写配置。
- **连接测试**：添加或编辑 Provider 时可直接测试 API 是否可用。
- **配置编辑**：可用 VS Code、Xcode 等外部编辑器打开原始配置文件。
- **导入导出**：将 Provider 配置导出为 JSON，或从 JSON 恢复。
- **自动更新**：启动和运行期间自动检查新版本。

## 常用快捷键

| 快捷键 | 操作 |
|--------|------|
| `⌘T` | 新增 Provider |
| `⌘E` | 编辑当前选中的 Provider |
| `⌘↩` | 应用当前选中的 Provider 配置 |
| `⌘,` | 打开设置 |
| `⌘W` | 关闭窗口 |

## 设置

设置面板包含：

- 外观：深色/浅色/跟随系统，内置多套主题色。
- 编辑器：选择外部编辑器打开配置文件。
- 数据管理：导入、导出 Provider 配置。
- 开机自启：登录 macOS 后自动启动。
- CLI：安装或移除 `ccmanager` 命令行工具。
- 关于：查看版本并手动检查更新。

## 为什么做 CCManager

很多切换工具会接管整份配置文件，容易覆盖手动维护的字段。CCManager 的原则更保守：

> 只改 Provider 切换需要的字段，其它配置留给用户自己控制。

如果需要修改高级配置，直接用外部编辑器打开原始配置文件即可。

## 致谢

CCManager 的灵感来自 [cc-switch](https://github.com/farion1231/cc-switch)。这是一个功能完整的跨平台 AI CLI 管理工具，覆盖 Provider、MCP、Skills、Prompts 等多个方向。

本项目在设计思路和部分实现上参考、借鉴了 cc-switch，并在此基础上做了更聚焦的取舍：保留 Provider 切换和配置写入能力，做成一个轻量的 macOS 原生菜单栏工具。

## 系统需求

- macOS 13.0+

## 本地构建

```bash
xcodegen generate
xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Release build
```

也可以用 Xcode 打开 `CCManager.xcodeproj` 后直接运行。
