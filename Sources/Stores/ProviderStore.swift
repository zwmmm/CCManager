import Foundation
import SQLite

final class ProviderStore: ObservableObject {
    static let shared = ProviderStore()

    @Published var providers: [Provider] = []
    @Published var activeProvider: Provider?
    @Published var importProgress: Double? = nil
    @Published var exportProgress: Double? = nil

    private var db: Connection?
    private let dbQueue = DispatchQueue(label: "com.ccmanager.database")

    // Table definition
    private let providersTable = Table("providers")
    private let idColumn = Expression<String>("id")
    private let nameColumn = Expression<String>("name")
    private let typeColumn = Expression<String>("type")
    private let apiKeyColumn = Expression<String>("api_key")
    private let baseUrlColumn = Expression<String>("base_url")
    private let modelColumn = Expression<String?>("model")
    private let isActiveColumn = Expression<Bool>("is_active")
    private let sortOrderColumn = Expression<Int>("sort_order")

    private init() {
        setupDatabase()
        loadProviders()
    }

    private func setupDatabase() {
        do {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appFolder = appSupport.appendingPathComponent("CCManager", isDirectory: true)
            try FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
            let dbPath = appFolder.appendingPathComponent("providers.sqlite").path

            db = try Connection(dbPath)
            try createTable()
        } catch {
            print("Database setup error: \(error)")
        }
    }

    private func createTable() throws {
        try db?.run(providersTable.create(ifNotExists: true) { t in
            t.column(idColumn, primaryKey: true)
            t.column(nameColumn)
            t.column(typeColumn)
            t.column(apiKeyColumn)
            t.column(baseUrlColumn)
            t.column(modelColumn)
            t.column(isActiveColumn, defaultValue: false)
            t.column(sortOrderColumn, defaultValue: 0)
        })
        // 迁移：检查列是否存在再添加（避免每次启动报错）
        if let stmt = try db?.prepare("PRAGMA table_info(providers)") {
            var hasModel = false
            for row in stmt {
                // PRAGMA table_info returns: cid, name, type, notnull, dflt_value, pk
                // Column 1 is "name"
                if let nameCol = row[1] as? String, nameCol == "model" {
                    hasModel = true
                    break
                }
            }
            if !hasModel {
                try db?.run(providersTable.addColumn(modelColumn))
            }
        }
    }

    func loadProviders() {
        dbQueue.sync {
            guard let db = db else { return }
            do {
                var loadedProviders: [Provider] = []
                for row in try db.prepare(providersTable.order(sortOrderColumn.asc)) {
                    let provider = Provider(
                        id: UUID(uuidString: row[idColumn]) ?? UUID(),
                        name: row[nameColumn],
                        type: ProviderType(rawValue: row[typeColumn]) ?? .claudeCode,
                        apiKey: row[apiKeyColumn],
                        baseUrl: row[baseUrlColumn],
                        model: row[modelColumn],
                        isActive: row[isActiveColumn],
                        sortOrder: row[sortOrderColumn]
                    )
                    loadedProviders.append(provider)
                }
                DispatchQueue.main.async {
                    self.providers = loadedProviders
                    self.activeProvider = loadedProviders.first { $0.isActive }
                }
            } catch {
                print("Load providers error: \(error)")
            }
        }
    }

    func addProvider(_ provider: Provider) {
        dbQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            do {
                try db.run(self.providersTable.insert(
                    self.idColumn <- provider.id.uuidString,
                    self.nameColumn <- provider.name,
                    self.typeColumn <- provider.type.rawValue,
                    self.apiKeyColumn <- provider.apiKey,
                    self.baseUrlColumn <- provider.baseUrl,
                    self.modelColumn <- provider.model,
                    self.isActiveColumn <- provider.isActive,
                    self.sortOrderColumn <- provider.sortOrder
                ))
                DispatchQueue.main.async {
                    self.loadProviders()
                }
            } catch {
                print("Add provider error: \(error)")
            }
        }
    }

    func updateProvider(_ provider: Provider) {
        dbQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            do {
                let row = self.providersTable.filter(self.idColumn == provider.id.uuidString)
                try db.run(row.update(
                    self.nameColumn <- provider.name,
                    self.typeColumn <- provider.type.rawValue,
                    self.apiKeyColumn <- provider.apiKey,
                    self.baseUrlColumn <- provider.baseUrl,
                    self.modelColumn <- provider.model,
                    self.isActiveColumn <- provider.isActive,
                    self.sortOrderColumn <- provider.sortOrder
                ))
                DispatchQueue.main.async {
                    self.loadProviders()
                }
            } catch {
                print("Update provider error: \(error)")
            }
        }
    }

    func deleteProvider(_ provider: Provider) {
        dbQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            do {
                let row = self.providersTable.filter(self.idColumn == provider.id.uuidString)
                try db.run(row.delete())
                DispatchQueue.main.async {
                    self.loadProviders()
                }
            } catch {
                print("Delete provider error: \(error)")
            }
        }
    }

    func setActiveProvider(_ provider: Provider) {
        dbQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            do {
                // Deactivate all providers of the same type
                try db.run(self.providersTable.filter(self.typeColumn == provider.type.rawValue).update(self.isActiveColumn <- false))
                // Activate selected
                let row = self.providersTable.filter(self.idColumn == provider.id.uuidString)
                try db.run(row.update(self.isActiveColumn <- true))
                DispatchQueue.main.async {
                    self.loadProviders()
                }
            } catch {
                print("Set active provider error: \(error)")
            }
        }
    }

    func moveProvider(from source: IndexSet, to destination: Int) {
        var reorderedProviders = providers
        reorderedProviders.move(fromOffsets: source, toOffset: destination)

        dbQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            do {
                for (index, provider) in reorderedProviders.enumerated() {
                    let row = self.providersTable.filter(self.idColumn == provider.id.uuidString)
                    try db.run(row.update(self.sortOrderColumn <- index))
                }
                DispatchQueue.main.async {
                    self.loadProviders()
                }
            } catch {
                print("Move provider error: \(error)")
            }
        }
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
}
