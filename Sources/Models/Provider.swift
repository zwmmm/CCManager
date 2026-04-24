import Foundation

enum ProviderType: String, CaseIterable, Identifiable, Codable {
    case claudeCode = "Claude Code"
    case codex = "Codex"
    case codexOAuth = "Codex OAuth"

    var id: String { rawValue }
}

struct Provider: Identifiable, Equatable, Codable {
    var id: UUID
    var name: String
    var type: ProviderType
    var apiKey: String?
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

struct PresetProvider {
    let name: String
    let type: ProviderType
    let baseUrl: String
    let model: String?

    static let defaultClaudeModel = "claude-sonnet-4-20250514"
    static let defaultCodexModel = "gpt-5.5"

    static let presets: [PresetProvider] = [
        // Claude Code
        PresetProvider(name: "GLM", type: .claudeCode, baseUrl: "https://open.bigmodel.cn/api/anthropic", model: "glm-5"),
        PresetProvider(name: "GLM Global", type: .claudeCode, baseUrl: "https://api.z.ai/api/anthropic", model: "glm-5"),
        PresetProvider(name: "MiniMax", type: .claudeCode, baseUrl: "https://api.minimaxi.com/anthropic", model: "MiniMax-M2.7"),
        PresetProvider(name: "MiniMax Global", type: .claudeCode, baseUrl: "https://api.minimax.io/anthropic", model: "MiniMax-M2.7"),
        PresetProvider(name: "Kimi", type: .claudeCode, baseUrl: "https://api.kimi.com/coding", model: "kimi-k2.5"),
        PresetProvider(name: "Anthropic", type: .claudeCode, baseUrl: "https://api.anthropic.com", model: defaultClaudeModel),
        PresetProvider(name: "OpenRouter (CC)", type: .claudeCode, baseUrl: "https://openrouter.ai/api/v1", model: "anthropic/claude-3-sonnet"),
        // Codex
        PresetProvider(name: "OpenAI", type: .codex, baseUrl: "https://api.openai.com/v1", model: defaultCodexModel),
        PresetProvider(name: "OpenRouter (Codex)", type: .codex, baseUrl: "https://openrouter.ai/api/v1", model: "openai/gpt-4o"),
    ]
}
