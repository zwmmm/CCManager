import Darwin
import Foundation
import SQLite

let cli = CCManagerCLI()
cli.run()

struct CCManagerCLI {
    func run() {
        let options = CLIOptions(arguments: Array(CommandLine.arguments.dropFirst()))

        guard let command = options.command else {
            printHelp()
            exit(0)
        }

        switch command {
        case "list":
            handleList(options: options)
        case "switch":
            handleSwitch(args: options.commandArgs, options: options)
        case "add":
            handleAdd(args: options.commandArgs, options: options)
        case "edit":
            handleEdit(args: options.commandArgs, options: options)
        case "delete":
            handleDelete(args: options.commandArgs, options: options)
        case "active":
            handleActive(options: options)
        case "test":
            handleTest(args: options.commandArgs, options: options)
        case "-h", "--help", "help":
            printHelp()
        default:
            exitWithError(
                CLIErrorPayload(
                    code: "unknown_command",
                    message: "Unknown command: \(command)",
                    input: ["command": command],
                    retryable: false,
                    suggestion: "Run 'ccmanager --help' to see available commands."
                ),
                options: options
            )
        }
    }

    private func handleList(options: CLIOptions) {
        if options.describe {
            output(CommandDescription.list, options: options)
            return
        }

        let providers = Database.shared.loadAllProviders()
        if options.outputMode == .json {
            output(CLIProviderSummary.makeList(from: providers, limit: options.limit, fields: options.fields), options: options)
            return
        }

        if providers.isEmpty {
            print("No providers configured.")
            return
        }

        for provider in providers.prefix(options.limit ?? providers.count) {
            let marker = provider.isActive ? "*" : " "
            print("\(marker) [\(provider.type.rawValue)] \(provider.name)")
            print("      ID: \(provider.id.uuidString.lowercased())")
            print("      Model: \(provider.model ?? "default")")
            print("      Base URL: \(provider.baseUrl)")
            print()
        }
    }

    private func handleSwitch(args: [String], options: CLIOptions) {
        if options.describe {
            output(CommandDescription.switchProvider, options: options)
            return
        }

        guard let providerId = args.first else {
            exitWithUsage(
                code: "missing_provider_id",
                usage: "ccmanager switch <provider-id>",
                suggestion: "Run 'ccmanager list --json --fields=id,name,type,active' to find a provider ID.",
                options: options
            )
        }

        guard let uuid = UUID(uuidString: providerId) else {
            exitWithError(
                CLIErrorPayload(
                    code: "invalid_provider_id",
                    message: "Invalid provider ID: \(providerId)",
                    input: ["provider_id": providerId],
                    retryable: false,
                    suggestion: "Provider IDs must be UUID strings from 'ccmanager list --json'."
                ),
                options: options
            )
        }

        guard let provider = Database.shared.getProvider(byId: uuid) else {
            exitWithProviderNotFound(providerId, options: options)
        }

        do {
            try Database.shared.setActiveProvider(id: uuid, type: provider.type)
            try ConfigWriter.shared.writeProviderToConfig(provider)
            output(
                ProviderMutationResult(status: "switched", provider: CLIProviderSummary.make(provider: provider)),
                text: "Switched to '\(provider.name)' (\(provider.type.rawValue))",
                options: options
            )
        } catch {
            exitWithError(
                CLIErrorPayload(
                    code: "switch_failed",
                    message: "Failed to switch provider: \(error.localizedDescription)",
                    input: ["provider_id": providerId],
                    retryable: false,
                    suggestion: "Check that CCManager can write the target CLI config files."
                ),
                options: options
            )
        }
    }

    private func handleAdd(args: [String], options: CLIOptions) {
        if options.describe {
            output(CommandDescription.add, options: options)
            return
        }

        var name: String?
        var type: ProviderType = .claudeCode
        var apiKey: String?
        var baseUrl: String?
        var model: String?

        var parser = OptionParser(args: args)
        while let token = parser.next() {
            switch token {
            case "-n", "--name":
                name = parser.requiredValue(for: token, options: options)
            case "-t", "--type":
                let rawType = parser.requiredValue(for: token, options: options)
                guard let parsedType = ProviderType(rawValue: rawType) else {
                    exitWithError(
                        CLIErrorPayload(
                            code: "invalid_provider_type",
                            message: "Invalid provider type: \(rawType)",
                            input: ["type": rawType],
                            retryable: false,
                            suggestion: "Use one of: Claude Code, Codex, Codex OAuth."
                        ),
                        options: options
                    )
                }
                type = parsedType
            case "-k", "--api-key":
                apiKey = parser.requiredValue(for: token, options: options)
            case "-u", "--url":
                baseUrl = parser.requiredValue(for: token, options: options)
            case "-m", "--model":
                model = parser.requiredValue(for: token, options: options)
            case "-h", "--help":
                printAddHelp()
                exit(0)
            default:
                if token.hasPrefix("-") {
                    exitWithUnknownOption(token, usage: "ccmanager add [options]", options: options)
                } else if name == nil {
                    name = token
                }
            }
        }

        guard let providerName = name, !providerName.isEmpty else {
            exitWithUsage(
                code: "missing_name",
                usage: "ccmanager add -n <name> -k <api-key> -u <base-url>",
                suggestion: "Pass -n or --name with a non-empty provider name.",
                options: options
            )
        }

        guard let key = apiKey, !key.isEmpty else {
            exitWithUsage(
                code: "missing_api_key",
                usage: "ccmanager add -n <name> -k <api-key> -u <base-url>",
                suggestion: "Pass -k or --api-key. OAuth providers are managed from the GUI.",
                options: options
            )
        }

        guard let url = baseUrl, !url.isEmpty else {
            exitWithUsage(
                code: "missing_base_url",
                usage: "ccmanager add -n <name> -k <api-key> -u <base-url>",
                suggestion: "Pass -u or --url with the provider API base URL.",
                options: options
            )
        }

        let provider = Provider(
            name: providerName,
            type: type,
            apiKey: key,
            baseUrl: url,
            model: model
        )

        do {
            try Database.shared.addProvider(provider)
            output(
                ProviderMutationResult(status: "added", provider: CLIProviderSummary.make(provider: provider)),
                text: "Added provider '\(providerName)' (ID: \(provider.id.uuidString.lowercased()))",
                options: options
            )
        } catch {
            exitWithError(
                CLIErrorPayload(
                    code: "add_failed",
                    message: "Failed to add provider: \(error.localizedDescription)",
                    input: ["name": providerName, "type": type.rawValue, "base_url": url],
                    retryable: false,
                    suggestion: "Check the local CCManager database is writable."
                ),
                options: options
            )
        }
    }

    private func handleEdit(args: [String], options: CLIOptions) {
        if options.describe {
            output(CommandDescription.edit, options: options)
            return
        }

        guard let providerId = args.first else {
            exitWithUsage(
                code: "missing_provider_id",
                usage: "ccmanager edit <provider-id> [options]",
                suggestion: "Run 'ccmanager list --json --fields=id,name,type,active' to find a provider ID.",
                options: options
            )
        }

        guard let uuid = UUID(uuidString: providerId) else {
            exitWithError(
                CLIErrorPayload(
                    code: "invalid_provider_id",
                    message: "Invalid provider ID: \(providerId)",
                    input: ["provider_id": providerId],
                    retryable: false,
                    suggestion: "Provider IDs must be UUID strings from 'ccmanager list --json'."
                ),
                options: options
            )
        }

        guard var provider = Database.shared.getProvider(byId: uuid) else {
            exitWithProviderNotFound(providerId, options: options)
        }

        var parser = OptionParser(args: Array(args.dropFirst()))
        while let token = parser.next() {
            switch token {
            case "-n", "--name":
                provider.name = parser.requiredValue(for: token, options: options)
            case "-k", "--api-key":
                provider.apiKey = parser.requiredValue(for: token, options: options)
            case "-u", "--url":
                provider.baseUrl = parser.requiredValue(for: token, options: options)
            case "-m", "--model":
                provider.model = parser.requiredValue(for: token, options: options)
            case "-h", "--help":
                printEditHelp()
                exit(0)
            default:
                if token.hasPrefix("-") {
                    exitWithUnknownOption(token, usage: "ccmanager edit <provider-id> [options]", options: options)
                }
            }
        }

        do {
            try Database.shared.updateProvider(provider)
            if provider.isActive {
                try ConfigWriter.shared.writeProviderToConfig(provider)
            }
            output(
                ProviderMutationResult(status: "updated", provider: CLIProviderSummary.make(provider: provider)),
                text: "Updated provider '\(provider.name)'",
                options: options
            )
        } catch {
            exitWithError(
                CLIErrorPayload(
                    code: "update_failed",
                    message: "Failed to update provider: \(error.localizedDescription)",
                    input: ["provider_id": providerId],
                    retryable: false,
                    suggestion: "Check the provider fields and local database permissions."
                ),
                options: options
            )
        }
    }

    private func handleDelete(args: [String], options: CLIOptions) {
        if options.describe {
            output(CommandDescription.delete, options: options)
            return
        }

        guard let providerId = args.first else {
            exitWithUsage(
                code: "missing_provider_id",
                usage: "ccmanager delete <provider-id>",
                suggestion: "Run 'ccmanager list --json --fields=id,name,type,active' to find a provider ID.",
                options: options
            )
        }

        guard let uuid = UUID(uuidString: providerId) else {
            exitWithError(
                CLIErrorPayload(
                    code: "invalid_provider_id",
                    message: "Invalid provider ID: \(providerId)",
                    input: ["provider_id": providerId],
                    retryable: false,
                    suggestion: "Provider IDs must be UUID strings from 'ccmanager list --json'."
                ),
                options: options
            )
        }

        guard let provider = Database.shared.getProvider(byId: uuid) else {
            exitWithProviderNotFound(providerId, options: options)
        }

        do {
            try Database.shared.deleteProvider(id: uuid)
            output(
                ProviderMutationResult(status: "deleted", provider: CLIProviderSummary.make(provider: provider)),
                text: "Deleted provider '\(provider.name)'",
                options: options
            )
        } catch {
            exitWithError(
                CLIErrorPayload(
                    code: "delete_failed",
                    message: "Failed to delete provider: \(error.localizedDescription)",
                    input: ["provider_id": providerId],
                    retryable: false,
                    suggestion: "Check the local CCManager database is writable."
                ),
                options: options
            )
        }
    }

    private func handleActive(options: CLIOptions) {
        if options.describe {
            output(CommandDescription.active, options: options)
            return
        }

        let providers = Database.shared.loadAllProviders().filter { $0.isActive }
        if options.outputMode == .json {
            output(CLIProviderSummary.makeList(from: providers, limit: options.limit, fields: options.fields), options: options)
            return
        }

        if providers.isEmpty {
            print("No active provider.")
            return
        }

        for provider in providers.prefix(options.limit ?? providers.count) {
            print("\(provider.type.rawValue): \(provider.name) (ID: \(provider.id.uuidString.lowercased()))")
            print("  Model: \(provider.model ?? "default")")
            print("  URL: \(provider.baseUrl)")
        }
    }

    private func handleTest(args: [String], options: CLIOptions) {
        if options.describe {
            output(CommandDescription.test, options: options)
            return
        }

        guard let providerId = args.first else {
            exitWithUsage(
                code: "missing_provider_id",
                usage: "ccmanager test <provider-id>",
                suggestion: "Run 'ccmanager list --json --fields=id,name,type,active' to find a provider ID.",
                options: options
            )
        }

        guard let uuid = UUID(uuidString: providerId) else {
            exitWithError(
                CLIErrorPayload(
                    code: "invalid_provider_id",
                    message: "Invalid provider ID: \(providerId)",
                    input: ["provider_id": providerId],
                    retryable: false,
                    suggestion: "Provider IDs must be UUID strings from 'ccmanager list --json'."
                ),
                options: options
            )
        }

        guard let provider = Database.shared.getProvider(byId: uuid) else {
            exitWithProviderNotFound(providerId, options: options)
        }

        if options.outputMode == .text {
            print("Testing '\(provider.name)'... ", terminator: "")
        }

        let semaphore = DispatchSemaphore(value: 0)
        var result: TestResult = .failure("Timed out")

        Task {
            result = await ProviderTester.shared.test(provider: provider)
            semaphore.signal()
        }

        let waitResult = semaphore.wait(timeout: .now() + 30)
        if waitResult == .timedOut {
            result = .failure("Timed out")
        }

        switch result {
        case .success:
            output(
                ProviderTestResult(status: "success", provider: CLIProviderSummary.make(provider: provider), message: nil),
                text: "Success",
                options: options
            )
        case .failure(let message):
            if options.outputMode == .text {
                print("Failed: \(message)")
            }
            exitWithError(
                CLIErrorPayload(
                    code: message == "Timed out" ? "test_timeout" : "test_failed",
                    message: "Provider test failed: \(message)",
                    input: ["provider_id": providerId],
                    retryable: message == "Timed out",
                    suggestion: "Verify the API key, base URL, model, and network connectivity."
                ),
                options: options
            )
        }
    }

    private func printHelp() {
        print("""
        Usage: ccmanager <command> [options]

        Commands:
          list              List providers
          active            Show active providers
          switch <id>       Switch active provider
          add [options]     Add provider
          edit <id> [opts]  Edit provider
          delete <id>       Delete provider
          test <id>         Test provider connection
          help              Show help

        Global options:
          --json            Output JSON
          --fields <list>   Comma-separated fields for list output
          --limit <number>  Limit list output
          --describe        Output command schema as JSON
          -h, --help        Show help

        Examples:
          ccmanager list --json --fields=id,name,type,active
          ccmanager switch 550e8400-e29b-41d4-a716-446655440000 --json
          ccmanager add -n "OpenAI" -t "Codex" -k "sk-..." -u "https://api.openai.com/v1" --json
        """)
    }

    private func printAddHelp() {
        print("""
        Usage: ccmanager add [options]

        Options:
          -n, --name <name>       Provider name [required]
          -t, --type <type>       Provider type: Claude Code|Codex|Codex OAuth [default: Claude Code]
          -k, --api-key <key>     API key [required]
          -u, --url <url>         Base URL [required]
          -m, --model <model>     Model name
          --json                  Output JSON
          --describe              Output command schema as JSON
          -h, --help              Show help
        """)
    }

    private func printEditHelp() {
        print("""
        Usage: ccmanager edit <provider-id> [options]

        Options:
          -n, --name <name>       New provider name
          -k, --api-key <key>     New API key
          -u, --url <url>         New base URL
          -m, --model <model>     New model name
          --json                  Output JSON
          --describe              Output command schema as JSON
          -h, --help              Show help
        """)
    }
}

private struct CLIOptions {
    let command: String?
    let commandArgs: [String]
    let outputMode: CLIOutputMode
    let fields: [String]?
    let limit: Int?
    let describe: Bool

    init(arguments: [String]) {
        var remaining: [String] = []
        var jsonFlag = false
        var parsedFields: [String]?
        var parsedLimit: Int?
        var parsedDescribe = false

        var index = 0
        while index < arguments.count {
            let arg = arguments[index]
            if arg == "--json" {
                jsonFlag = true
            } else if arg == "--describe" {
                parsedDescribe = true
                jsonFlag = true
            } else if arg == "--fields", index + 1 < arguments.count {
                index += 1
                parsedFields = CLIOptions.parseFields(arguments[index])
            } else if arg.hasPrefix("--fields=") {
                parsedFields = CLIOptions.parseFields(String(arg.dropFirst("--fields=".count)))
            } else if arg == "--limit", index + 1 < arguments.count {
                index += 1
                parsedLimit = Int(arguments[index])
            } else if arg.hasPrefix("--limit=") {
                parsedLimit = Int(String(arg.dropFirst("--limit=".count)))
            } else {
                remaining.append(arg)
            }
            index += 1
        }

        self.command = remaining.first
        self.commandArgs = Array(remaining.dropFirst())
        self.outputMode = CLIOutputMode(jsonFlag: jsonFlag, stdoutIsTTY: isatty(STDOUT_FILENO) == 1)
        self.fields = parsedFields
        self.limit = parsedLimit
        self.describe = parsedDescribe
    }

    private static func parseFields(_ value: String) -> [String] {
        value.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

private struct OptionParser {
    private let args: [String]
    private var index = 0

    init(args: [String]) {
        self.args = args
    }

    mutating func next() -> String? {
        guard index < args.count else { return nil }
        defer { index += 1 }
        return args[index]
    }

    mutating func requiredValue(for option: String, options: CLIOptions) -> String {
        guard index < args.count, !args[index].hasPrefix("-") else {
            exitWithError(
                CLIErrorPayload(
                    code: "missing_option_value",
                    message: "Missing value for option: \(option)",
                    input: ["option": option],
                    retryable: false,
                    suggestion: "Run 'ccmanager \(options.command ?? "help") --help' for command options."
                ),
                options: options
            )
        }
        defer { index += 1 }
        return args[index]
    }
}

private struct ProviderMutationResult: Encodable {
    let status: String
    let provider: [String: CLIJSONValue]
}

private struct ProviderTestResult: Encodable {
    let status: String
    let provider: [String: CLIJSONValue]
    let message: String?
}

private struct CommandDescription: Encodable {
    let command: String
    let usage: String
    let parameters: [Parameter]
    let output: String
    let riskTier: String

    struct Parameter: Encodable {
        let name: String
        let type: String
        let required: Bool
        let values: [String]?
        let defaultValue: String?
    }

    static let list = CommandDescription(
        command: "list",
        usage: "ccmanager list [--json] [--fields <list>] [--limit <number>]",
        parameters: [
            .init(name: "json", type: "boolean", required: false, values: nil, defaultValue: "false"),
            .init(name: "fields", type: "string", required: false, values: CLIProviderSummary.defaultFields, defaultValue: nil),
            .init(name: "limit", type: "integer", required: false, values: nil, defaultValue: nil)
        ],
        output: "Array of provider summaries.",
        riskTier: "low"
    )

    static let active = CommandDescription(
        command: "active",
        usage: "ccmanager active [--json] [--fields <list>] [--limit <number>]",
        parameters: list.parameters,
        output: "Array of active provider summaries.",
        riskTier: "low"
    )

    static let switchProvider = CommandDescription(
        command: "switch",
        usage: "ccmanager switch <provider-id> [--json]",
        parameters: [
            .init(name: "provider-id", type: "uuid", required: true, values: nil, defaultValue: nil),
            .init(name: "json", type: "boolean", required: false, values: nil, defaultValue: "false")
        ],
        output: "Mutation status and provider summary.",
        riskTier: "medium"
    )

    static let add = CommandDescription(
        command: "add",
        usage: "ccmanager add -n <name> -k <api-key> -u <base-url> [options] [--json]",
        parameters: [
            .init(name: "name", type: "string", required: true, values: nil, defaultValue: nil),
            .init(name: "type", type: "string", required: false, values: ProviderType.allCases.map(\.rawValue), defaultValue: ProviderType.claudeCode.rawValue),
            .init(name: "api-key", type: "string", required: true, values: nil, defaultValue: nil),
            .init(name: "url", type: "string", required: true, values: nil, defaultValue: nil),
            .init(name: "model", type: "string", required: false, values: nil, defaultValue: nil),
            .init(name: "json", type: "boolean", required: false, values: nil, defaultValue: "false")
        ],
        output: "Mutation status and provider summary.",
        riskTier: "medium"
    )

    static let edit = CommandDescription(
        command: "edit",
        usage: "ccmanager edit <provider-id> [options] [--json]",
        parameters: [
            .init(name: "provider-id", type: "uuid", required: true, values: nil, defaultValue: nil),
            .init(name: "name", type: "string", required: false, values: nil, defaultValue: nil),
            .init(name: "api-key", type: "string", required: false, values: nil, defaultValue: nil),
            .init(name: "url", type: "string", required: false, values: nil, defaultValue: nil),
            .init(name: "model", type: "string", required: false, values: nil, defaultValue: nil),
            .init(name: "json", type: "boolean", required: false, values: nil, defaultValue: "false")
        ],
        output: "Mutation status and provider summary.",
        riskTier: "medium"
    )

    static let delete = CommandDescription(
        command: "delete",
        usage: "ccmanager delete <provider-id> [--json]",
        parameters: switchProvider.parameters,
        output: "Mutation status and deleted provider summary.",
        riskTier: "medium"
    )

    static let test = CommandDescription(
        command: "test",
        usage: "ccmanager test <provider-id> [--json]",
        parameters: switchProvider.parameters,
        output: "Test status and provider summary.",
        riskTier: "low"
    )
}

private func output<T: Encodable>(_ value: T, text: String? = nil, options: CLIOptions) {
    if options.outputMode == .json {
        let encoder = makeJSONEncoder()
        do {
            let data = try encoder.encode(value)
            print(String(data: data, encoding: .utf8) ?? "{}")
        } catch {
            FileHandle.standardError.write("Error [json_encode_failed]: \(error.localizedDescription)\n".data(using: .utf8)!)
            exit(1)
        }
    } else if let text {
        print(text)
    }
}

private func exitWithUsage(code: String, usage: String, suggestion: String, options: CLIOptions) -> Never {
    exitWithError(
        CLIErrorPayload(
            code: code,
            message: "Usage: \(usage)",
            input: nil,
            retryable: false,
            suggestion: suggestion
        ),
        options: options
    )
}

private func exitWithUnknownOption(_ option: String, usage: String, options: CLIOptions) -> Never {
    exitWithError(
        CLIErrorPayload(
            code: "unknown_option",
            message: "Unknown option: \(option)",
            input: ["option": option],
            retryable: false,
            suggestion: "Usage: \(usage)"
        ),
        options: options
    )
}

private func exitWithProviderNotFound(_ providerId: String, options: CLIOptions) -> Never {
    exitWithError(
        CLIErrorPayload(
            code: "provider_not_found",
            message: "Provider not found: \(providerId)",
            input: ["provider_id": providerId],
            retryable: false,
            suggestion: "Run 'ccmanager list --json --fields=id,name,type,active' to see available providers."
        ),
        options: options
    )
}

private func exitWithError(_ error: CLIErrorPayload, options: CLIOptions) -> Never {
    if options.outputMode == .json {
        let encoder = makeJSONEncoder()
        let data = try? encoder.encode(CLIErrorEnvelope(error: error))
        FileHandle.standardError.write((String(data: data ?? Data(), encoding: .utf8) ?? "{\"error\":{\"code\":\"unknown\"}}").appending("\n").data(using: .utf8)!)
    } else {
        FileHandle.standardError.write("Error [\(error.code)]: \(error.message)\n".data(using: .utf8)!)
        if let suggestion = error.suggestion {
            FileHandle.standardError.write("Hint: \(suggestion)\n".data(using: .utf8)!)
        }
    }
    exit(Int32(error.exitCode))
}

private func makeJSONEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.keyEncodingStrategy = .convertToSnakeCase
    return encoder
}
