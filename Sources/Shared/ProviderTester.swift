import Foundation

enum TestResult {
    case success
    case failure(String)
}

enum ProviderTestBuildError: Error, Equatable {
    case message(String)
}

final class ProviderTester {
    static let shared = ProviderTester()

    private init() {}

    func test(provider: Provider) async -> TestResult {
        switch provider.type {
        case .claudeCode:
            return await testClaudeCode(provider: provider)
        case .codex:
            return await testCodex(provider: provider)
        case .codexOAuth:
            return await testCodex(provider: provider)
        }
    }

    // MARK: - Claude Code Test

    private func testClaudeCode(provider: Provider) async -> TestResult {
        let urlString = provider.baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(urlString)/v1/messages") else {
            return .failure("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(provider.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let model = provider.model ?? PresetProvider.defaultClaudeModel
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1,
            "messages": [["role": "user", "content": "Hi"]]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return .failure("Failed to encode request")
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure("Invalid response")
            }
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                return .success
            } else {
                return .failure("HTTP \(httpResponse.statusCode)")
            }
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    // MARK: - Codex Test

    private func testCodex(provider: Provider) async -> TestResult {
        switch codexRequest(for: provider) {
        case let .failure(.message(message)):
            return .failure(message)
        case let .success(request):
            return await performCodexRequest(request)
        }
    }

    func codexRequest(for provider: Provider) -> Result<URLRequest, ProviderTestBuildError> {
        let bearerToken: String?
        if provider.type == .codexOAuth {
            bearerToken = provider.oauthAccessToken
        } else {
            bearerToken = provider.apiKey
        }

        guard let bearerToken, !bearerToken.isEmpty else {
            return .failure(.message(provider.type == .codexOAuth ? "OAuth access token is required" : "API key is required"))
        }

        let rawBaseUrl = provider.type == .codexOAuth && provider.baseUrl.isEmpty
            ? "https://api.openai.com/v1"
            : provider.baseUrl
        let urlString = rawBaseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(urlString)/chat/completions") else {
            return .failure(.message("Invalid URL"))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let model = provider.model ?? PresetProvider.defaultCodexModel
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1,
            "messages": [["role": "user", "content": "Hi"]]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            return .success(request)
        } catch {
            return .failure(.message("Failed to encode request"))
        }
    }

    private func performCodexRequest(_ request: URLRequest) async -> TestResult {
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure("Invalid response")
            }
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                return .success
            } else {
                return .failure("HTTP \(httpResponse.statusCode)")
            }
        } catch {
            return .failure(networkErrorMessage(for: error, request: request))
        }
    }

    private func networkErrorMessage(for error: Error, request: URLRequest) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateUntrusted,
                 .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid, .clientCertificateRejected,
                 .clientCertificateRequired:
                let host = request.url?.host ?? "server"
                return "TLS handshake failed for \(host). Check proxy, VPN, system certificate trust, or HTTPS inspection."
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .notConnectedToInternet:
                return "Network connection failed: \(urlError.localizedDescription)"
            default:
                return urlError.localizedDescription
            }
        }

        return error.localizedDescription
    }

    func networkErrorMessageForTesting(_ error: Error, request: URLRequest) -> String {
        networkErrorMessage(for: error, request: request)
    }
}
