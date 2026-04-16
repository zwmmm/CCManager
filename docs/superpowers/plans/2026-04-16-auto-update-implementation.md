# CCManager 自动更新功能实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 CCManager macOS 应用添加基于 Sparkle 2.x 的自动更新功能，支持定时检查、手动检查和 GitHub Actions 自动化发布。

**Architecture:** 使用 `SPUStandardUpdaterController` 封装 Sparkle 更新逻辑，通过 `ObservableObject` 模式与 SwiftUI 集成。appcast.xml 托管在 GitHub 仓库，由 CI 自动生成和更新。

**Tech Stack:** Sparkle 2.6.0, SwiftUI, Combine, GitHub Actions, XcodeGen

---

## 文件结构

| 文件 | 操作 | 职责 |
|------|------|------|
| `project.yml` | 修改 | 添加 Sparkle SPM 依赖 |
| `Sources/Managers/UpdateManager.swift` | 新建 | 封装 Sparkle 更新逻辑，ObservableObject |
| `Resources/Info.plist` | 修改 | 添加 SUFeedURL、SUPublicEDKey 配置 |
| `Sources/Views/ThemeSettingsView.swift` | 修改 | 添加 ABOUT 区域（版本 + 检查更新按钮） |
| `Sources/App/AppDelegate.swift` | 修改 | 注册 UpdateManager 为 EnvironmentObject |
| `.github/workflows/release.yml` | 新建 | 自动构建、打包、发布工作流 |
| `docs/appcast.xml` | 新建 | Sparkle 更新源文件（初始模板） |

---

## Task 1: 添加 Sparkle 依赖

**Files:**
- Modify: `project.yml`

- [ ] **Step 1: 修改 project.yml 添加 Sparkle 包依赖**

在 `packages` 部分添加 Sparkle，在 `dependencies` 部分添加依赖引用：

```yaml
name: CCManager
options:
  bundleIdPrefix: com.ccmanager
  deploymentTarget:
    macOS: "13.0"
  xcodeVersion: "15.0"
  generateEmptyDirectories: true

settings:
  base:
    PRODUCT_NAME: CCManager
    MARKETING_VERSION: "1.0.0"
    CURRENT_PROJECT_VERSION: "1"
    SWIFT_VERSION: "5.9"
    MACOSX_DEPLOYMENT_TARGET: "13.0"
    CODE_SIGN_IDENTITY: "-"
    CODE_SIGN_STYLE: Manual
    ENABLE_HARDENED_RUNTIME: YES

packages:
  SQLite:
    url: https://github.com/stephencelis/SQLite.swift.git
    from: "0.15.0"
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle.git
    from: "2.6.0"

targets:
  CCManager:
    type: application
    platform: macOS
    sources:
      - Sources
      - path: Resources/MingcuteClaudeFill.png
        buildPhase: resources
      - Resources/Assets.xcassets
    resources:
      - Resources/Info.plist
      - Resources/CCManager.entitlements
    settings:
      base:
        INFOPLIST_FILE: Resources/Info.plist
        CODE_SIGN_ENTITLEMENTS: Resources/CCManager.entitlements
        LD_RUNPATH_SEARCH_PATHS: "@executable_path/../Frameworks"
        COMBINE_HIDPI_IMAGES: YES
    dependencies:
      - package: SQLite
        product: SQLite
      - package: Sparkle
        product: Sparkle
```

- [ ] **Step 2: 重新生成 Xcode 项目**

Run: `cd /Users/sanyi/ensoai/repos/github/zwmmm/CCManager && xcodegen generate`

Expected: 项目生成成功，无错误

- [ ] **Step 3: 验证 Sparkle 包已添加**

Run: `cd /Users/sanyi/ensoai/repos/github/zwmmm/CCManager && xcodebuild -project CCManager.xcodeproj -showBuildSettings | grep -i sparkle`

Expected: 输出包含 Sparkle 相关路径

- [ ] **Step 4: 提交**

```bash
git add project.yml CCManager.xcodeproj
git commit -m "feat: add Sparkle 2.6.0 SPM dependency for auto-update"
```

---

## Task 2: 创建 UpdateManager

**Files:**
- Create: `Sources/Managers/UpdateManager.swift`

- [ ] **Step 1: 创建 UpdateManager.swift 文件**

```swift
import Foundation
import Sparkle
import Combine

/// 管理应用自动更新的单例类
/// 封装 Sparkle 的 SPUStandardUpdaterController，提供 SwiftUI 友好的接口
final class UpdateManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = UpdateManager()
    
    // MARK: - Published Properties
    
    /// 是否可以检查更新（用于 UI 按钮状态绑定）
    @Published var canCheckForUpdates: Bool = false
    
    /// 最后一次检查更新的时间
    @Published var lastUpdateCheckDate: Date?
    
    // MARK: - Private Properties
    
    private let updaterController: SPUStandardUpdaterController
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// 当前应用版本号
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    /// 当前构建号
    var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
    
    /// 是否启用自动检查
    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }
    
    /// 自动检查间隔（秒）
    var updateCheckInterval: TimeInterval {
        get { updaterController.updater.updateCheckInterval }
        set { updaterController.updater.updateCheckInterval = newValue }
    }
    
    // MARK: - Initialization
    
    private override init() {
        // 初始化 Sparkle 更新控制器
        // startingUpdater: true 表示立即启动更新器
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        super.init()
        
        setupBindings()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // 使用 KVO 绑定 canCheckForUpdates 属性
        // Sparkle 的 canCheckForUpdates 是 KVO 兼容的
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)
        
        // 绑定最后检查时间
        updaterController.updater.publisher(for: \.lastUpdateCheckDate)
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastUpdateCheckDate)
    }
    
    // MARK: - Public Methods
    
    /// 用户手动检查更新
    /// 会显示 Sparkle 标准更新对话框
    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        updaterController.checkForUpdates(nil)
    }
    
    /// 后台静默检查更新
    /// 不会显示 UI，只在发现新版本时通知用户
    func checkForUpdatesInBackground() {
        updaterController.updater.checkForUpdatesInBackground()
    }
    
    /// 重置更新周期
    /// 在更改 feed URL 或渠道后调用
    func resetUpdateCycle() {
        updaterController.updater.resetUpdateCycle()
    }
}
```

- [ ] **Step 2: 验证文件创建成功**

Run: `ls -la /Users/sanyi/ensoai/repos/github/zwmmm/CCManager/Sources/Managers/UpdateManager.swift`

Expected: 文件存在

- [ ] **Step 3: 提交**

```bash
git add Sources/Managers/UpdateManager.swift
git commit -m "feat: add UpdateManager for Sparkle integration"
```

---

## Task 3: 配置 Info.plist

**Files:**
- Modify: `Resources/Info.plist`

- [ ] **Step 1: 添加 Sparkle 配置到 Info.plist**

在 `</dict>` 之前添加 Sparkle 配置：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$(MARKETING_VERSION)</string>
    <key>CFBundleVersion</key>
    <string>$(CURRENT_PROJECT_VERSION)</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2024. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    
    <!-- Sparkle Configuration -->
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/zwmmm/CCManager/main/docs/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>PLACEHOLDER_EDDSA_PUBLIC_KEY</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUScheduledCheckInterval</key>
    <integer>3600</integer>
</dict>
</plist>
```

**注意**: `SUPublicEDKey` 的值需要在生成 EdDSA 密钥后替换。

- [ ] **Step 2: 验证 XML 格式正确**

Run: `plutil -lint /Users/sanyi/ensoai/repos/github/zwmmm/CCManager/Resources/Info.plist`

Expected: `Resources/Info.plist: OK`

- [ ] **Step 3: 提交**

```bash
git add Resources/Info.plist
git commit -m "feat: add Sparkle configuration to Info.plist"
```

---

## Task 4: 修改 ThemeSettingsView 添加 ABOUT 区域

**Files:**
- Modify: `Sources/Views/ThemeSettingsView.swift`

- [ ] **Step 1: 在 ThemeSettingsView 中添加 ABOUT 区域**

在 `dataManagementSection` 之后、`Spacer()` 之前添加 ABOUT 区域。找到第 126 行 `dataManagementSection` 后面，添加以下代码：

```swift
                    Divider()
                        .padding(.horizontal, 18)

                    // About
                    sectionHeader("ABOUT")

                    aboutSection
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
```

然后在 `dataManagementSection` 计算属性后面（约第 297 行）添加 `aboutSection` 计算属性：

```swift
    private var aboutSection: some View {
        HStack(spacing: 0) {
            // Version info
            VStack(alignment: .leading, spacing: 2) {
                Text("Version")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(updateManager.currentVersion)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
            }
            
            Spacer()
            
            // Check for updates button
            Button {
                updateManager.checkForUpdates()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10, weight: .medium))
                    Text("Check for Updates")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(themeManager.brandColor.opacity(0.15))
                .clipShape(Capsule())
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!updateManager.canCheckForUpdates)
            .opacity(updateManager.canCheckForUpdates ? 1.0 : 0.5)
        }
    }
```

- [ ] **Step 2: 添加 UpdateManager 环境对象**

在 `ThemeSettingsView` 结构体顶部，添加 `updateManager` 属性：

```swift
struct ThemeSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var editorManager: EditorManager
    @EnvironmentObject var providerStore: ProviderStore
    @EnvironmentObject var updateManager: UpdateManager
    @Environment(\.dismiss) private var dismiss
```

- [ ] **Step 3: 验证编译通过**

Run: `cd /Users/sanyi/ensoai/repos/github/zwmmm/CCManager && xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Debug build 2>&1 | tail -20`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 提交**

```bash
git add Sources/Views/ThemeSettingsView.swift
git commit -m "feat: add ABOUT section with version and update button"
```

---

## Task 5: 注册 UpdateManager 到 AppDelegate

**Files:**
- Modify: `Sources/App/AppDelegate.swift`

- [ ] **Step 1: 在 AppDelegate 中添加 UpdateManager 环境对象**

在 `applicationDidFinishLaunching` 方法中，找到 `contentView` 的创建位置（约第 24 行），添加 `updateManager` 环境对象：

```swift
import AppKit
import SwiftUI

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let restoreMainWindow = Notification.Name("restoreMainWindow")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var window: NSWindow?
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        statusBarController = StatusBarController()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRestoreMainWindow),
            name: .restoreMainWindow,
            object: nil
        )

        let contentView = ContentView()
            .environmentObject(ProviderStore.shared)
            .environmentObject(ThemeManager.shared)
            .environmentObject(EditorManager.shared)
            .environmentObject(UpdateManager.shared)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window?.isReleasedWhenClosed = false
        window?.center()
        window?.setFrameAutosaveName("CCManagerMainWindow")
        window?.contentView = NSHostingView(rootView: contentView)
        window?.title = "CC Manager"
        window?.titlebarAppearsTransparent = false
        window?.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
    }

    // ... rest of the file unchanged
}
```

- [ ] **Step 2: 验证编译通过**

Run: `cd /Users/sanyi/ensoai/repos/github/zwmmm/CCManager && xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Debug build 2>&1 | tail -20`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 提交**

```bash
git add Sources/App/AppDelegate.swift
git commit -m "feat: register UpdateManager as environment object in AppDelegate"
```

---

## Task 6: 创建 GitHub Actions 发布工作流

**Files:**
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: 创建 .github/workflows 目录**

Run: `mkdir -p /Users/sanyi/ensoai/repos/github/zwmmm/CCManager/.github/workflows`

- [ ] **Step 2: 创建 release.yml 文件**

```yaml
name: Build and Release

on:
  push:
    tags:
      - 'v*.*.*'

permissions:
  contents: write

env:
  XCODE_VERSION: '16.0'
  SCHEME: 'CCManager'
  PROJECT: 'CCManager.xcodeproj'

jobs:
  build-and-release:
    runs-on: macos-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: ${{ env.XCODE_VERSION }}

      - name: Install XcodeGen
        run: brew install xcodegen

      - name: Generate Xcode Project
        run: xcodegen generate

      - name: Build Release
        run: |
          xcodebuild \
            -project ${{ env.PROJECT }} \
            -scheme ${{ env.SCHEME }} \
            -configuration Release \
            -derivedDataPath build \
            CODE_SIGN_IDENTITY="-" \
            CODE_SIGN_STYLE=Manual \
            | xcpretty && exit ${PIPESTATUS[0]}

      - name: Package App
        run: |
          cd build/Build/Products/Release
          zip -r CCManager-${{ github.ref_name }}.zip CCManager.app

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
          if [ -n "$SPARKLE_PRIVATE_KEY" ]; then
            echo "$SPARKLE_PRIVATE_KEY" | ./bin/generate_appcast \
              --ed-key-file - \
              --download-url-prefix "https://github.com/zwmmm/CCManager/releases/download/${{ github.ref_name }}/" \
              -o docs/appcast.xml \
              build/Build/Products/Release/
          else
            echo "Warning: SPARKLE_PRIVATE_KEY not set, skipping appcast generation"
          fi

      - name: Create Release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            build/Build/Products/Release/CCManager-${{ github.ref_name }}.zip
            docs/appcast.xml
          generate_release_notes: true
          draft: false
          prerelease: ${{ contains(github.ref_name, '-') }}

      - name: Update Appcast in Repo
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add docs/appcast.xml
          git commit -m "chore: update appcast.xml for ${{ github.ref_name }}" || echo "No changes"
          git push
```

- [ ] **Step 3: 验证 YAML 格式正确**

Run: `python3 -c "import yaml; yaml.safe_load(open('/Users/sanyi/ensoai/repos/github/zwmmm/CCManager/.github/workflows/release.yml'))"`

Expected: 无输出表示格式正确

- [ ] **Step 4: 提交**

```bash
git add .github/workflows/release.yml
git commit -m "feat: add GitHub Actions release workflow with Sparkle integration"
```

---

## Task 7: 创建初始 appcast.xml 模板

**Files:**
- Create: `docs/appcast.xml`

- [ ] **Step 1: 创建 docs 目录（如果不存在）**

Run: `mkdir -p /Users/sanyi/ensoai/repos/github/zwmmm/CCManager/docs`

- [ ] **Step 2: 创建 appcast.xml 模板文件**

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"
     xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>CCManager Updates</title>
        <link>https://github.com/zwmmm/CCManager</link>
        <language>en</language>
        
        <!-- Initial release will be added by GitHub Actions -->
    </channel>
</rss>
```

- [ ] **Step 3: 验证 XML 格式正确**

Run: `xmllint --noout /Users/sanyi/ensoai/repos/github/zwmmm/CCManager/docs/appcast.xml`

Expected: 无输出表示格式正确

- [ ] **Step 4: 提交**

```bash
git add docs/appcast.xml
git commit -m "feat: add initial appcast.xml template for Sparkle updates"
```

---

## Task 8: 生成 EdDSA 密钥并配置

**Files:**
- Modify: `Resources/Info.plist`（更新公钥）

- [ ] **Step 1: 下载 Sparkle 发行版**

Run: `curl -L -o /tmp/sparkle.tar.xz "https://github.com/sparkle-project/Sparkle/releases/download/2.6.0/Sparkle-2.6.0.tar.xz" && tar -xf /tmp/sparkle.tar.xz -C /tmp/`

Expected: Sparkle 工具解压到 `/tmp/bin/`

- [ ] **Step 2: 生成 EdDSA 密钥对**

Run: `/tmp/bin/generate_keys`

Expected: 输出类似：
```
A key has been generated and saved in your keychain.
Add the `SUPublicEDKey` key to the Info.plist...
SUPublicEDKey: pfIShU4dEXqPd5ObYNfDBiQWcXozk7estwzTnF9BamQ=
```

- [ ] **Step 3: 记录公钥**

将输出的 `SUPublicEDKey` 值记录下来，例如：`pfIShU4dEXqPd5ObYNfDBiQWcXozk7estwzTnF9BamQ=`

- [ ] **Step 4: 更新 Info.plist 中的公钥**

将 `Resources/Info.plist` 中的 `PLACEHOLDER_EDDSA_PUBLIC_KEY` 替换为实际的公钥值。

- [ ] **Step 5: 导出私钥（用于 GitHub Secrets）**

Run: `/tmp/bin/generate_keys -x - | base64 > /tmp/sparkle_private_key.txt`

Expected: 私钥保存到 `/tmp/sparkle_private_key.txt`

- [ ] **Step 6: 提交公钥更新**

```bash
git add Resources/Info.plist
git commit -m "feat: add EdDSA public key for Sparkle updates"
```

- [ ] **Step 7: 配置 GitHub Secret**

在 GitHub 仓库 Settings > Secrets and variables > Actions 中添加：
- Name: `SPARKLE_PRIVATE_KEY`
- Value: `/tmp/sparkle_private_key.txt` 文件内容

**注意**: 私钥不应提交到仓库，只存储在 GitHub Secrets 中。

---

## Task 9: 最终验证和测试

**Files:**
- 无新文件

- [ ] **Step 1: 完整构建测试**

Run: `cd /Users/sanyi/ensoai/repos/github/zwmmm/CCManager && xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Release build 2>&1 | tail -30`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: 验证 Sparkle 集成**

Run: `cd /Users/sanyi/ensoai/repos/github/zwmmm/CCManager && xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Debug build 2>&1 | grep -i sparkle`

Expected: 输出包含 Sparkle 框架路径

- [ ] **Step 3: 运行应用测试更新功能**

Run: `open /Users/sanyi/ensoai/repos/github/zwmmm/CCManager/build/Build/Products/Debug/CCManager.app`

Expected: 应用启动，设置界面显示版本号和"Check for Updates"按钮

- [ ] **Step 4: 提交所有更改**

```bash
git status
git add -A
git commit -m "feat: complete Sparkle auto-update integration"
```

---

## 发布流程说明

完成以上任务后，发布新版本的流程：

1. **更新版本号**：
   - 修改 `project.yml` 中的 `MARKETING_VERSION`
   - 修改 `project.yml` 中的 `CURRENT_PROJECT_VERSION`

2. **提交并打标签**：
   ```bash
   git add project.yml
   git commit -m "chore: bump version to x.y.z"
   git tag vx.y.z
   git push && git push --tags
   ```

3. **自动发布**：
   - GitHub Actions 自动触发
   - 构建应用并打包
   - 生成 appcast.xml
   - 创建 GitHub Release
   - 更新仓库中的 appcast.xml

---

## 检查清单

- [ ] Sparkle 依赖已添加到 project.yml
- [ ] UpdateManager.swift 已创建
- [ ] Info.plist 包含 SUFeedURL 和 SUPublicEDKey
- [ ] ThemeSettingsView 显示版本和更新按钮
- [ ] UpdateManager 已注册为环境对象
- [ ] GitHub Actions 工作流已创建
- [ ] appcast.xml 模板已创建
- [ ] EdDSA 密钥已生成并配置
- [ ] 构建测试通过
