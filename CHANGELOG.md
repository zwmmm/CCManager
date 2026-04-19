# Changelog

## [1.8.0] - 2026-04-19

### Features

- Add theme settings with customizable brand color (Chinese pigment palette) and system/light/dark theme mode
- Add CollapsibleGroup and ListReorderPreview for provider list drag & group functionality

### Others

- Add CLAUDE.md and DESIGN.md documentation for codebase guidance
- Update README with menu switch instructions

## [1.7.0] - 2026-04-18

### Features

- Add CCManagerCLI as a standalone CLI tool with shared Database layer
- Add CLI PATH installation feature in Settings UI
- Simplify CLI settings UI text
- Refactor CLI installation to download pre-built binaries from GitHub Releases

### Others

- Refactor color classification system for better maintainability
- Add CCManagerCLI build step in CI pipeline

## [1.6.0] - 2026-04-18

### Features

- Add status bar interaction, hover effects and auto-select provider for avatars

### Bug Fixes

- Adjust avatar size from 24/64 to 28/72

### Others

- Refactor avatar rendering to use DiceBear API instead of pixel generation

## [1.5.1] - 2026-04-18

### Others

- Restore app-release skill and GitHub Actions workflow for automated releases

## [1.5.0] - 2026-04-18

### Features

- Add macOS auto-start functionality

### Others

- Add research document for auto-start feature

## [1.4.1] - 2026-04-17

### Bug Fixes

- Use repository URL for sparkle:releaseNotesLink instead of release asset URL

### Others

- Add Sparkle key generation instructions to app-release skill

## [1.4.0] - 2026-04-17

### Features

- Improve Codex configuration writing to merge with existing config files
- Add ad-hoc re-signing script for embedded frameworks and binaries

### Others

- Remove GitHub Actions release workflow (replaced by local release process)
- Update app-release skill documentation

## [1.3.9] - 2026-04-17

### Others

- Update app-release skill to support local builds with DMG packaging
- Remove GitHub Actions release workflow (replaced by local release process)

## [1.3.8] - 2026-04-17

### Others

- Refactor Codex configuration to use separate auth.json and config.toml files
- Update CI Xcode version to 26.4

## [1.3.7] - 2026-04-17

### Others

- Add Xcode scheme configuration for proper platform resolution

## [1.3.6] - 2026-04-17

### Others

- Fix CI build by specifying macOS destination platform

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
