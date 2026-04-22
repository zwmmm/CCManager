import XCTest
import SQLite
@testable import CCManager

final class DatabaseActiveProviderTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CCManagerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
        try super.tearDownWithError()
    }

    func testCodexAndCodexOAuthShareOneActiveSlot() throws {
        let database = try Database(databaseURL: tempDirectory.appendingPathComponent("providers.sqlite"))

        let claude = Provider(
            name: "Claude",
            type: .claudeCode,
            apiKey: "claude-key",
            baseUrl: "https://api.anthropic.com",
            isActive: true
        )
        let codex = Provider(
            name: "Codex",
            type: .codex,
            apiKey: "codex-key",
            baseUrl: "https://api.openai.com/v1",
            isActive: true
        )
        let codexOAuth = Provider(
            name: "ChatGPT",
            type: .codexOAuth,
            apiKey: nil,
            baseUrl: "",
            isActive: false,
            oauthAccountId: "account-id",
            oauthAccessToken: "access-token",
            oauthRefreshToken: "refresh-token",
            oauthIdToken: "id-token",
            oauthDisplayName: "user@example.com"
        )

        try database.addProvider(claude)
        try database.addProvider(codex)
        try database.addProvider(codexOAuth)

        try database.setActiveProvider(id: codexOAuth.id, type: .codexOAuth)

        let providers = database.loadAllProviders()
        XCTAssertTrue(try XCTUnwrap(providers.first { $0.id == claude.id }).isActive)
        XCTAssertFalse(try XCTUnwrap(providers.first { $0.id == codex.id }).isActive)
        XCTAssertTrue(try XCTUnwrap(providers.first { $0.id == codexOAuth.id }).isActive)
    }

    func testPersistsCodexOAuthProvider() throws {
        let database = try Database(databaseURL: tempDirectory.appendingPathComponent("providers.sqlite"))
        let provider = Provider(
            name: "user@example.com",
            type: .codexOAuth,
            apiKey: nil,
            baseUrl: "",
            model: "gpt-5.4",
            oauthAccountId: "account-id",
            oauthAccessToken: "access-token",
            oauthRefreshToken: "refresh-token",
            oauthIdToken: "id-token",
            oauthDisplayName: "user@example.com"
        )

        try database.addProvider(provider)

        let persisted = try XCTUnwrap(database.loadAllProviders().first(where: { $0.id == provider.id }))
        XCTAssertEqual(persisted.type, .codexOAuth)
        XCTAssertEqual(persisted.name, "user@example.com")
        XCTAssertEqual(persisted.oauthDisplayName, "user@example.com")
    }

    func testPersistsCodexOAuthProviderWithLegacyNonNullApiKeySchema() throws {
        let databaseURL = tempDirectory.appendingPathComponent("legacy-providers.sqlite")
        let connection = try Connection(databaseURL.path)
        try connection.execute("""
        CREATE TABLE providers (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            api_key TEXT NOT NULL,
            base_url TEXT NOT NULL,
            model TEXT,
            is_active INTEGER NOT NULL DEFAULT 0,
            sort_order INTEGER NOT NULL DEFAULT 0,
            thinking_model TEXT,
            haiku_model TEXT,
            sonnet_model TEXT,
            opus_model TEXT,
            oauth_account_id TEXT,
            oauth_access_token TEXT,
            oauth_refresh_token TEXT,
            oauth_id_token TEXT,
            oauth_display_name TEXT,
            oauth_token_expiry TEXT
        );
        """)

        let database = try Database(databaseURL: databaseURL)
        let provider = Provider(
            name: "legacy@example.com",
            type: .codexOAuth,
            apiKey: nil,
            baseUrl: "",
            oauthAccountId: "account-id",
            oauthAccessToken: "access-token",
            oauthRefreshToken: "refresh-token",
            oauthIdToken: "id-token",
            oauthDisplayName: "legacy@example.com"
        )

        try database.addProvider(provider)

        let persisted = try XCTUnwrap(database.loadAllProviders().first(where: { $0.id == provider.id }))
        XCTAssertEqual(persisted.type, .codexOAuth)
        XCTAssertNil(persisted.apiKey)
        XCTAssertEqual(persisted.oauthDisplayName, "legacy@example.com")
    }
}
