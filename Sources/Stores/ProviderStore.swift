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

    static func providers(
        _ providers: [Provider],
        moving sourceId: UUID,
        to targetId: UUID,
        inGroup groupType: ProviderType?
    ) -> [Provider] {
        guard sourceId != targetId else { return providers }

        let scopedProviders: [Provider]
        if let groupType {
            scopedProviders = providers
                .filter { provider in provider.belongsToReorderGroup(groupType) }
                .sorted { $0.sortOrder < $1.sortOrder }
        } else {
            scopedProviders = providers
        }

        guard
            let sourceIndex = scopedProviders.firstIndex(where: { $0.id == sourceId }),
            let targetIndex = scopedProviders.firstIndex(where: { $0.id == targetId })
        else {
            return providers
        }

        var reorderedScopedProviders = scopedProviders
        reorderedScopedProviders.move(
            fromOffsets: IndexSet(integer: sourceIndex),
            toOffset: targetIndex > sourceIndex ? targetIndex + 1 : targetIndex
        )

        for index in reorderedScopedProviders.indices {
            reorderedScopedProviders[index].sortOrder = index
        }

        guard let groupType else {
            return reorderedScopedProviders
        }

        var output = providers
        var scopedIterator = reorderedScopedProviders.makeIterator()
        for index in output.indices where output[index].belongsToReorderGroup(groupType) {
            if let provider = scopedIterator.next() {
                output[index] = provider
            }
        }
        return output
    }

    static func providersWithChangedSortOrder(from oldProviders: [Provider], to newProviders: [Provider]) -> [Provider] {
        newProviders.filter { provider in
            oldProviders.first(where: { $0.id == provider.id })?.sortOrder != provider.sortOrder
        }
    }

    func moveProvider(from source: IndexSet, to destination: Int, inGroup groupType: ProviderType? = nil) {
        let scopedProviders = groupType.map { group in
            providers.filter { $0.belongsToReorderGroup(group) }.sorted { $0.sortOrder < $1.sortOrder }
        } ?? providers
        guard
            let sourceIndex = source.first,
            scopedProviders.indices.contains(sourceIndex)
        else { return }

        let boundedDestination = max(0, min(destination, scopedProviders.count - 1))
        let targetProvider = scopedProviders[boundedDestination]
        moveProvider(moving: scopedProviders[sourceIndex].id, to: targetProvider.id, inGroup: groupType)
    }

    func moveProvider(moving sourceId: UUID, to targetId: UUID, inGroup groupType: ProviderType? = nil) {
        let oldProviders = providers
        let reorderedProviders = Self.providers(providers, moving: sourceId, to: targetId, inGroup: groupType)
        guard reorderedProviders != oldProviders else { return }

        providers = reorderedProviders
        persistProviderSortOrderChanges(from: oldProviders)
    }

    func previewMoveProvider(moving sourceId: UUID, to targetId: UUID, inGroup groupType: ProviderType? = nil) {
        let reorderedProviders = Self.providers(providers, moving: sourceId, to: targetId, inGroup: groupType)
        guard reorderedProviders != providers else { return }

        providers = reorderedProviders
    }

    func persistProviderSortOrderChanges(from oldProviders: [Provider]) {
        let changedProviders = Self.providersWithChangedSortOrder(from: oldProviders, to: providers)
        guard !changedProviders.isEmpty else { return }

        database.updateProviderSortOrders(changedProviders) { result in
            if case let .failure(error) = result {
                print("Move provider error: \(error)")
            }
        }
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

private extension Provider {
    func belongsToReorderGroup(_ groupType: ProviderType) -> Bool {
        switch groupType {
        case .claudeCode:
            return type == .claudeCode
        case .codex, .codexOAuth:
            return type == .codex || type == .codexOAuth
        }
    }
}
