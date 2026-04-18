import Foundation
import SQLite

// MARK: - CLI Entry Point

let cli = CCManagerCLI()
cli.run()

// MARK: - CLI Implementation
// Reuses ProviderStore, ConfigWriter, ProviderTester from GUI

struct CCManagerCLI {
    func run() {
        let args = Array(CommandLine.arguments.dropFirst()) // Drop program name

        guard let command = args.first else {
            printHelp()
            exit(0)
        }

        switch command {
        case "list":
            handleList()
        case "switch":
            handleSwitch(args: Array(args.dropFirst()))
        case "add":
            handleAdd(args: Array(args.dropFirst()))
        case "edit":
            handleEdit(args: Array(args.dropFirst()))
        case "delete":
            handleDelete(args: Array(args.dropFirst()))
        case "active":
            handleActive()
        case "test":
            handleTest(args: Array(args.dropFirst()))
        case "-h", "--help", "help":
            printHelp()
        default:
            printError("Unknown command: \(command)")
            printHelp()
            exit(1)
        }
    }

    // MARK: - Commands

    private func handleList() {
        let providers = Database.shared.loadAllProviders()

        if providers.isEmpty {
            print("No providers configured.")
            return
        }

        for provider in providers {
            let marker = provider.isActive ? "✓" : " "
            let typeStr = provider.type.rawValue
            print("\(marker) [\(typeStr)] \(provider.name)")
            print("      ID: \(provider.id)")
            print("      Model: \(provider.model ?? "default")")
            print("      Base URL: \(provider.baseUrl)")
            print()
        }
    }

    private func handleSwitch(args: [String]) {
        guard let providerId = args.first else {
            printError("Usage: ccmanager switch <provider-id>")
            exit(1)
        }

        guard let uuid = UUID(uuidString: providerId) else {
            printError("Invalid provider ID: \(providerId)")
            exit(1)
        }

        guard let provider = Database.shared.getProvider(byId: uuid) else {
            printError("Provider not found: \(providerId)")
            exit(1)
        }

        do {
            try Database.shared.setActiveProvider(id: uuid, type: provider.type)
            try ConfigWriter.shared.writeProviderToConfig(provider)
            print("Switched to '\(provider.name)' (\(provider.type.rawValue))")
        } catch {
            printError("Failed to switch provider: \(error.localizedDescription)")
            exit(1)
        }
    }

    private func handleAdd(args: [String]) {
        // Parse arguments
        var name: String?
        var type: ProviderType = .claudeCode
        var apiKey: String?
        var baseUrl: String?
        var model: String?

        var i = 0
        while i < args.count {
            switch args[i] {
            case "-n", "--name":
                i += 1
                name = args[i]
            case "-t", "--type":
                i += 1
                type = ProviderType(rawValue: args[i]) ?? .claudeCode
            case "-k", "--api-key":
                i += 1
                apiKey = args[i]
            case "-u", "--url":
                i += 1
                baseUrl = args[i]
            case "-m", "--model":
                i += 1
                model = args[i]
            case "-h", "--help":
                printAddHelp()
                exit(0)
            default:
                if args[i].hasPrefix("-") {
                    printError("Unknown option: \(args[i])")
                    printAddHelp()
                    exit(1)
                } else if name == nil {
                    name = args[i]
                }
            }
            i += 1
        }

        // Validate required fields
        guard let providerName = name, !providerName.isEmpty else {
            printError("Name is required (use -n or --name)")
            printAddHelp()
            exit(1)
        }

        guard let key = apiKey, !key.isEmpty else {
            printError("API key is required (use -k or --api-key)")
            printAddHelp()
            exit(1)
        }

        guard let url = baseUrl, !url.isEmpty else {
            printError("Base URL is required (use -u or --url)")
            printAddHelp()
            exit(1)
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
            print("Added provider '\(providerName)' (ID: \(provider.id))")
        } catch {
            printError("Failed to add provider: \(error.localizedDescription)")
            exit(1)
        }
    }

    private func handleEdit(args: [String]) {
        guard let providerId = args.first else {
            printError("Usage: ccmanager edit <provider-id> [options]")
            exit(1)
        }

        guard let uuid = UUID(uuidString: providerId) else {
            printError("Invalid provider ID: \(providerId)")
            exit(1)
        }

        guard var provider = Database.shared.getProvider(byId: uuid) else {
            printError("Provider not found: \(providerId)")
            exit(1)
        }

        // Parse options to update
        let updateArgs = Array(args.dropFirst())
        var i = 0
        while i < updateArgs.count {
            switch updateArgs[i] {
            case "-n", "--name":
                i += 1
                provider.name = updateArgs[i]
            case "-k", "--api-key":
                i += 1
                provider.apiKey = updateArgs[i]
            case "-u", "--url":
                i += 1
                provider.baseUrl = updateArgs[i]
            case "-m", "--model":
                i += 1
                provider.model = updateArgs[i]
            case "-h", "--help":
                printEditHelp()
                exit(0)
            default:
                if updateArgs[i].hasPrefix("-") {
                    printError("Unknown option: \(updateArgs[i])")
                    printEditHelp()
                    exit(1)
                }
            }
            i += 1
        }

        do {
            try Database.shared.updateProvider(provider)

            // If this provider is active, also update the config file
            if provider.isActive {
                try ConfigWriter.shared.writeProviderToConfig(provider)
            }

            print("Updated provider '\(provider.name)'")
        } catch {
            printError("Failed to update provider: \(error.localizedDescription)")
            exit(1)
        }
    }

    private func handleDelete(args: [String]) {
        guard let providerId = args.first else {
            printError("Usage: ccmanager delete <provider-id>")
            exit(1)
        }

        guard let uuid = UUID(uuidString: providerId) else {
            printError("Invalid provider ID: \(providerId)")
            exit(1)
        }

        guard let provider = Database.shared.getProvider(byId: uuid) else {
            printError("Provider not found: \(providerId)")
            exit(1)
        }

        do {
            try Database.shared.deleteProvider(id: uuid)
            print("Deleted provider '\(provider.name)'")
        } catch {
            printError("Failed to delete provider: \(error.localizedDescription)")
            exit(1)
        }
    }

    private func handleActive() {
        let providers = Database.shared.loadAllProviders()
        let activeProviders = providers.filter { $0.isActive }

        if activeProviders.isEmpty {
            print("No active provider.")
            return
        }

        for provider in activeProviders {
            print("\(provider.type.rawValue): \(provider.name) (ID: \(provider.id))")
            print("  Model: \(provider.model ?? "default")")
            print("  URL: \(provider.baseUrl)")
        }
    }

    private func handleTest(args: [String]) {
        guard let providerId = args.first else {
            printError("Usage: ccmanager test <provider-id>")
            exit(1)
        }

        guard let uuid = UUID(uuidString: providerId) else {
            printError("Invalid provider ID: \(providerId)")
            exit(1)
        }

        guard let provider = Database.shared.getProvider(byId: uuid) else {
            printError("Provider not found: \(providerId)")
            exit(1)
        }

        print("Testing '\(provider.name)'... ", terminator: "")

        let semaphore = DispatchSemaphore(value: 0)
        var result: TestResult = .failure("Timed out")

        Task {
            result = await ProviderTester.shared.test(provider: provider)
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 30)

        switch result {
        case .success:
            print("✓ Success")
        case .failure(let message):
            print("✗ Failed: \(message)")
            exit(1)
        }
    }

    // MARK: - Help

    private func printHelp() {
        print("""
        CCManager CLI - Manage Claude Code/Codex providers

        Usage: ccmanager <command> [options]

        Commands:
          list              List all providers
          switch <id>      Switch active provider by ID
          add [options]     Add a new provider
          edit <id> [opts]  Edit an existing provider
          delete <id>       Delete a provider
          active            Show currently active providers
          test <id>         Test a provider connection
          help              Show this help message

        Examples:
          ccmanager list
          ccmanager switch 550e8400-e29b-41d4-a716-446655440000
          ccmanager add -n "My Provider" -t "Claude Code" -k "sk-..." -u "https://api.example.com"
          ccmanager edit 550e8400-e29b-41d4-a716-446655440000 -n "New Name"
          ccmanager delete 550e8400-e29b-41d4-a716-446655440000
          ccmanager test 550e8400-e29b-41d4-a716-446655440000

        For more options on a specific command:
          ccmanager <command> --help
        """)
    }

    private func printAddHelp() {
        print("""
        Usage: ccmanager add [options]

        Options:
          -n, --name <name>       Provider name (required)
          -t, --type <type>       Provider type: "Claude Code" or "Codex" (default: Claude Code)
          -k, --api-key <key>     API key (required)
          -u, --url <url>         Base URL (required)
          -m, --model <model>     Model name (optional)
          -h, --help              Show this help message

        Examples:
          ccmanager add -n "MiniMax" -t "Claude Code" -k "sk-xxx" -u "https://api.minimax.com" -m "MiniMax-M2.7"
          ccmanager add -n "OpenAI" -t "Codex" -k "sk-xxx" -u "https://api.openai.com" -m "gpt-5.4"
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
          -h, --help              Show this help message

        Examples:
          ccmanager edit 550e8400-e29b-41d4-a716-446655440000 -n "New Name"
          ccmanager edit 550e8400-e29b-41d4-a716-446655440000 -k "new-key" -u "https://new-url.com"
        """)
    }

    private func printError(_ message: String) {
        FileHandle.standardError.write("Error: \(message)\n".data(using: .utf8)!)
    }
}
