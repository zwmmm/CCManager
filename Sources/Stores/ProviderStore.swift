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

    func moveProvider(from source: IndexSet, to destination: Int) {
        var reorderedProviders = providers
        reorderedProviders.move(fromOffsets: source, toOffset: destination)

        for (index, provider) in reorderedProviders.enumerated() {
            var updated = provider
            updated.sortOrder = index
            do {
                try database.updateProvider(updated)
            } catch {
                print("Move provider error: \(error)")
            }
        }
        loadProviders()
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
