import Foundation

final class ConfigWriter {
    static let shared = ConfigWriter()

    private let fileManager: FileManager
    private let home: URL
    private let currentDate: () -> Date

    // MARK: - Claude Code paths
    private var claudeDir: URL { home.appendingPathComponent(".claude") }
    private var claudeSettings: URL { claudeDir.appendingPathComponent("settings.json") }

    // MARK: - Codex paths
    private var codexDir: URL { home.appendingPathComponent(".codex") }
    private var codexConfig: URL { codexDir.appendingPathComponent("config.toml") }

    private init() {
        self.fileManager = .default
        self.home = URL(fileURLWithPath: NSHomeDirectory())
        self.currentDate = Date.init
    }

    init(fileManager: FileManager = .default, home: URL, currentDate: @escaping () -> Date = Date.init) {
        self.fileManager = fileManager
        self.home = home
        self.currentDate = currentDate
    }

    // MARK: - Public dispatch

    func writeProviderToConfig(_ provider: Provider) throws {
        switch provider.type {
        case .claudeCode: try writeClaudeCodeConfig(provider)
        case .codex:      try writeCodexConfig(provider)
        case .codexOAuth: try writeCodexOAuthConfig(provider)
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

        // Write auth.json
        let authUrl = codexDir.appendingPathComponent("auth.json")
        var auth: [String: Any] = (try? Data(contentsOf: authUrl))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]

        auth["auth_mode"] = "apikey"
        auth["OPENAI_API_KEY"] = provider.apiKey ?? ""
        auth.removeValue(forKey: "tokens")
        auth.removeValue(forKey: "last_refresh")

        let authData = try JSONSerialization.data(withJSONObject: auth, options: [.prettyPrinted])
        try authData.write(to: authUrl, options: .atomic)

        let model = provider.model ?? PresetProvider.defaultCodexModel
        let providerKey = "ccmanager"  // fixed provider key
        let providerSection = """
        [model_providers.\(providerKey)]
        name = "\(providerKey)"
        base_url = "\(provider.baseUrl)"
        wire_api = "responses"
        requires_openai_auth = true
        """

        try updateCodexConfig(
            model: model,
            modelProvider: providerKey,
            managedProviderSection: providerSection
        )
    }

    // MARK: - Codex OAuth → ~/.codex/auth.json + config.toml

    private func writeCodexOAuthConfig(_ provider: Provider) throws {
        try fileManager.createDirectory(at: codexDir, withIntermediateDirectories: true)

        // Write auth.json
        let authUrl = codexDir.appendingPathComponent("auth.json")
        var auth: [String: Any] = (try? Data(contentsOf: authUrl))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]

        auth["auth_mode"] = "chatgpt"
        auth["OPENAI_API_KEY"] = NSNull()

        let tokens: [String: Any] = [
            "id_token": provider.oauthIdToken ?? "",
            "access_token": provider.oauthAccessToken ?? "",
            "refresh_token": provider.oauthRefreshToken ?? "",
            "account_id": provider.oauthAccountId ?? ""
        ]
        auth["tokens"] = tokens
        auth["last_refresh"] = ISO8601DateFormatter().string(from: currentDate())

        let authData = try JSONSerialization.data(withJSONObject: auth, options: [.prettyPrinted])
        try authData.write(to: authUrl, options: .atomic)

        // Update only CCManager-owned fields in config.toml.
        let model = provider.model ?? PresetProvider.defaultCodexModel
        try updateCodexConfig(model: model, modelProvider: nil, managedProviderSection: nil)
    }

    private func updateCodexConfig(
        model: String,
        modelProvider: String?,
        managedProviderSection: String?
    ) throws {
        let existingConfig = fileManager.fileExists(atPath: codexConfig.path)
            ? try String(contentsOf: codexConfig, encoding: .utf8)
            : ""
        var lines = splitPreservingLineEndings(existingConfig)

        setTopLevelValue("model", to: model, in: &lines)
        setTopLevelValue("model_provider", to: modelProvider, in: &lines)
        removeManagedCodexProviderSection(from: &lines)

        if let managedProviderSection {
            let detectedLineEnding = lines.compactMap(lineEnding(of:)).first ?? "\n"
            if !lines.isEmpty {
                if lineEnding(of: lines[lines.count - 1]) == nil {
                    lines[lines.count - 1] += detectedLineEnding
                }
                if !lineBody(of: lines[lines.count - 1]).isEmpty {
                    lines.append(detectedLineEnding)
                }
            }
            lines.append(contentsOf: splitPreservingLineEndings(
                managedProviderSection.replacingOccurrences(of: "\n", with: detectedLineEnding) + detectedLineEnding
            ))
        }

        try lines.joined().write(to: codexConfig, atomically: true, encoding: .utf8)
    }

    private func setTopLevelValue(_ key: String, to value: String?, in lines: inout [String]) {
        let firstTableIndex = lines.firstIndex(where: isTableHeader) ?? lines.endIndex
        let matchingIndexes = lines.indices.prefix(upTo: firstTableIndex).filter {
            isAssignment(to: key, line: lines[$0])
        }

        if let value {
            let replacement = "\(key) = \"\(value)\""
            if let firstIndex = matchingIndexes.first {
                lines[firstIndex] = replacement + (lineEnding(of: lines[firstIndex]) ?? "")
                for index in matchingIndexes.dropFirst().reversed() {
                    lines.remove(at: index)
                }
            } else {
                let lineEnding = lines.compactMap(lineEnding(of:)).first ?? "\n"
                lines.insert(replacement + lineEnding, at: firstTableIndex)
            }
        } else {
            for index in matchingIndexes.reversed() {
                lines.remove(at: index)
            }
        }
    }

    private func removeManagedCodexProviderSection(from lines: inout [String]) {
        while let sectionStart = lines.firstIndex(where: isManagedCodexProviderHeader) {
            let nextSection = lines.indices.dropFirst(sectionStart + 1).first {
                isTableHeader(lines[$0])
            } ?? lines.endIndex
            lines.removeSubrange(sectionStart..<nextSection)
        }
    }

    private func splitPreservingLineEndings(_ content: String) -> [String] {
        var lines: [String] = []
        var lineStart = content.startIndex

        while let newlineIndex = content[lineStart...].firstIndex(of: "\n") {
            let lineEnd = content.index(after: newlineIndex)
            lines.append(String(content[lineStart..<lineEnd]))
            lineStart = lineEnd
        }
        if lineStart < content.endIndex {
            lines.append(String(content[lineStart...]))
        }
        return lines
    }

    private func lineBody(of line: String) -> String {
        if line.hasSuffix("\r\n") { return String(line.dropLast(2)) }
        if line.hasSuffix("\n") { return String(line.dropLast()) }
        return line
    }

    private func lineEnding(of line: String) -> String? {
        if line.hasSuffix("\r\n") { return "\r\n" }
        if line.hasSuffix("\n") { return "\n" }
        return nil
    }

    private func isTableHeader(_ line: String) -> Bool {
        lineBody(of: line).trimmingCharacters(in: .whitespaces).hasPrefix("[")
    }

    private func isManagedCodexProviderHeader(_ line: String) -> Bool {
        let header = "[model_providers.ccmanager]"
        let trimmed = lineBody(of: line).trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(header) else { return false }
        let remainder = trimmed.dropFirst(header.count).trimmingCharacters(in: .whitespaces)
        return remainder.isEmpty || remainder.hasPrefix("#")
    }

    private func isAssignment(to key: String, line: String) -> Bool {
        let trimmed = lineBody(of: line).drop(while: { $0 == " " || $0 == "\t" })
        guard trimmed.hasPrefix(key) else { return false }
        return trimmed.dropFirst(key.count).drop(while: { $0 == " " || $0 == "\t" }).hasPrefix("=")
    }

    // MARK: - Read helpers

    func readClaudeSettings() -> [String: Any]? {
        guard let data = try? Data(contentsOf: claudeSettings) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
