# Changelog

## [1.3.5] - 2026-04-17

### Others

- Improve CI release workflow code signing configuration

## [1.3.4] - 2026-04-17

### Others

- Update standard Swift/Xcode gitignore rules and remove user-specific xcuserdata files from tracking

## [1.3.3] - 2026-04-17

### Others

- Remove macOS runner code signing configuration

## [1.3.2] - 2026-04-17

### Others

- Configure code signing settings

## [1.3.1] - 2026-04-17

### Others

- CI: Update Xcode to 26.4 and macOS runner to 26

## [1.3.0] - 2026-04-17

### Features

- Optimize update installation flow and window management

### Others

- CI: Use stable Xcode version (no product changes)

## [1.2.0] - 2026-04-16

### Features

- Add custom update popup with Markdown release notes support

### Bug Fixes

- Fix appcast.xml generation using GitHub Release assets

### Others

- Add Down package dependency for Markdown rendering
- Add app-release skill for standardized releases

## [1.1.4] - 2026-04-16

### Others

- Release workflow improvements (no product changes)

## [1.1.1] - 2026-04-16

### Others

- chore: add .claude directory
- chore: 调整布局间距和更新颜色名称
- refactor: 使用 NSCache 重构头像缓存
- chore: translate CHANGELOG to English

## [1.1.0] - 2026-04-16

### Features

- feat: extract release notes from CHANGELOG.md
- feat: add DMG packaging to release workflow
- feat(provider): add advanced model configuration

### Bug Fixes

- fix: serve appcast.xml from GitHub Release instead of repo
- fix: checkout main branch before pushing appcast update
- fix: correct bash variable substitution in release workflow

## [1.0.1] - 2026-04-16

### Features

- **Provider Management**: Multiple AI provider configuration and management
- **Advanced Model Configuration**: Custom model parameters and advanced settings
- **Theme System**: Customizable theme configuration
- **Status Bar Integration**: Convenient status bar menu and quick actions
- **Auto Update**: Sparkle-based automatic update functionality

### Tech Stack

- SwiftUI + AppKit Hybrid Architecture
- SQLite Local Storage
- Sparkle 2.x Auto Update Framework

### System Requirements

- macOS 13.0+
- Apple Silicon or Intel Mac
