# Codex OAuth Provider 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 为 CCManager 添加第三种 Provider 类型 Codex OAuth，支持通过 OAuth 登录 ChatGPT 账号（Plus/Pro），替代 API Key 认证。

**架构：** 新增 `codexOAuth` Provider 类型，OAuth Token 存储于 SQLite，仅在激活时写入 `~/.codex/auth.json` 和 `config.toml`。登录通过执行 `codex login --device-auth` 实现 Device Code 流程。

**技术栈：** Swift/SwiftUI, SQLite.swift, Foundation

---

## 文件变更总览

| 文件 | 操作 | 职责 |
|---|---|---|
| `Sources/Models/Provider.swift` | 修改 | 新增 `codexOAuth` 类型和 OAuth 字段 |
| `Sources/Shared/Database.swift` | 修改 | 数据库迁移添加 OAuth 列 |
| `Sources/Shared/ConfigWriter.swift` | 修改 | 新增 `writeCodexOAuthConfig` 方法，修改 dispatch |
| `Sources/Shared/CodexOAuthLoginParser.swift` | 创建 | 解析 `codex login --device-auth` 输出 |
| `Sources/Views/ProviderFormView.swift` | 修改 | OAuth 登录 UI 和刷新按钮 |
| `Sources/Views/OAuthLoginSheet.swift` | 创建 | OAuth 登录弹窗（Device Code 等待） |

---

### Task 1: 扩展 ProviderType 枚举

**文件:**
- Modify: `Sources/Models/Provider.swift:3-8`

- [ ] **Step 1: 添加 codexOAuth case**

```swift
enum ProviderType: String, CaseIterable, Identifiable, Codable {
    case claudeCode = "Claude Code"
    case codex = "Codex"
    case codexOAuth = "Codex OAuth"  // 新增

    var id: String { rawValue }
}
```

- [ ] **Step 2: 验证构建**

Run: `xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Debug build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:|warning:.*ProviderType" | head -20`

Expected: 无 ProviderType 相关 error

- [ ] **Step 3: 提交**

```bash
git add Sources/Models/Provider.swift
git commit -m "feat(provider): add codexOAuth type to ProviderType enum

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

---

### Task 2: 扩展 Provider 模型（添加 OAuth 字段）

**文件:**
- Modify: `Sources/Models/Provider.swift:10-51`

- [ ] **Step 1: 添加 OAuth 字段到 Provider struct**

将 `Provider` struct 中的 `apiKey` 改为可选（`apiKey: String?`），并新增以下字段（添加在 `sortOrder` 之后）：

```swift
struct Provider: Identifiable, Equatable, Codable {
    var id: UUID
    var name: String
    var type: ProviderType
    var apiKey: String?           // Codex OAuth 模式下为 nil
    var baseUrl: String
    var model: String?
    var thinkingModel: String?
    var haikuModel: String?
    var sonnetModel: String?
    var opusModel: String?
    var isActive: Bool
    var sortOrder: Int

    // === Codex OAuth 专用字段 ===
    var oauthAccountId: String?
    var oauthAccessToken: String?
    var oauthRefreshToken: String?
    var oauthIdToken: String?
    var oauthTokenExpiry: Date?
    var oauthDisplayName: String?

    init(
        id: UUID = UUID(),
        name: String,
        type: ProviderType,
        apiKey: String?,
        baseUrl: String,
        model: String? = nil,
        thinkingModel: String? = nil,
        haikuModel: String? = nil,
        sonnetModel: String? = nil,
        opusModel: String? = nil,
        isActive: Bool = false,
        sortOrder: Int = 0,
        oauthAccountId: String? = nil,
        oauthAccessToken: String? = nil,
        oauthRefreshToken: String? = nil,
        oauthIdToken: String? = nil,
        oauthTokenExpiry: Date? = nil,
        oauthDisplayName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.apiKey = apiKey
        self.baseUrl = baseUrl
        self.model = model
        self.thinkingModel = thinkingModel
        self.haikuModel = haikuModel
        self.sonnetModel = sonnetModel
        self.opusModel = opusModel
        self.isActive = isActive
        self.sortOrder = sortOrder
        self.oauthAccountId = oauthAccountId
        self.oauthAccessToken = oauthAccessToken
        self.oauthRefreshToken = oauthRefreshToken
        self.oauthIdToken = oauthIdToken
        self.oauthTokenExpiry = oauthTokenExpiry
        self.oauthDisplayName = oauthDisplayName
    }
}
```

- [ ] **Step 2: 更新 PresetProvider 的 codex preset 使用**

`PresetProvider` 中 `apiKey` 为非可选，需要改为 `apiKey: "placeholder"`（因为 codex preset 不会被 OAuth 使用，codex OAuth 不出现在 preset 中，保持不变即可）。

**验证构建**

Run: `xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Debug build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:" | head -20`

Expected: 无 error

- [ ] **Step 3: 提交**

```bash
git add Sources/Models/Provider.swift
git commit -m "feat(provider): add OAuth fields to Provider model

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

---

### Task 3: 数据库迁移（添加 OAuth 列）

**文件:**
- Modify: `Sources/Shared/Database.swift`

- [ ] **Step 1: 添加 OAuth 列定义**

在 `Database` 类的列定义区域（`sortOrderColumn` 之后）添加：

```swift
private let oauthAccountIdColumn = Expression<String?>("oauth_account_id")
private let oauthAccessTokenColumn = Expression<String?>("oauth_access_token")
private let oauthRefreshTokenColumn = Expression<String?>("oauth_refresh_token")
private let oauthIdTokenColumn = Expression<String?>("oauth_id_token")
private let oauthTokenExpiryColumn = Expression<String?>("oauth_token_expiry")
private let oauthDisplayNameColumn = Expression<String?>("oauth_display_name")
```

- [ ] **Step 2: 添加 createTable 中的列**

在 `createTable()` 的 `providersTable.create` 闭包末尾添加：

```swift
t.column(oauthAccountIdColumn)
t.column(oauthAccessTokenColumn)
t.column(oauthRefreshTokenColumn)
t.column(oauthIdTokenColumn)
t.column(oauthTokenExpiryColumn)
t.column(oauthDisplayNameColumn)
```

- [ ] **Step 3: 添加 migrateIfNeeded 中的迁移**

在 `migrations` 数组中添加：

```swift
let migrations: [(String, SQLite.Expression<String?>)] = [
    ("thinking_model", thinkingModelColumn),
    ("haiku_model", haikuModelColumn),
    ("sonnet_model", sonnetModelColumn),
    ("opus_model", opusModelColumn),
    // OAuth columns
    ("oauth_account_id", oauthAccountIdColumn),
    ("oauth_access_token", oauthAccessTokenColumn),
    ("oauth_refresh_token", oauthRefreshTokenColumn),
    ("oauth_id_token", oauthIdTokenColumn),
    ("oauth_token_expiry", oauthTokenExpiryColumn),
    ("oauth_display_name", oauthDisplayNameColumn),
]
```

- [ ] **Step 4: 更新 loadAllProviders 中的 provider 构造**

在 `loadAllProviders()` 的 provider 构造中，添加 OAuth 字段读取。在 `sortOrder: row[self.sortOrderColumn]` 后添加逗号，然后添加：

```swift
oauthAccountId: row[self.oauthAccountIdColumn],
oauthAccessToken: row[self.oauthAccessTokenColumn],
oauthRefreshToken: row[self.oauthRefreshTokenColumn],
oauthIdToken: row[self.oauthIdTokenColumn],
oauthTokenExpiry: row[self.oauthTokenExpiryColumn].flatMap { ISO8601DateFormatter().date(from: $0) },
oauthDisplayName: row[self.oauthDisplayNameColumn],
```

- [ ] **Step 5: 更新 addProvider 中的 insert**

在 `addProvider()` 的 `sortOrderColumn <- provider.sortOrder` 后添加：

```swift
oauthAccountIdColumn <- provider.oauthAccountId,
oauthAccessTokenColumn <- provider.oauthAccessToken,
oauthRefreshTokenColumn <- provider.oauthRefreshToken,
oauthIdTokenColumn <- provider.oauthIdToken,
oauthTokenExpiryColumn <- provider.oauthTokenExpiry.map { ISO8601DateFormatter().string(from: $0) },
oauthDisplayNameColumn <- provider.oauthDisplayName,
```

- [ ] **Step 6: 更新 updateProvider 中的 update**

在 `updateProvider()` 的 `sortOrderColumn <- provider.sortOrder` 后添加相同的字段。

- [ ] **Step 7: 验证构建**

Run: `xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Debug build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:" | head -20`

Expected: 无 error

- [ ] **Step 8: 提交**

```bash
git add Sources/Shared/Database.swift
git commit -m "feat(database): add OAuth columns migration

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

---

### Task 4: 创建 CodexOAuthLoginParser

**文件:**
- Create: `Sources/Shared/CodexOAuthLoginParser.swift`

- [ ] **Step 1: 编写解析器**

```swift
import Foundation

struct DeviceCodeInfo {
    let userCode: String      // e.g. "U9CQ-MFLJ1"
    let verificationUrl: String  // "https://auth.openai.com/codex/device"
}

enum CodexOAuthLoginParser {
    /// 从 `codex login --device-auth` 的 stdout 解析 Device Code 信息
    static func parse(_ output: String) -> DeviceCodeInfo? {
        // 匹配格式: XXXX-XXXX (4个字母数字 + 短横线 + 4个字母数字)
        let codePattern = #"([A-Z0-9]{4}-[A-Z0-9]{4})"#

        guard let codeMatch = output.range(of: codePattern, options: .regularExpression) else {
            return nil
        }

        let userCode = String(output[codeMatch])
        let verificationUrl = "https://auth.openai.com/codex/device"

        return DeviceCodeInfo(userCode: userCode, verificationUrl: verificationUrl)
    }

    /// 从 `~/.codex/auth.json` 解析 OAuth tokens
    static func parseAuthJson(at url: URL) -> (accountId: String, accessToken: String, refreshToken: String, idToken: String, displayName: String?)? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let authMode = json["auth_mode"] as? String,
              authMode == "chatgpt",
              let tokens = json["tokens"] as? [String: Any],
              let idToken = tokens["id_token"] as? String,
              let accessToken = tokens["access_token"] as? String,
              let refreshToken = tokens["refresh_token"] as? String,
              let accountId = tokens["account_id"] as? String
        else {
            return nil
        }

        // 从 id_token 中提取 email 作为 displayName
        var displayName: String?
        if let idTokenData = Data(base64Encoded: idToken.components(separatedBy: ".")[1].padding(toLength: ((idToken.components(separatedBy: ".")[1].count + 3) / 4) * 4, withPad: "=", startingAt: 0)) ?? Data(),
           let claims = try? JSONSerialization.jsonObject(with: idTokenData) as? [String: Any] {
            displayName = claims["email"] as? String
        }

        return (accountId, accessToken, refreshToken, idToken, displayName)
    }
}
```

- [ ] **Step 2: 验证构建**

Run: `xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Debug build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:.*CodexOAuth" | head -20`

Expected: 无 error

- [ ] **Step 3: 提交**

```bash
git add Sources/Shared/CodexOAuthLoginParser.swift
git commit -m "feat(oauth): add CodexOAuthLoginParser for Device Code output parsing

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

---

### Task 5: 更新 ConfigWriter 支持 Codex OAuth

**文件:**
- Modify: `Sources/Shared/ConfigWriter.swift`

- [ ] **Step 1: 在 dispatch 方法中添加 codexOAuth 分支**

修改 `writeProviderToConfig` 方法：

```swift
func writeProviderToConfig(_ provider: Provider) throws {
    switch provider.type {
    case .claudeCode: try writeClaudeCodeConfig(provider)
    case .codex:      try writeCodexConfig(provider)
    case .codexOAuth: try writeCodexOAuthConfig(provider)  // 新增
    }
}
```

- [ ] **Step 2: 添加 writeCodexOAuthConfig 方法**

在 `writeCodexConfig` 方法之后添加：

```swift
// MARK: - Codex OAuth → ~/.codex/auth.json + config.toml

private func writeCodexOAuthConfig(_ provider: Provider) throws {
    try fileManager.createDirectory(at: codexDir, withIntermediateDirectories: true)

    // 写入 auth.json
    let authUrl = codexDir.appendingPathComponent("auth.json")
    var auth: [String: Any] = (try? Data(contentsOf: authUrl))
        .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]

    auth["auth_mode"] = "chatgpt"
    auth["OPENAI_API_KEY"] = NSNull()

    var tokens: [String: Any] = [
        "id_token": provider.oauthIdToken ?? "",
        "access_token": provider.oauthAccessToken ?? "",
        "refresh_token": provider.oauthRefreshToken ?? "",
        "account_id": provider.oauthAccountId ?? ""
    ]
    auth["tokens"] = tokens
    auth["last_refresh"] = ISO8601DateFormatter().string(from: Date())

    let authData = try JSONSerialization.data(withJSONObject: auth, options: [.prettyPrinted])
    try authData.write(to: authUrl, options: .atomic)

    // 写入 config.toml（仅 model 字段，不写 model_provider）
    let model = provider.model ?? "gpt-4o"
    let configContent = """
    model = "\(model)"

    """
    try configContent.write(to: codexConfig, atomically: true, encoding: .utf8)
}
```

- [ ] **Step 3: 验证构建**

Run: `xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Debug build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:" | head -20`

Expected: 无 error

- [ ] **Step 4: 提交**

```bash
git add Sources/Shared/ConfigWriter.swift
git commit -m "feat(config): add Codex OAuth config writing

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

---

### Task 6: 创建 OAuth 登录弹窗视图

**文件:**
- Create: `Sources/Views/OAuthLoginSheet.swift`

- [ ] **Step 1: 编写 OAuthLoginSheet 视图**

```swift
import SwiftUI

struct OAuthLoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var deviceCode: String = ""
    @State private var verificationUrl: String = ""
    @State private var pollingState: PollingState = .idle
    @State private var errorMessage: String?

    enum PollingState {
        case idle
        case polling
        case success
        case error
    }

    let onComplete: (String, String, String, String, String?) -> Void
    // (accountId, accessToken, refreshToken, idToken, displayName)

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("LOGIN CHATGPT")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            if pollingState == .idle {
                // 显示 Device Code 信息（由上层填充）
                IdleContent(
                    deviceCode: deviceCode,
                    verificationUrl: verificationUrl,
                    onPollingStart: { pollingState = .polling }
                )
            } else if pollingState == .polling {
                PollingContent(deviceCode: deviceCode)
            } else if pollingState == .success {
                SuccessContent()
            } else if pollingState == .error {
                ErrorContent(message: errorMessage ?? "Unknown error")
            }
        }
        .frame(width: 340)
    }
}

struct IdleContent: View {
    let deviceCode: String
    let verificationUrl: String
    let onPollingStart: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("1. Open this link in your browser and sign in:")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text(verificationUrl)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(verificationUrl, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Text("2. Enter this one-time code:")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text(deviceCode)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(deviceCode, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(themeManager.brandColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Button {
                onPollingStart()
            } label: {
                Text("I've Completed Login")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(themeManager.brandColor)
        }
        .padding(18)
    }

    @EnvironmentObject var themeManager: ThemeManager
}

struct PollingContent: View {
    let deviceCode: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Waiting for authorization...")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)

            Text("Code: \(deviceCode)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }
}

struct SuccessContent: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)

            Text("Login Successful!")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
        }
        .padding(40)
    }
}

struct ErrorContent: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.red)

            Text("Error: \(message)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}
```

- [ ] **Step 2: 验证构建**

Run: `xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Debug build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:.*OAuthLogin" | head -20`

Expected: 无 error

- [ ] **Step 3: 提交**

```bash
git add Sources/Views/OAuthLoginSheet.swift
git commit -m "feat(ui): add OAuthLoginSheet view

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

---

### Task 7: 更新 ProviderFormView 支持 codexOAuth

**文件:**
- Modify: `Sources/Views/ProviderFormView.swift`

- [ ] **Step 1: 添加 OAuth 相关的 State 变量**

在现有 `@State` 变量区域添加：

```swift
@State private var oauthIsLoggedIn: Bool = false
@State private var oauthDisplayName: String = ""
@State private var showOAuthLogin: Bool = false
```

- [ ] **Step 2: 修改 isValid 计算属性**

`codexOAuth` 类型不需要 apiKey，修改 `isValid`：

```swift
private var isValid: Bool {
    !name.trimmingCharacters(in: .whitespaces).isEmpty &&
    !baseUrl.trimmingCharacters(in: .whitespaces).isEmpty &&
    (type != .codexOAuth ? !apiKey.trimmingCharacters(in: .whitespaces).isEmpty : true)
}
```

- [ ] **Step 3: 修改 modelPlaceholder 计算属性**

添加 `codexOAuth` 类型支持：

```swift
private var modelPlaceholder: String {
    switch type {
    case .claudeCode: return "claude-sonnet-4-20250514"
    case .codex: return "gpt-4o"
    case .codexOAuth: return "gpt-4o"
    }
}
```

- [ ] **Step 4: 修改 baseUrlPlaceholder 计算属性**

```swift
private var baseUrlPlaceholder: String {
    switch type {
    case .claudeCode: return "https://api.anthropic.com"
    case .codex: return "https://api.openai.com/v1"
    case .codexOAuth: return "https://api.openai.com/v1"
    }
}
```

- [ ] **Step 5: 修改 Form 中的 type tabs 和内容区域**

将 `ForEach(ProviderType.allCases)` 保持不变（自动包含新的 `codexOAuth`）。

找到 `fieldGroup("API KEY"` 的行，在其外层条件中排除 `codexOAuth`：

```swift
if type != .codexOAuth {
    fieldGroup("API KEY", text: $apiKey, placeholder: "sk-...", isSecure: true)
}
```

- [ ] **Step 6: 在 Base URL 和 Model 字段之间添加 OAuth Account 区块**

在 `fieldGroup("BASE URL"...` 之后添加（仅 `codexOAuth` 类型显示）：

```swift
if type == .codexOAuth {
    VStack(alignment: .leading, spacing: 6) {
        Text("ACCOUNT")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)

        if oauthIsLoggedIn {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 12))
                Text(oauthDisplayName.isEmpty ? "Logged in" : oauthDisplayName)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Refresh") {
                    // TODO: Token refresh action
                }
                .font(.system(size: 11, design: .monospaced))
                .buttonStyle(.bordered)
                Button("Logout") {
                    oauthIsLoggedIn = false
                    oauthDisplayName = ""
                }
                .font(.system(size: 11, design: .monospaced))
                .buttonStyle(.bordered)
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Button {
                showOAuthLogin = true
            } label: {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Login with ChatGPT")
                }
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(themeManager.brandColor)
        }
    }
}
```

- [ ] **Step 7: 添加 sheet 绑定**

在 `ProviderFormView` 末尾添加 `.sheet(isPresented: $showOAuthLogin)` 修饰符：

在 `frame(maxHeight: 600)` 之后添加：

```swift
.sheet(isPresented: $showOAuthLogin) {
    OAuthLoginSheet { accountId, accessToken, refreshToken, idToken, displayName in
        // Handle OAuth completion
        self.oauthIsLoggedIn = true
        self.oauthDisplayName = displayName ?? "ChatGPT Account"
        self.showOAuthLogin = false
    }
}
```

**注意**：`OAuthLoginSheet` 的 `onComplete` 参数实际使用时需要传递完整的 OAuth 数据（accountId, accessToken, refreshToken, idToken, displayName）。目前 `OAuthLoginSheet` 内部实现需要补充完整的 Device Code 轮询逻辑，这部分在 Task 8 中实现。

- [ ] **Step 8: 更新 onAppear 中 edit 模式的初始化**

在 `onAppear` 的 edit 分支中补充 OAuth 字段：

```swift
if case .edit(let provider) = mode {
    name = provider.name
    type = provider.type
    apiKey = provider.apiKey ?? ""
    baseUrl = provider.baseUrl
    model = provider.model ?? ""
    thinkingModel = provider.thinkingModel ?? ""
    haikuModel = provider.haikuModel ?? ""
    sonnetModel = provider.sonnetModel ?? ""
    opusModel = provider.opusModel ?? ""
    // OAuth fields
    oauthIsLoggedIn = provider.oauthAccountId != nil
    oauthDisplayName = provider.oauthDisplayName ?? ""
}
```

- [ ] **Step 9: 更新 saveProvider 中的 provider 构造**

修改 `saveProvider()` 中的两处 provider 构造，添加 OAuth 字段：

在 `mode.add` 分支中：

```swift
provider = Provider(
    name: name.trimmingCharacters(in: .whitespaces),
    type: type,
    apiKey: type == .codexOAuth ? nil : apiKey.trimmingCharacters(in: .whitespaces),
    baseUrl: baseUrl.trimmingCharacters(in: .whitespaces),
    model: model.isEmpty ? nil : model.trimmingCharacters(in: .whitespaces),
    thinkingModel: thinkingModel.isEmpty ? nil : thinkingModel.trimmingCharacters(in: .whitespaces),
    haikuModel: haikuModel.isEmpty ? nil : haikuModel.trimmingCharacters(in: .whitespaces),
    sonnetModel: sonnetModel.isEmpty ? nil : sonnetModel.trimmingCharacters(in: .whitespaces),
    opusModel: opusModel.isEmpty ? nil : opusModel.trimmingCharacters(in: .whitespaces),
    sortOrder: 0,
    oauthAccountId: nil,
    oauthAccessToken: nil,
    oauthRefreshToken: nil,
    oauthIdToken: nil,
    oauthTokenExpiry: nil,
    oauthDisplayName: oauthDisplayName.isEmpty ? nil : oauthDisplayName
)
```

在 `mode.edit` 分支中同样添加 OAuth 字段的传递。

- [ ] **Step 10: 验证构建**

Run: `xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Debug build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:" | head -20`

Expected: 无 error（可能有一些 unused variable 警告，可忽略）

- [ ] **Step 11: 提交**

```bash
git add Sources/Views/ProviderFormView.swift
git commit -m "feat(ui): update ProviderFormView to support codexOAuth type

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

---

### Task 8: 实现 OAuth Device Code 登录逻辑

**文件:**
- Create: `Sources/Shared/OAuthLoginManager.swift`

- [ ] **Step 1: 编写 OAuthLoginManager**

这个 manager 负责执行 `codex login --device-auth` 并轮询 auth.json。

```swift
import Foundation

actor OAuthLoginManager {
    static let shared = OAuthLoginManager()

    private init() {}

    /// 执行 Device Code 登录，返回解析出的 DeviceCodeInfo
    func startLogin() async throws -> DeviceCodeInfo {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/codex")
        process.arguments = ["login", "--device-auth"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        guard let info = CodexOAuthLoginParser.parse(output) else {
            throw OAuthError.parseFailed
        }

        return info
    }

    /// 轮询 ~/.codex/auth.json 直到出现 auth_mode = "chatgpt"
    /// 超时时间 15 分钟（900 秒），轮询间隔 5 秒
    func pollForAuth(timeoutSeconds: Int = 900, intervalSeconds: Int = 5) async throws -> (accountId: String, accessToken: String, refreshToken: String, idToken: String, displayName: String?) {
        let authUrl = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".codex")
            .appendingPathComponent("auth.json")

        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))

        while Date() < deadline {
            if let result = CodexOAuthLoginParser.parseAuthJson(at: authUrl) {
                return result
            }
            try await Task.sleep(nanoseconds: UInt64(intervalSeconds) * 1_000_000_000)
        }

        throw OAuthError.timeout
    }
}

enum OAuthError: Error, LocalizedError {
    case parseFailed
    case timeout
    case cancelled

    var errorDescription: String? {
        switch self {
        case .parseFailed: return "Failed to parse Device Code from output"
        case .timeout: return "Login timeout (15 minutes)"
        case .cancelled: return "Login cancelled"
        }
    }
}
```

- [ ] **Step 2: 更新 OAuthLoginSheet 以集成 OAuthLoginManager**

修改 `OAuthLoginSheet`，添加完整的登录流程调用：

在 `OAuthLoginSheet` struct 中添加 `@StateObject` 或直接使用 `Task` 管理异步流程：

将 `OAuthLoginSheet` 的 body 改为使用 `oauthState` 驱动：

```swift
struct OAuthLoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var deviceCode: String = ""
    @State private var verificationUrl: String = "https://auth.openai.com/codex/device"
    @State private var pollingState: PollingState = .idle
    @State private var errorMessage: String?
    @State private var loginTask: Task<Void, Never>?

    enum PollingState {
        case idle
        case polling
        case success
        case error
    }

    let onComplete: (String, String, String, String, String?) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header (同前)
            HStack {
                Text("LOGIN CHATGPT")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    loginTask?.cancel()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            content
        }
        .frame(width: 340)
        .onAppear {
            startLoginFlow()
        }
        .onDisappear {
            loginTask?.cancel()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch pollingState {
        case .idle:
            IdleContent(deviceCode: deviceCode, verificationUrl: verificationUrl)
        case .polling:
            PollingContent(deviceCode: deviceCode)
        case .success:
            SuccessContent()
        case .error:
            ErrorContent(message: errorMessage ?? "Unknown error")
        }
    }

    private func startLoginFlow() {
        loginTask = Task {
            do {
                // 1. 启动 Device Code 流程
                let info = try await OAuthLoginManager.shared.startLogin()
                await MainActor.run {
                    self.deviceCode = info.userCode
                    self.verificationUrl = info.verificationUrl
                    self.pollingState = .polling
                }

                // 2. 轮询等待授权
                let result = try await OAuthLoginManager.shared.pollForAuth()

                // 3. 回调
                await MainActor.run {
                    self.pollingState = .success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.onComplete(result.accountId, result.accessToken, result.refreshToken, result.idToken, result.displayName)
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.pollingState = .error
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 3: 验证构建**

Run: `xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Debug build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:" | head -20`

Expected: 无 error

- [ ] **Step 4: 提交**

```bash
git add Sources/Shared/OAuthLoginManager.swift Sources/Views/OAuthLoginSheet.swift
git commit -m "feat(oauth): implement OAuth Device Code login flow

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

---

### Task 9: 更新 ProviderFormView 集成 OAuth 回调数据

**文件:**
- Modify: `Sources/Views/ProviderFormView.swift`

- [ ] **Step 1: 添加 OAuth Token State 变量**

添加以下 `@State` 变量（用于存储临时 OAuth 回调数据）：

```swift
@State private var pendingOauthTokens: (accessToken: String, refreshToken: String, idToken: String)?
```

- [ ] **Step 2: 更新 OAuthLoginSheet 的 onComplete 回调**

将 sheet 调用更新为：

```swift
.sheet(isPresented: $showOAuthLogin) {
    OAuthLoginSheet { accountId, accessToken, refreshToken, idToken, displayName in
        self.oauthIsLoggedIn = true
        self.oauthDisplayName = displayName ?? "ChatGPT Account"
        self.pendingOauthTokens = (accessToken, refreshToken, idToken)
        self.showOAuthLogin = false
    }
}
```

- [ ] **Step 3: 更新 saveProvider 中使用 pendingOauthTokens**

在 `mode.edit` 和 `mode.add` 的 provider 构造中，添加 `oauthAccessToken`、`oauthRefreshToken`、`oauthIdToken` 字段（从 `pendingOauthTokens` 获取）。

在 `saveProvider()` 方法中，找到 provider 构造调用，在保存前添加：

```swift
// 如果有 pending OAuth tokens，填充到 provider
let accessToken = pendingOauthTokens?.accessToken
let refreshToken = pendingOauthTokens?.refreshToken
let idToken = pendingOauthTokens?.idToken
```

然后在 provider 构造时传入这些值。

- [ ] **Step 4: 验证构建**

Run: `xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Debug build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:" | head -20`

Expected: 无 error

- [ ] **Step 5: 提交**

```bash
git add Sources/Views/ProviderFormView.swift
git commit -m "feat(ui): wire OAuth callback data into ProviderFormView

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

---

### Task 10: Provider 详情预览支持 codexOAuth

**文件:**
- Modify: `Sources/Views/ProviderListView.swift` 或 `ContentView.swift`（根据实际 Provider 详情展示位置）

- [ ] **Step 1: 在 Provider 详情区域显示 OAuth 账号信息**

找到展示 Provider 详情的视图（可能在 `ContentView.swift` 中的 detail panel）。当 `provider.type == .codexOAuth` 时，展示：

```
已登录: <oauthDisplayName> (ChatGPT)
```

格式与设计文档 7.3 节一致。如果 `oauthDisplayName` 为空，显示 "已登录: ChatGPT Account"。

- [ ] **Step 2: 验证构建**

Run: `xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Debug build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:" | head -20`

Expected: 无 error

- [ ] **Step 3: 提交**

```bash
git add Sources/Views/ContentView.swift
git commit -m "feat(ui): show OAuth account info in provider detail

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

---

### Task 11: Token 刷新逻辑

**文件:**
- Modify: `Sources/Shared/OAuthLoginManager.swift`

- [ ] **Step 1: 添加刷新方法**

在 `OAuthLoginManager` actor 中添加：

```swift
/// 刷新指定 provider 的 OAuth token
/// 注意：Codex OAuth 的 token 刷新需要通过 OpenAI OAuth 端点实现。
/// 目前 Codex CLI 不提供 token 刷新命令，需要手动实现 OAuth refresh 流程。
/// 这里先预留接口，实际刷新通过重新执行 login 实现。
func refreshToken(for provider: Provider) async throws {
    // TODO: 实现 OAuth token refresh
    // 方案1: 直接调用 OpenAI OAuth token 端点刷新
    // 方案2: 提示用户重新登录（当前采用）
    throw OAuthError.refreshNotSupported
}
```

在 `OAuthError` 枚举中添加：

```swift
case refreshNotSupported
```

- [ ] **Step 2: 在 ProviderFormView 中连接刷新按钮**

刷新按钮当前是占位符，在 Task 7 的基础上，当用户点击刷新时，调用 `OAuthLoginManager.shared.startLogin()` 重新执行登录流程，并用新返回的 tokens 更新 provider。

- [ ] **Step 3: 验证构建**

Run: `xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Debug build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:" | head -20`

Expected: 无 error

- [ ] **Step 4: 提交**

```bash
git add Sources/Shared/OAuthLoginManager.swift Sources/Views/ProviderFormView.swift
git commit -m "feat(oauth): add token refresh stub

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

---

### Task 12: 集成测试与最终验证

- [ ] **Step 1: 完整构建**

Run: `xcodebuild -project CCManager.xcodeproj -scheme CCManager -configuration Release build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:" | head -20`

Expected: 无 error

- [ ] **Step 2: CLI 构建**

Run: `xcodebuild -project CCManager.xcodeproj -scheme CCManagerCLI -configuration Release build CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:" | head -20`

Expected: 无 error

- [ ] **Step 3: 提交**

```bash
git add -A
git commit -m "feat: implement Codex OAuth provider support

- Add codexOAuth ProviderType
- Store OAuth tokens in SQLite (not written to disk until activated)
- Device Code login via codex login --device-auth
- Write OAuth auth.json (auth_mode=chatgpt, OPENAI_API_KEY=null) on activate
- Write minimal config.toml (model only, no model_provider)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

---

## 自检清单

- [ ] Spec Section 2（Provider 类型）：Task 1, 2 覆盖
- [ ] Spec Section 3（数据库）：Task 3 覆盖
- [ ] Spec Section 4（OAuth 登录）：Task 4, 6, 8 覆盖
- [ ] Spec Section 5（激活写入）：Task 5 覆盖
- [ ] Spec Section 6（Token 刷新）：Task 11 覆盖
- [ ] Spec Section 7（UI）：Task 6, 7, 8, 9, 10 覆盖
- [ ] Spec Section 8（新文件）：Task 4, 6, 8 覆盖
- [ ] 所有步骤包含具体代码和具体命令
- [ ] 类型一致性：Provider 模型的 oauth* 字段在 Database/ConfigWriter/ProviderFormView 中一致使用
- [ ] 无占位符（所有 TODO 已在 Task 中标记）
