import Foundation

final class ConfigWriter {
    static let shared = ConfigWriter()

    private let fileManager = FileManager.default
    private let home = URL(fileURLWithPath: NSHomeDirectory())

    // MARK: - Claude Code paths
    private var claudeDir: URL { home.appendingPathComponent(".claude") }
    private var claudeSettings: URL { claudeDir.appendingPathComponent("settings.json") }

    // MARK: - Codex paths
    private var codexDir: URL { home.appendingPathComponent(".codex") }
    private var codexConfig: URL { codexDir.appendingPathComponent("config.toml") }

    private init() {}

    // MARK: - Public dispatch

    func writeProviderToConfig(_ provider: Provider) throws {
        switch provider.type {
        case .claudeCode: try writeClaudeCodeConfig(provider)
        case .codex:      try writeCodexConfig(provider)
        }
    }

    // MARK: - Claude Code → ~/.claude/settings.json

    private func writeClaudeCodeConfig(_ provider: Provider) throws {
        try fileManager.createDirectory(at: claudeDir, withIntermediateDirectories: true)

        var settings: [String: Any] = (try? Data(contentsOf: claudeSettings))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]

        var env = settings["env"] as? [String: Any] ?? [:]
        env["ANTHROPIC_AUTH_TOKEN"] = provider.apiKey
        env["ANTHROPIC_BASE_URL"] = provider.baseUrl

        // 主模型
        let mainModel = provider.model ?? PresetProvider.defaultClaudeModel
        env["ANTHROPIC_MODEL"] = mainModel

        // 其他模型 - 如果未设置则使用主模型
        env["ANTHROPIC_SMALL_FAST_MODEL"] = provider.thinkingModel ?? mainModel
        env["ANTHROPIC_DEFAULT_HAIKU_MODEL"] = provider.haikuModel ?? mainModel
        env["ANTHROPIC_DEFAULT_SONNET_MODEL"] = provider.sonnetModel ?? mainModel
        env["ANTHROPIC_DEFAULT_OPUS_MODEL"] = provider.opusModel ?? mainModel

        settings["env"] = env

        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: claudeSettings, options: .atomic)
    }

    // MARK: - Codex → ~/.codex/auth.json + config.toml

    private func writeCodexConfig(_ provider: Provider) throws {
        try fileManager.createDirectory(at: codexDir, withIntermediateDirectories: true)

        let model = provider.model ?? PresetProvider.defaultCodexModel
        let providerKey = "ccmanager"  // fixed provider key

        // Write auth.json (merge with existing)
        let authUrl = codexDir.appendingPathComponent("auth.json")
        var auth: [String: String] = (try? Data(contentsOf: authUrl))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: String] } ?? [:]
        auth["OPENAI_API_KEY"] = provider.apiKey
        let authData = try JSONSerialization.data(withJSONObject: auth, options: [.prettyPrinted])
        try authData.write(to: authUrl, options: .atomic)

        // Build new config content with model_providers section
        let config = """
        model_provider = "\(providerKey)"
        model = "\(model)"

        [model_providers.\(providerKey)]
        name = "\(providerKey)"
        base_url = "\(provider.baseUrl)"
        wire_api = "responses"
        requires_openai_auth = true
        """

        try config.write(to: codexConfig, atomically: true, encoding: .utf8)
    }

    // MARK: - Read helpers

    func readClaudeSettings() -> [String: Any]? {
        guard let data = try? Data(contentsOf: claudeSettings) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
