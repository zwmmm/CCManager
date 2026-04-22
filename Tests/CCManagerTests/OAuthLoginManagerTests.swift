import XCTest
@testable import CCManager

final class OAuthLoginManagerTests: XCTestCase {
    func testUsesLoginShellForDeviceLogin() {
        XCTAssertEqual(OAuthLoginManager.shellExecutablePath.path, "/bin/zsh")
        XCTAssertEqual(OAuthLoginManager.shellArgumentsPrefix, "-lic")
    }

    func testRunsCodexDeviceLoginCommand() {
        XCTAssertEqual(OAuthLoginManager.codexLoginCommand, "exec codex login --device-auth")
        XCTAssertFalse(OAuthLoginManager.codexLoginCommand.contains("ccodex"))
    }

    func testIgnoresExistingAuthJsonUntilItChanges() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CCManagerOAuthTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let authURL = tempDirectory.appendingPathComponent("auth.json")
        let idTokenPayload = Self.base64URL(#"{"email":"old@example.com"}"#)
        let existingAuth = """
        {
          "auth_mode": "chatgpt",
          "tokens": {
            "id_token": "header.\(idTokenPayload).signature",
            "access_token": "old-access",
            "refresh_token": "old-refresh",
            "account_id": "old-account"
          }
        }
        """
        try existingAuth.write(to: authURL, atomically: true, encoding: .utf8)

        let manager = OAuthLoginManager(authFileURL: authURL)
        await manager.markLoginStartedForTesting()

        let task = Task {
            try await manager.pollForAuth(timeoutSeconds: 2, intervalSeconds: 1)
        }

        do {
            _ = try await task.value
            XCTFail("Expected timeout when auth.json has not changed")
        } catch let error as OAuthError {
            switch error {
            case .timeout:
                break
            default:
                XCTFail("Expected timeout, got \(error)")
            }
        }
    }

    func testParsesPreferredDisplayNameFromIDTokenBeforeEmail() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CCManagerOAuthTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let authURL = tempDirectory.appendingPathComponent("auth.json")
        let idTokenPayload = Self.base64URL(#"{"name":"sanyi","email":"wayne950117@gmail.com"}"#)
        let auth = """
        {
          "auth_mode": "chatgpt",
          "tokens": {
            "id_token": "header.\(idTokenPayload).signature",
            "access_token": "access-token",
            "refresh_token": "refresh-token",
            "account_id": "account-id"
          }
        }
        """
        try auth.write(to: authURL, atomically: true, encoding: .utf8)

        let parsed = try XCTUnwrap(CodexOAuthLoginParser.parseAuthJson(at: authURL))
        XCTAssertEqual(parsed.displayName, "sanyi")
    }

    private static func base64URL(_ string: String) -> String {
        Data(string.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
