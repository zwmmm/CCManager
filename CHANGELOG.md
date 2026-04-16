# Changelog

## [1.1.0] - 2026-04-16

### 功能特性

- feat: extract release notes from CHANGELOG.md
- feat: add DMG packaging to release workflow
- feat(provider): 添加高级模型配置功能

### Bug 修复

- fix: serve appcast.xml from GitHub Release instead of repo
- fix: checkout main branch before pushing appcast update
- fix: correct bash variable substitution in release workflow

## [1.0.1] - 2026-04-16

### 功能特性

- **Provider 管理**: 支持多个 AI Provider 配置和管理
- **高级模型配置**: 自定义模型参数和高级设置
- **主题系统**: 可自定义的主题配置
- **状态栏集成**: 便捷的状态栏菜单和快捷操作
- **自动更新**: 基于 Sparkle 的自动更新功能

### 技术栈

- SwiftUI + AppKit 混合架构
- SQLite 本地存储
- Sparkle 2.x 自动更新框架

### 系统要求

- macOS 13.0+
- Apple Silicon 或 Intel Mac
