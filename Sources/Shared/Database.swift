import Foundation
import SQLite

/// Shared database layer for Provider storage.
/// Both GUI and CLI use this same SQLite database.
final class Database {
    static let shared = Database()

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
    private let thinkingModelColumn = Expression<String?>("thinking_model")
    private let haikuModelColumn = Expression<String?>("haiku_model")
    private let sonnetModelColumn = Expression<String?>("sonnet_model")
    private let opusModelColumn = Expression<String?>("opus_model")
    private let isActiveColumn = Expression<Bool>("is_active")
    private let sortOrderColumn = Expression<Int>("sort_order")

    private init() {
        setupDatabase()
    }

    private func setupDatabase() {
        do {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appFolder = appSupport.appendingPathComponent("CCManager", isDirectory: true)
            try FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
            let dbPath = appFolder.appendingPathComponent("providers.sqlite").path

            db = try Connection(dbPath)
            try createTable()
            try migrateIfNeeded()
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
            t.column(thinkingModelColumn)
            t.column(haikuModelColumn)
            t.column(sonnetModelColumn)
            t.column(opusModelColumn)
            t.column(isActiveColumn, defaultValue: false)
            t.column(sortOrderColumn, defaultValue: 0)
        })
    }

    private func migrateIfNeeded() throws {
        guard let db = db else { return }

        // Get existing columns
        var existingColumns: Set<String> = []
        let stmt = try db.prepare("PRAGMA table_info(providers)")
        for row in stmt {
            if let nameCol = row[1] as? String {
                existingColumns.insert(nameCol)
            }
        }

        // Add missing columns
        let migrations: [(String, SQLite.Expression<String?>)] = [
            ("thinking_model", thinkingModelColumn),
            ("haiku_model", haikuModelColumn),
            ("sonnet_model", sonnetModelColumn),
            ("opus_model", opusModelColumn),
        ]

        for (colName, expression) in migrations {
            if !existingColumns.contains(colName) {
                try db.run(providersTable.addColumn(expression))
            }
        }
    }

    // MARK: - CRUD Operations

    func loadAllProviders() -> [Provider] {
        guard let db = db else { return [] }

        var results: [Provider] = []
        // Use sync carefully: dbQueue is serial, calling sync from main thread is safe
        // only if no other async work on dbQueue is pending (which is the case here).
        // Using DispatchQueue.concurrently and barrier flag would be safer for future async needs.
        let semaphore = DispatchSemaphore(value: 0)
        dbQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                for row in try db.prepare(self.providersTable.order(self.sortOrderColumn.asc)) {
                    let provider = Provider(
                        id: UUID(uuidString: row[self.idColumn]) ?? UUID(),
                        name: row[self.nameColumn],
                        type: ProviderType(rawValue: row[self.typeColumn]) ?? .claudeCode,
                        apiKey: row[self.apiKeyColumn],
                        baseUrl: row[self.baseUrlColumn],
                        model: row[self.modelColumn],
                        thinkingModel: row[self.thinkingModelColumn],
                        haikuModel: row[self.haikuModelColumn],
                        sonnetModel: row[self.sonnetModelColumn],
                        opusModel: row[self.opusModelColumn],
                        isActive: row[self.isActiveColumn],
                        sortOrder: row[self.sortOrderColumn]
                    )
                    results.append(provider)
                }
            } catch {
                print("Load providers error: \(error)")
            }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 5)
        return results
    }

    func addProvider(_ provider: Provider) throws {
        guard let db = db else { throw DatabaseError.notConnected }

        try db.run(providersTable.insert(
            idColumn <- provider.id.uuidString,
            nameColumn <- provider.name,
            typeColumn <- provider.type.rawValue,
            apiKeyColumn <- provider.apiKey,
            baseUrlColumn <- provider.baseUrl,
            modelColumn <- provider.model,
            thinkingModelColumn <- provider.thinkingModel,
            haikuModelColumn <- provider.haikuModel,
            sonnetModelColumn <- provider.sonnetModel,
            opusModelColumn <- provider.opusModel,
            isActiveColumn <- provider.isActive,
            sortOrderColumn <- provider.sortOrder
        ))
    }

    func updateProvider(_ provider: Provider) throws {
        guard let db = db else { throw DatabaseError.notConnected }

        let row = providersTable.filter(idColumn == provider.id.uuidString)
        try db.run(row.update(
            nameColumn <- provider.name,
            typeColumn <- provider.type.rawValue,
            apiKeyColumn <- provider.apiKey,
            baseUrlColumn <- provider.baseUrl,
            modelColumn <- provider.model,
            thinkingModelColumn <- provider.thinkingModel,
            haikuModelColumn <- provider.haikuModel,
            sonnetModelColumn <- provider.sonnetModel,
            opusModelColumn <- provider.opusModel,
            isActiveColumn <- provider.isActive,
            sortOrderColumn <- provider.sortOrder
        ))
    }

    func deleteProvider(id: UUID) throws {
        guard let db = db else { throw DatabaseError.notConnected }

        let row = providersTable.filter(idColumn == id.uuidString)
        try db.run(row.delete())
    }

    func setActiveProvider(id: UUID, type: ProviderType) throws {
        guard let db = db else { throw DatabaseError.notConnected }

        // Deactivate all providers of the same type
        try db.run(providersTable.filter(typeColumn == type.rawValue).update(isActiveColumn <- false))

        // Activate selected
        let row = providersTable.filter(idColumn == id.uuidString)
        try db.run(row.update(isActiveColumn <- true))
    }

    func getProvider(byId id: UUID) -> Provider? {
        return loadAllProviders().first { $0.id == id }
    }

    func getActiveProvider(forType type: ProviderType) -> Provider? {
        return loadAllProviders().first { $0.type == type && $0.isActive }
    }
}

enum DatabaseError: Error, LocalizedError {
    case notConnected
    case notFound
    case invalidData

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Database not connected"
        case .notFound: return "Provider not found"
        case .invalidData: return "Invalid data"
        }
    }
}
