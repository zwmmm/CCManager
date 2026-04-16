# CCManager 自动更新功能技术研究

**日期**: 2026-04-16
**Spec**: [auto-update-design.md](../specs/2026-04-16-auto-update-design.md)
**技术栈**: Sparkle 2.6.0, GitHub Actions, XcodeGen, SwiftUI

---

## 目录

1. [Sparkle 2.x 集成指南](#1-sparkle-2x-集成指南)
2. [GitHub Actions 发布流程](#2-github-actions-发布流程)
3. [最佳实践总结](#3-最佳实践总结)
4. [常见问题与解决方案](#4-常见问题与解决方案)

---

## 1. Sparkle 2.x 集成指南

### 1.1 核心概念

**Sparkle 2.x 架构**:
- `SPUStandardUpdaterController` - 标准更新控制器，封装了更新逻辑和 UI
- `SPUUpdater` - 核心更新逻辑
- `SPUUserDriver` - UI 交互协议（自定义 UI 时使用）

**更新流程**:
```
应用启动 → SPUUpdater 初始化 → 定时检查（默认24小时）
    ↓
用户触发检查 → checkForUpdates()
    ↓
下载 appcast.xml → 解析版本信息 → 比较当前版本
    ↓
发现新版本 → 下载更新包 → 验证 EdDSA 签名
    ↓
用户确认 → 提取并安装 → 重启应用
```

### 1.2 SPM 集成

**project.yml 配置**:
```yaml
packages:
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle.git
    from: "2.6.0"

targets:
  CCManager:
    dependencies:
      - package: Sparkle
        product: Sparkle
```

### 1.3 Info.plist 配置

```xml
<!-- Sparkle 必需配置 -->
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/zwmmm/CCManager/main/docs/appcast.xml</string>

<key>SUPublicEDKey</key>
<string>YOUR_EDDSA_PUBLIC_KEY_BASE64</string>

<!-- 可选配置 -->
<key>SUEnableAutomaticChecks</key>
<true/>

<key>SUScheduledCheckInterval</key>
<integer>3600</integer> <!-- 1小时检查间隔 -->
```

### 1.4 EdDSA 密钥生成

```bash
# 下载 Sparkle 后执行
./bin/generate_keys

# 输出示例：
# A key has been generated and saved in your keychain.
# SUPublicEDKey: pfIShU4dEXqPd5ObYNfDBiQWcXozk7estwzTnF9BamQ=

# 导出私钥（用于 CI）
./bin/generate_keys -x sparkle_private_key.pem
```

### 1.5 SwiftUI 集成

**UpdateManager.swift**:
```swift
import Sparkle
import Combine

final class UpdateManager: NSObject, ObservableObject {
    static let shared = UpdateManager()

    private let updaterController: SPUStandardUpdaterController
    private var cancellables = Set<AnyCancellable>()

    @Published var canCheckForUpdates: Bool = false

    private override init() {
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()

        // KVO 绑定 canCheckForUpdates
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        updaterController.checkForUpdates(nil)
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}
```

### 1.6 appcast.xml 格式

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"
     xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>CCManager 更新</title>
        <link>https://github.com/zwmmm/CCManager</link>
        <language>zh-CN</language>

        <item>
            <title>版本 1.0.0</title>
            <pubDate>Thu, 16 Apr 2026 00:00:00 +0800</pubDate>
            <sparkle:version>1</sparkle:version>
            <sparkle:shortVersionString>1.0.0</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>13.0.0</sparkle:minimumSystemVersion>

            <description><![CDATA[
                <h2>更新内容</h2>
                <ul>
                    <li>首次发布</li>
                </ul>
            ]]></description>

            <enclosure
                url="https://github.com/zwmmm/CCManager/releases/download/v1.0.0/CCManager.zip"
                sparkle:edSignature="SIGNATURE_HERE"
                length="1623481"
                type="application/octet-stream"
            />
        </item>
    </channel>
</rss>
```

**关键字段说明**:
| 字段 | 说明 |
|------|------|
| `sparkle:version` | 内部版本号（CFBundleVersion），用于版本比较 |
| `sparkle:shortVersionString` | 显示版本号（CFBundleShortVersionString） |
| `sparkle:minimumSystemVersion` | 最低 macOS 版本，三段式格式 |
| `sparkle:edSignature` | EdDSA 签名，由 generate_appcast 自动生成 |

---

## 2. GitHub Actions 发布流程

### 2.1 macOS Runner 环境

**macos-latest (macOS 15)**:
- **默认 Xcode**: 16.4
- **可用 Xcode 版本**: 16.0 - 26.3
- **预装工具**: Homebrew 5.1.3, Git 2.53.0, GitHub CLI 2.89.0
- **包管理器**: CocoaPods 1.16.2, Carthage 0.40.0

### 2.2 完整发布工作流

**.github/workflows/release.yml**:
```yaml
name: Release

on:
  push:
    tags:
      - 'v*.*.*'

permissions:
  contents: write

jobs:
  build-and-release:
    runs-on: macos-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '16.0'

      - name: Install XcodeGen
        run: brew install xcodegen

      - name: Generate Xcode Project
        run: xcodegen generate

      - name: Build Release
        run: |
          xcodebuild -project CCManager.xcodeproj \
            -scheme CCManager \
            -configuration Release \
            -derivedDataPath build \
            CODE_SIGN_IDENTITY="-" \
            CODE_SIGN_STYLE=Manual

      - name: Package App
        run: |
          cd build/Build/Products/Release
          zip -r CCManager.zip CCManager.app

      - name: Download Sparkle Tools
        run: |
          SPARKLE_VERSION="2.6.0"
          curl -L -o sparkle.tar.xz \
            "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
          tar -xf sparkle.tar.xz

      - name: Generate Appcast
        env:
          SPARKLE_PRIVATE_KEY: ${{ secrets.SPARKLE_PRIVATE_KEY }}
        run: |
          # 从 stdin 读取私钥（安全）
          echo "$SPARKLE_PRIVATE_KEY" | ./bin/generate_appcast \
            --ed-key-file - \
            --download-url-prefix "https://github.com/zwmmm/CCManager/releases/download/${{ github.ref_name }}/" \
            -o docs/appcast.xml \
            build/Build/Products/Release/

      - name: Create Release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            build/Build/Products/Release/CCManager.zip
            docs/appcast.xml
          generate_release_notes: true

      - name: Update Appcast in Repo
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add docs/appcast.xml
          git commit -m "chore: update appcast.xml for ${{ github.ref_name }}"
          git push
```

### 2.3 Secrets 配置

**必需的 GitHub Secrets**:
| Secret 名称 | 说明 |
|-------------|------|
| `SPARKLE_PRIVATE_KEY` | EdDSA 私钥（从 generate_keys -x 导出） |

**设置步骤**:
```bash
# 1. 本地生成密钥
./bin/generate_keys

# 2. 导出私钥
./bin/generate_keys -x - | base64

# 3. 在 GitHub 仓库 Settings > Secrets 中添加
```

### 2.4 generate_appcast 命令详解

```bash
# 基本用法
./bin/generate_appcast /path/to/updates_folder/

# 完整参数
./bin/generate_appcast \
  --ed-key-file - \                      # 从 stdin 读取私钥
  --download-url-prefix "https://..." \  # 下载 URL 前缀
  --link "https://..." \                 # 应用主页
  --embed-release-notes \                # 嵌入更新说明
  --channel beta \                       # 指定渠道
  -o appcast.xml \                       # 输出文件
  ./releases/
```

**自动功能**:
- 自动生成 `.delta` 增量更新文件
- 自动查找同名的 `.html` 或 `.md` 文件作为更新说明
- 自动添加 EdDSA 签名

---

## 3. 最佳实践总结

### 3.1 Sparkle 集成

| 实践 | 原因 |
|------|------|
| 使用 `SPUStandardUpdaterController` | 标准场景下最简单，封装了 UI 和逻辑 |
| 通过 KVO 绑定 `canCheckForUpdates` | 属性变化时 UI 自动更新 |
| 私钥从 stdin 读取 | 避免写入文件系统，更安全 |
| appcast.xml 托管在 GitHub | 简化部署，自动更新 |

### 3.2 GitHub Actions

| 实践 | 原因 |
|------|------|
| 使用 `permissions: contents: write` | 最小权限原则 |
| 缓存 SPM 依赖 | 加速构建 |
| 使用 `softprops/action-gh-release@v2` | 功能完整，维护活跃 |
| tag 触发发布 | 版本控制清晰 |

### 3.3 版本管理

```
CFBundleVersion (sparkle:version):
  - 格式: 递增整数
  - 示例: 1, 2, 3
  - 用途: 版本比较

CFBundleShortVersionString (sparkle:shortVersionString):
  - 格式: 语义版本
  - 示例: 1.0.0, 1.1.0
  - 用途: 显示给用户
```

---

## 4. 常见问题与解决方案

### 4.1 Sparkle 问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 检查更新无响应 | HTTPS 问题或 URL 错误 | 验证 SUFeedURL 可访问性 |
| 签名验证失败 | EdDSA 签名无效 | 重新生成签名，确认私钥正确 |
| 找不到更新 | appcast.xml 格式错误 | 检查 XML 格式和版本号 |
| 沙盒应用更新失败 | 缺少 XPC 配置 | 添加 SUEnableInstallerLauncherService |

**调试命令**:
```bash
# 查看控制台日志
log stream --predicate 'subsystem == "org.sparkle-project.sparkle"' --level debug

# 验证签名
./bin/sign_update --verify path/to/update.zip
```

### 4.2 GitHub Actions 问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 构建失败 | Xcode 版本不匹配 | 使用 setup-xcode 指定版本 |
| 权限错误 | GITHUB_TOKEN 权限不足 | 添加 permissions 配置 |
| appcast 更新失败 | 无法推送到仓库 | 使用 PAT 或配置 workflow 权限 |

---

## 参考资源

- [Sparkle 官方文档](https://sparkle-project.org/documentation/)
- [Sparkle GitHub](https://github.com/sparkle-project/Sparkle)
- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
