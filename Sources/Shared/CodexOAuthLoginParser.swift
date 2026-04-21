import Foundation

struct DeviceCodeInfo {
    let userCode: String      // e.g. "U9CQ-MFLJ1"
    let verificationUrl: String  // "https://auth.openai.com/codex/device"
}

enum CodexOAuthLoginParser {
    /// 从 `ccodex login --device-auth` 的 stdout 解析 Device Code 信息
    static func parse(_ output: String) -> DeviceCodeInfo? {
        // 匹配格式: XXXX-XXXX (4个字母数字 + 短横线 + 4个字母数字)
        let codePattern = #"([A-Z0-9]{4}-[A-Z0-9]{4})"#

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

        // 从 id_token 中提取 email 作为 displayName
        var displayName: String?
        if let idTokenBase64 = idToken.split(separator: ".").dropFirst().first {
            let padding = String(repeating: "=", count: (4 - idTokenBase64.count % 4) % 4)
            if let idTokenData = Data(base64Encoded: String(idTokenBase64) + padding),
               let claims = try? JSONSerialization.jsonObject(with: idTokenData) as? [String: Any] {
                displayName = claims["email"] as? String
            }
        }

        return (accountId, accessToken, refreshToken, idToken, displayName)
    }
}