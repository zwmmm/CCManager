import Foundation
import SQLite

/// ProviderStore for GUI - wraps Database and adds ObservableObject support.
/// Uses Database.shared for actual storage operations (code reuse with CLI).
final class ProviderStore: ObservableObject {
    static let shared = ProviderStore()

    @Published var providers: [Provider] = []
    @Published var activeProvider: Provider?
    @Published var importProgress: Double? = nil
    @Published var exportProgress: Double? = nil

    private let database = Database.shared

    private init() {
        loadProviders()
    }

    func loadProviders() {
        let loadedProviders = database.loadAllProviders()
        providers = loadedProviders
        activeProvider = loadedProviders.first { $0.isActive }
    }

    func addProvider(_ provider: Provider) {
        do {
            try database.addProvider(provider)
            loadProviders()
        } catch {
            print("Add provider error: \(error)")
        }
    }

    func updateProvider(_ provider: Provider) {
        do {
            try database.updateProvider(provider)
            loadProviders()
        } catch {
            print("Update provider error: \(error)")
        }
    }

    func deleteProvider(_ provider: Provider) {
        do {
            try database.deleteProvider(id: provider.id)
            loadProviders()
        } catch {
            print("Delete provider error: \(error)")
        }
    }

    func setActiveProvider(_ provider: Provider) {
        do {
            try database.setActiveProvider(id: provider.id, type: provider.type)
            loadProviders()
        } catch {
            print("Set active provider error: \(error)")
        }
    }

    // MARK: - Provider Access Helpers

    func providers(ofType type: ProviderType) -> [Provider] {
        providers.filter { $0.type == type }.sorted { $0.sortOrder < $1.sortOrder }
    }

    func moveProvider(from source: IndexSet, to destination: Int, inGroup groupType: ProviderType? = nil) {
        if let groupType = groupType {
            // 分组模式：只移动同 groupType 的 provider
            var groupProviders = providers(ofType: groupType)
            groupProviders.move(fromOffsets: source, toOffset: destination)

            // Update sortOrder for moved providers (O(n) - using direct index lookup)
            let movedIds = Set(source.map { groupProviders[$0] }.map { $0.id })
            for (index, provider) in groupProviders.enumerated() {
                if let idx = providers.firstIndex(where: { $0.id == provider.id }) {
                    providers[idx].sortOrder = index
                }
            }

            // Write only affected providers to DB
            for provider in groupProviders where movedIds.contains(provider.id) {
                if let idx = providers.firstIndex(where: { $0.id == provider.id }) {
                    do {
                        try database.updateProvider(providers[idx])
                    } catch {
                        print("Move provider error: \(error)")
                    }
                }
            }
        } else {
            // 扁平模式：全量移动
            var reorderedProviders = providers
            reorderedProviders.move(fromOffsets: source, toOffset: destination)

            // Update sortOrder for all (O(n) - reorderedProviders order matches providers index)
            let movedIds = Set(source.map { reorderedProviders[$0] }.map { $0.id })
            for (index, provider) in reorderedProviders.enumerated() {
                if let idx = providers.firstIndex(where: { $0.id == provider.id }) {
                    providers[idx].sortOrder = index
                }
            }

            // Write only affected providers to DB
            for provider in reorderedProviders where movedIds.contains(provider.id) {
                if let idx = providers.firstIndex(where: { $0.id == provider.id }) {
                    do {
                        try database.updateProvider(providers[idx])
                    } catch {
                        print("Move provider error: \(error)")
                    }
                }
            }
        }

        objectWillChange.send()
    }

    func reassignSortOrderOnGroupingEnabled() {
        var claudeCodeOrder = 0
        var codexOrder = 0

        // Single pass: update sortOrder and track affected providers
        var affectedProviders: [Provider] = []

        for provider in providers.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            switch provider.type {
            case .claudeCode:
                if let idx = providers.firstIndex(where: { $0.id == provider.id }) {
                    providers[idx].sortOrder = claudeCodeOrder
                    affectedProviders.append(providers[idx])
                    claudeCodeOrder += 1
                }
            case .codex:
                if let idx = providers.firstIndex(where: { $0.id == provider.id }) {
                    providers[idx].sortOrder = codexOrder
                    affectedProviders.append(providers[idx])
                    codexOrder += 1
                }
            case .codexOAuth:
                if let idx = providers.firstIndex(where: { $0.id == provider.id }) {
                    providers[idx].sortOrder = codexOrder
                    affectedProviders.append(providers[idx])
                    codexOrder += 1
                }
            }
        }

        // Write only affected providers to DB
        for provider in affectedProviders {
            do {
                try database.updateProvider(provider)
            } catch {
                print("Reassign sort order error: \(error)")
            }
        }

        objectWillChange.send()
    }

    // MARK: - Import/Export

    func exportProviders(to url: URL) async throws -> Int {
        let data = try JSONEncoder().encode(self.providers)
        try data.write(to: url)
        return providers.count
    }

    func importProviders(from url: URL) async throws -> Int {
        let data = try Data(contentsOf: url)
        let imported = try JSONDecoder().decode([Provider].self, from: data)

        for provider in imported {
            if self.providers.contains(where: { $0.id == provider.id }) {
                self.updateProvider(provider)
            } else {
                self.addProvider(provider)
            }
        }

        return imported.count
    }

    // MARK: - CLI Test Support

    func testProvider(_ provider: Provider) async -> TestResult {
        return await ProviderTester.shared.test(provider: provider)
    }
}
