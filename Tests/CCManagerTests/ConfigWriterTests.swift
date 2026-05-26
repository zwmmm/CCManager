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

    func testCodexWritesBearerTokenInModelProviderWithoutAuthJson() throws {
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

        XCTAssertFalse(FileManager.default.fileExists(atPath: authURL.path))

        let config = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertTrue(config.contains("model_provider = \"ccmanager\""))
        XCTAssertTrue(config.contains("model = \"gpt-5.4\""))
        XCTAssertTrue(config.contains("[model_providers.ccmanager]"))
        XCTAssertTrue(config.contains("base_url = \"https://api.openai.com/v1\""))
        XCTAssertTrue(config.contains("experimental_bearer_token = \"api-token\""))
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
}
