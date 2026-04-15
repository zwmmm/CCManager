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
        env["ANTHROPIC_MODEL"] = provider.model ?? PresetProvider.defaultClaudeModel
        settings["env"] = env

        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: claudeSettings, options: .atomic)
    }

    // MARK: - Codex → ~/.codex/config.toml

    private func writeCodexConfig(_ provider: Provider) throws {
        try fileManager.createDirectory(at: codexDir, withIntermediateDirectories: true)

        let model = provider.model ?? PresetProvider.defaultCodexModel

        // Read and preserve unrelated fields from existing config
        var existing = readExistingToml()
        existing["model"] = model
        existing["model_provider"] = "ccmanager"

        // Build provider block (overwrite only our managed block)
        let providerBlock = """
            [model_providers.ccmanager]
            name = "CCManager"
            base_url = "\(provider.baseUrl)"
            api_key = "\(provider.apiKey)"
            """

        let toml = buildToml(scalars: existing, extraBlocks: [providerBlock])
        try toml.write(to: codexConfig, atomically: true, encoding: .utf8)
    }

    // MARK: - Minimal TOML helpers (no dependency)

    /// Read top-level scalar key=value pairs from existing config.toml (preserves non-managed fields)
    private func readExistingToml() -> [String: String] {
        guard let text = try? String(contentsOf: codexConfig, encoding: .utf8) else { return [:] }
        var result: [String: String] = [:]
        let managedKeys: Set<String> = ["model", "model_provider"]
        for line in text.components(separatedBy: .newlines) {
            let stripped = line.trimmingCharacters(in: .whitespaces)
            guard !stripped.hasPrefix("["), !stripped.hasPrefix("#"), stripped.contains("=") else { continue }
            let parts = stripped.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            let key = parts[0]
            guard !managedKeys.contains(key) else { continue }
            result[key] = parts[1]
        }
        return result
    }

    private func buildToml(scalars: [String: String], extraBlocks: [String]) -> String {
        var lines = ["# Managed by CCManager (model/model_provider/model_providers.ccmanager)"]
        for (k, v) in scalars.sorted(by: { $0.key < $1.key }) {
            lines.append("\(k) = \(v)")
        }
        lines.append("")
        lines.append(contentsOf: extraBlocks)
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Read helpers

    func readClaudeSettings() -> [String: Any]? {
        guard let data = try? Data(contentsOf: claudeSettings) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
