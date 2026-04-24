import XCTest
@testable import CCManager

final class CLIOutputTests: XCTestCase {
    func testOutputModeUsesJSONWhenRequested() {
        XCTAssertEqual(CLIOutputMode(jsonFlag: true, stdoutIsTTY: true), .json)
        XCTAssertEqual(CLIOutputMode(jsonFlag: false, stdoutIsTTY: false), .json)
        XCTAssertEqual(CLIOutputMode(jsonFlag: false, stdoutIsTTY: true), .text)
    }

    func testProviderSummaryHonorsFieldsAndLimit() {
        let providers = [
            Provider(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                name: "Claude",
                type: .claudeCode,
                apiKey: "sk-claude",
                baseUrl: "https://api.anthropic.com",
                model: "claude-sonnet",
                isActive: true
            ),
            Provider(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                name: "Codex",
                type: .codex,
                apiKey: "sk-openai",
                baseUrl: "https://api.openai.com/v1",
                model: "gpt-5.4"
            )
        ]

        let summaries = CLIProviderSummary.makeList(
            from: providers,
            limit: 1,
            fields: ["id", "name", "active"]
        )

        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries[0], [
            "active": .bool(true),
            "id": .string("00000000-0000-0000-0000-000000000001"),
            "name": .string("Claude")
        ])
        XCTAssertNil(summaries[0]["api_key"])
    }

    func testStructuredErrorContainsRecoveryMetadata() {
        let error = CLIErrorPayload(
            code: "provider_not_found",
            message: "Provider not found: missing",
            input: ["provider_id": "missing"],
            retryable: false,
            suggestion: "Run 'ccmanager list --json --fields=id,name,type,active' to see available providers."
        )

        XCTAssertEqual(error.exitCode, 1)
        XCTAssertEqual(error.input?["provider_id"], "missing")
        XCTAssertEqual(error.suggestion, "Run 'ccmanager list --json --fields=id,name,type,active' to see available providers.")
    }
}
