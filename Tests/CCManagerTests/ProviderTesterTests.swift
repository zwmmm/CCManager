import XCTest
@testable import CCManager

final class ProviderTesterTests: XCTestCase {
    func testCodexOAuthRequiresOAuthAccessToken() {
        let provider = Provider(
            name: "sanyi",
            type: .codexOAuth,
            apiKey: nil,
            baseUrl: "",
            model: "gpt-5.4",
            oauthAccountId: "oauth-account",
            oauthAccessToken: nil,
            oauthRefreshToken: "oauth-refresh",
            oauthIdToken: "oauth-id",
            oauthDisplayName: "sanyi"
        )

        let result = ProviderTester.shared.codexRequest(for: provider)

        switch result {
        case let .failure(.message(message)):
            XCTAssertEqual(message, "OAuth access token is required")
        case .success:
            XCTFail("Expected missing OAuth token failure")
        }
    }

    func testCodexOAuthUsesDefaultBaseURLAndBearerToken() throws {
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

        let request: URLRequest
        switch ProviderTester.shared.codexRequest(for: provider) {
        case let .success(builtRequest):
            request = builtRequest
        case let .failure(.message(message)):
            XCTFail("Expected request build success, got \(message)")
            return
        }

        XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/chat/completions")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer oauth-access")
        XCTAssertEqual(request.httpMethod, "POST")
    }

    func testCodexOAuthMapsTLSErrorToHelpfulMessage() async {
        let request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        let tester = ProviderTester.shared
        let error = URLError(.secureConnectionFailed)

        let mirror = Mirror(reflecting: tester)
        _ = mirror

        let message = tester.networkErrorMessageForTesting(error, request: request)
        XCTAssertEqual(
            message,
            "TLS handshake failed for api.openai.com. Check proxy, VPN, system certificate trust, or HTTPS inspection."
        )
    }
}
