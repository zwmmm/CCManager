import Foundation

enum TestResult {
    case success
    case failure(String)
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
        let urlString = provider.baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(urlString)/chat/completions") else {
            return .failure("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let model = provider.model ?? PresetProvider.defaultCodexModel
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
}
