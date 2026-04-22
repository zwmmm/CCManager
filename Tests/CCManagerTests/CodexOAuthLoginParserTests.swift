import XCTest
@testable import CCManager

final class CodexOAuthLoginParserTests: XCTestCase {
    func testParsesCurrentCodexDeviceCodeFormat() {
        let output = """
        Follow these steps to sign in with ChatGPT using device code authorization:

        1. Open this link in your browser and sign in to your account
           https://auth.openai.com/codex/device

        2. Enter this one-time code (expires in 15 minutes)
           VHQW-F20A2
        """

        let info = CodexOAuthLoginParser.parse(output)

        XCTAssertEqual(info?.userCode, "VHQW-F20A2")
        XCTAssertEqual(info?.verificationUrl, "https://auth.openai.com/codex/device")
    }

    func testParsesAnsiColoredCodexOutput() {
        let output = "\u{001B}[94mVHQW-F20A2\u{001B}[0m"

        let info = CodexOAuthLoginParser.parse(output)

        XCTAssertEqual(info?.userCode, "VHQW-F20A2")
    }
}
