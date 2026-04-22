import Foundation

struct DeviceCodeInfo {
    let userCode: String      // e.g. "VHQW-F20A2"
    let verificationUrl: String  // "https://auth.openai.com/codex/device"
}

enum CodexOAuthLoginParser {
    /// 从 `codex login --device-auth` 的 stdout 解析 Device Code 信息
    static func parse(_ output: String) -> DeviceCodeInfo? {
        // 匹配格式: XXXX-XXXXX (Codex CLI 0.122+ 使用 4 + 5 位)
        let codePattern = #"([A-Z0-9]{4}-[A-Z0-9]{4,6})"#

        guard let codeMatch = output.range(of: codePattern, options: .regularExpression) else {
            return nil
        }

        let userCode = String(output[codeMatch])
        let verificationUrl = "https://auth.openai.com/codex/device"

        return DeviceCodeInfo(userCode: userCode, verificationUrl: verificationUrl)
    }

    /// 从 `~/.codex/auth.json` 解析 OAuth tokens
    static func parseAuthJson(at url: URL) -> (accountId: String, accessToken: String, refreshToken: String, idToken: String, displayName: String?)? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let authMode = json["auth_mode"] as? String,
              authMode == "chatgpt",
              let tokens = json["tokens"] as? [String: Any],
              let idToken = tokens["id_token"] as? String,
              let accessToken = tokens["access_token"] as? String,
              let refreshToken = tokens["refresh_token"] as? String,
              let accountId = tokens["account_id"] as? String
        else {
            return nil
        }

        let displayName = displayName(fromIDToken: idToken)

        return (accountId, accessToken, refreshToken, idToken, displayName)
    }

    static func parseAuthJsonIfChanged(
        at url: URL,
        previousData: Data?
    ) -> (accountId: String, accessToken: String, refreshToken: String, idToken: String, displayName: String?)? {
        guard let currentData = try? Data(contentsOf: url) else {
            return nil
        }

        if let previousData, currentData == previousData {
            return nil
        }

        return parseAuthJson(at: url)
    }

    private static func displayName(fromIDToken idToken: String) -> String? {
        guard let idTokenBase64 = idToken.split(separator: ".").dropFirst().first else {
            return nil
        }

        let padding = String(repeating: "=", count: (4 - idTokenBase64.count % 4) % 4)
        guard let idTokenData = Data(base64Encoded: String(idTokenBase64) + padding),
              let claims = try? JSONSerialization.jsonObject(with: idTokenData) as? [String: Any]
        else {
            return nil
        }

        let candidateKeys = ["name", "preferred_username", "nickname", "email"]
        for key in candidateKeys {
            if let value = claims[key] as? String,
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }

        return nil
    }
}
