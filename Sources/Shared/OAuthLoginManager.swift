import Foundation

actor OAuthLoginManager {
    static let shared = OAuthLoginManager()

    private init() {}

    /// 执行 Device Code 登录，返回解析出的 DeviceCodeInfo
    func startLogin() async throws -> DeviceCodeInfo {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ccodex")
        process.arguments = ["login", "--device-auth"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        guard let info = CodexOAuthLoginParser.parse(output) else {
            throw OAuthError.parseFailed
        }

        return info
    }

    /// 轮询 ~/.codex/auth.json 直到出现 auth_mode = "chatgpt"
    /// 超时时间 15 分钟（900 秒），轮询间隔 5 秒
    func pollForAuth(timeoutSeconds: Int = 900, intervalSeconds: Int = 5) async throws -> (accountId: String, accessToken: String, refreshToken: String, idToken: String, displayName: String?) {
        let authUrl = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".codex")
            .appendingPathComponent("auth.json")

        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))

        while Date() < deadline {
            if let result = CodexOAuthLoginParser.parseAuthJson(at: authUrl) {
                return result
            }
            try await Task.sleep(nanoseconds: UInt64(intervalSeconds) * 1_000_000_000)
        }

        throw OAuthError.timeout
    }

    /// 刷新指定 provider 的 OAuth token
    /// 当前实现：重新执行 Device Code 登录流程
    /// 注意：真正的 OAuth refresh 需要调用 OpenAI OAuth token 刷新端点
    func refreshToken() async throws {
        // 目前通过重新执行 Device Code 流程来实现刷新
        // 用户需要重新在浏览器中授权
        throw OAuthError.refreshNotSupported
    }
}

enum OAuthError: Error, LocalizedError {
    case parseFailed
    case timeout
    case cancelled
    case refreshNotSupported

    var errorDescription: String? {
        switch self {
        case .parseFailed: return "Failed to parse Device Code from output"
        case .timeout: return "Login timeout (15 minutes)"
        case .cancelled: return "Login cancelled"
        case .refreshNotSupported: return "Token refresh requires re-authentication via browser"
        }
    }
}