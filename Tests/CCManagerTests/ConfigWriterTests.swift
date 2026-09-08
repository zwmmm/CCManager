import XCTest
@testable import CCManager

final class ConfigWriterTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CCManagerConfigWriterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
        try super.tearDownWithError()
    }

    func testCodexWritesApiKeyToAuthJsonAndModelProviderWithoutBearerToken() throws {
        let writer = ConfigWriter(home: tempDirectory)
        let provider = Provider(
            name: "OpenAI",
            type: .codex,
            apiKey: "api-token",
            baseUrl: "https://api.openai.com/v1",
            model: "gpt-5.4"
        )

        try writer.writeProviderToConfig(provider)

        let authURL = tempDirectory.appendingPathComponent(".codex/auth.json")
        let configURL = tempDirectory.appendingPathComponent(".codex/config.toml")

        let authData = try Data(contentsOf: authURL)
        let auth = try XCTUnwrap(try JSONSerialization.jsonObject(with: authData) as? [String: Any])
        XCTAssertEqual(auth["auth_mode"] as? String, "apikey")
        XCTAssertEqual(auth["OPENAI_API_KEY"] as? String, "api-token")
        XCTAssertNil(auth["tokens"])
        XCTAssertNil(auth["last_refresh"])

        let config = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertTrue(config.contains("model_provider = \"ccmanager\""))
        XCTAssertTrue(config.contains("model = \"gpt-5.4\""))
        XCTAssertTrue(config.contains("[model_providers.ccmanager]"))
        XCTAssertTrue(config.contains("base_url = \"https://api.openai.com/v1\""))
        XCTAssertTrue(config.contains("wire_api = \"responses\""))
        XCTAssertTrue(config.contains("requires_openai_auth = true"))
        XCTAssertFalse(config.contains("experimental_bearer_token"))
    }

    func testCodexPreservesUnmanagedConfigWhenSwitchingProvider() throws {
        let codexDirectory = tempDirectory.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        let configURL = codexDirectory.appendingPathComponent("config.toml")
        let existingConfig = """
        model = "previous-model"
        model_provider = "previous-provider"
        approval_policy = "on-request"

        [features]
        web_search = true

        [model_providers.other]
        name = "other"
        base_url = "https://other.example.com/v1"

        [model_providers.ccmanager]
        name = "old-ccmanager"
        base_url = "https://old.example.com/v1"
        experimental_bearer_token = "old-token"

        [profiles.work]
        model = "work-model"
        approval_policy = "never"
        """
        try existingConfig.write(to: configURL, atomically: true, encoding: .utf8)

        let writer = ConfigWriter(home: tempDirectory)
        let provider = Provider(
            name: "OpenAI",
            type: .codex,
            apiKey: "new-token",
            baseUrl: "https://api.openai.com/v1",
            model: "gpt-5.4"
        )

        try writer.writeProviderToConfig(provider)

        let authURL = tempDirectory.appendingPathComponent(".codex/auth.json")
        let authData = try Data(contentsOf: authURL)
        let auth = try XCTUnwrap(try JSONSerialization.jsonObject(with: authData) as? [String: Any])
        XCTAssertEqual(auth["auth_mode"] as? String, "apikey")
        XCTAssertEqual(auth["OPENAI_API_KEY"] as? String, "new-token")

        let config = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertTrue(config.contains("approval_policy = \"on-request\""))
        XCTAssertTrue(config.contains("[features]\nweb_search = true"))
        XCTAssertTrue(config.contains("[model_providers.other]"))
        XCTAssertTrue(config.contains("base_url = \"https://other.example.com/v1\""))
        XCTAssertTrue(config.contains("[profiles.work]\nmodel = \"work-model\"\napproval_policy = \"never\""))
        XCTAssertTrue(config.contains("model = \"gpt-5.4\""))
        XCTAssertTrue(config.contains("model_provider = \"ccmanager\""))
        XCTAssertFalse(config.contains("experimental_bearer_token"))
        XCTAssertFalse(config.contains("previous-model"))
        XCTAssertFalse(config.contains("previous-provider"))
        XCTAssertFalse(config.contains("old-ccmanager"))
        XCTAssertFalse(config.contains("old-token"))
    }

    func testCodexDoesNotOverwriteConfigWhenExistingFileCannotBeDecoded() throws {
        let codexDirectory = tempDirectory.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        let configURL = codexDirectory.appendingPathComponent("config.toml")
        let originalData = Data([0xFF, 0xFE, 0xFD])
        try originalData.write(to: configURL, options: .atomic)

        let writer = ConfigWriter(home: tempDirectory)
        let provider = Provider(
            name: "OpenAI",
            type: .codex,
            apiKey: "new-token",
            baseUrl: "https://api.openai.com/v1",
            model: "gpt-5.4"
        )

        XCTAssertThrowsError(try writer.writeProviderToConfig(provider))
        XCTAssertEqual(try Data(contentsOf: configURL), originalData)
    }

    func testCodexOAuthWritesChatGPTAuthWithoutModelProvider() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_777_000_000)
        let writer = ConfigWriter(home: tempDirectory, currentDate: { fixedDate })
        let provider = Provider(
            name: "sanyi",
            type: .codexOAuth,
            apiKey: nil,
            baseUrl: "",
            model: "gpt-5.4",
            oauthAccountId: "oauth-account",
            oauthAccessToken: "oauth-access",
            oauthRefreshToken: "oauth-refresh",
            oauthIdToken: "oauth-id",
            oauthDisplayName: "sanyi"
        )

        try writer.writeProviderToConfig(provider)

        let authURL = tempDirectory.appendingPathComponent(".codex/auth.json")
        let configURL = tempDirectory.appendingPathComponent(".codex/config.toml")

        let authData = try Data(contentsOf: authURL)
        let auth = try XCTUnwrap(try JSONSerialization.jsonObject(with: authData) as? [String: Any])
        let tokens = try XCTUnwrap(auth["tokens"] as? [String: Any])

        XCTAssertEqual(auth["auth_mode"] as? String, "chatgpt")
        XCTAssertTrue(auth["OPENAI_API_KEY"] is NSNull)
        XCTAssertEqual(tokens["access_token"] as? String, "oauth-access")
        XCTAssertEqual(tokens["refresh_token"] as? String, "oauth-refresh")
        XCTAssertEqual(tokens["id_token"] as? String, "oauth-id")
        XCTAssertEqual(tokens["account_id"] as? String, "oauth-account")
        XCTAssertNotNil(auth["last_refresh"] as? String)

        let config = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertTrue(config.contains("model = \"gpt-5.4\""))
        XCTAssertFalse(config.contains("model_provider"))
        XCTAssertFalse(config.contains("base_url"))
    }

    func testCodexOAuthPreservesUnmanagedConfigWhenSwitchingProvider() throws {
        let codexDirectory = tempDirectory.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        let configURL = codexDirectory.appendingPathComponent("config.toml")
        let existingConfig = """
        model = "previous-model"
        model_provider = "ccmanager"
        approval_policy = "on-request"

        [features]
        web_search = true

        [model_providers.other]
        name = "other"
        base_url = "https://other.example.com/v1"

        [model_providers.ccmanager]
        name = "ccmanager"
        base_url = "https://old.example.com/v1"
        experimental_bearer_token = "old-token"

        [profiles.work]
        model = "work-model"
        approval_policy = "never"
        """
        try existingConfig.write(to: configURL, atomically: true, encoding: .utf8)

        let writer = ConfigWriter(home: tempDirectory)
        let provider = Provider(
            name: "sanyi",
            type: .codexOAuth,
            apiKey: nil,
            baseUrl: "",
            model: "gpt-5.4",
            oauthAccountId: "oauth-account",
            oauthAccessToken: "oauth-access",
            oauthRefreshToken: "oauth-refresh",
            oauthIdToken: "oauth-id"
        )

        try writer.writeProviderToConfig(provider)

        let config = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertTrue(config.contains("approval_policy = \"on-request\""))
        XCTAssertTrue(config.contains("[features]\nweb_search = true"))
        XCTAssertTrue(config.contains("[model_providers.other]"))
        XCTAssertTrue(config.contains("base_url = \"https://other.example.com/v1\""))
        XCTAssertTrue(config.contains("[profiles.work]\nmodel = \"work-model\"\napproval_policy = \"never\""))
        XCTAssertTrue(config.contains("model = \"gpt-5.4\""))
        XCTAssertFalse(config.contains("model_provider ="))
        XCTAssertFalse(config.contains("[model_providers.ccmanager]"))
        XCTAssertFalse(config.contains("old-token"))
    }

    func testSwitchingBetweenCodexOAuthAndCodexApiKeyCleansAuthJson() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_777_000_000)
        let writer = ConfigWriter(home: tempDirectory, currentDate: { fixedDate })

        let oauthProvider = Provider(
            name: "ChatGPT",
            type: .codexOAuth,
            apiKey: nil,
            baseUrl: "",
            model: "gpt-5.4",
            oauthAccountId: "acc-123",
            oauthAccessToken: "access-token-123",
            oauthRefreshToken: "refresh-token-123",
            oauthIdToken: "id-token-123"
        )
        try writer.writeProviderToConfig(oauthProvider)

        let authURL = tempDirectory.appendingPathComponent(".codex/auth.json")
        let configURL = tempDirectory.appendingPathComponent(".codex/config.toml")

        var authData = try Data(contentsOf: authURL)
        var auth = try XCTUnwrap(try JSONSerialization.jsonObject(with: authData) as? [String: Any])
        XCTAssertEqual(auth["auth_mode"] as? String, "chatgpt")
        XCTAssertTrue(auth["OPENAI_API_KEY"] is NSNull)
        XCTAssertNotNil(auth["tokens"])

        let apiKeyProvider = Provider(
            name: "ThirdParty",
            type: .codex,
            apiKey: "sk-third-party-key",
            baseUrl: "https://api.thirdparty.com/v1",
            model: "gpt-5.5"
        )
        try writer.writeProviderToConfig(apiKeyProvider)

        authData = try Data(contentsOf: authURL)
        auth = try XCTUnwrap(try JSONSerialization.jsonObject(with: authData) as? [String: Any])
        XCTAssertEqual(auth["auth_mode"] as? String, "apikey")
        XCTAssertEqual(auth["OPENAI_API_KEY"] as? String, "sk-third-party-key")
        XCTAssertNil(auth["tokens"])
        XCTAssertNil(auth["last_refresh"])

        let config = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertTrue(config.contains("model = \"gpt-5.5\""))
        XCTAssertTrue(config.contains("model_provider = \"ccmanager\""))
        XCTAssertTrue(config.contains("[model_providers.ccmanager]"))
        XCTAssertTrue(config.contains("base_url = \"https://api.thirdparty.com/v1\""))
        XCTAssertFalse(config.contains("experimental_bearer_token"))
    }
}
