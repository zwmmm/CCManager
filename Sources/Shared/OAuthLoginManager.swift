import Foundation

actor OAuthLoginManager {
    static let shared = OAuthLoginManager()
    static let shellExecutablePath = URL(fileURLWithPath: "/bin/zsh")
    static let shellArgumentsPrefix = "-lic"
    static let codexLoginCommand = "exec codex login --device-auth"

    private var loginProcess: Process?
    private var loginOutputPipe: Pipe?
    private let authFileURL: URL
    private var baselineAuthData: Data?

    private init() {
        self.authFileURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".codex")
            .appendingPathComponent("auth.json")
    }

    init(authFileURL: URL) {
        self.authFileURL = authFileURL
    }

    /// 执行 Device Code 登录，返回解析出的 DeviceCodeInfo
    func startLogin() async throws -> DeviceCodeInfo {
        cancelCurrentLogin()
        baselineAuthData = try? Data(contentsOf: authFileURL)

        let process = Process()
        process.executableURL = Self.shellExecutablePath
        process.arguments = [Self.shellArgumentsPrefix, Self.codexLoginCommand]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        loginProcess = process
        loginOutputPipe = pipe

        var output = ""
        let readHandle = pipe.fileHandleForReading

        repeat {
            let data = await Task.detached {
                readHandle.availableData
            }.value

            if data.isEmpty {
                break
            }

            output += String(data: data, encoding: .utf8) ?? ""
            if let info = CodexOAuthLoginParser.parse(output) {
                return info
            }
        } while process.isRunning

        throw OAuthError.parseFailed(output: output, exitCode: process.terminationStatus)
    }

    /// 轮询 ~/.codex/auth.json 直到出现 auth_mode = "chatgpt"
    /// 超时时间 15 分钟（900 秒），轮询间隔 5 秒
    func pollForAuth(timeoutSeconds: Int = 900, intervalSeconds: Int = 5) async throws -> (accountId: String, accessToken: String, refreshToken: String, idToken: String, displayName: String?) {
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))

        while Date() < deadline {
            if Task.isCancelled {
                cancelCurrentLogin()
                throw OAuthError.cancelled
            }

            if let result = CodexOAuthLoginParser.parseAuthJsonIfChanged(
                at: authFileURL,
                previousData: baselineAuthData
            ) {
                clearFinishedLogin()
                return result
            }
            try await Task.sleep(nanoseconds: UInt64(intervalSeconds) * 1_000_000_000)
        }

        cancelCurrentLogin()
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

    func cancelCurrentLogin() {
        if let loginProcess, loginProcess.isRunning {
            loginProcess.terminate()
        }
        loginProcess = nil
        loginOutputPipe = nil
    }

    private func clearFinishedLogin() {
        if loginProcess?.isRunning == false {
            loginProcess = nil
            loginOutputPipe = nil
        }
    }

    func markLoginStartedForTesting() {
        baselineAuthData = try? Data(contentsOf: authFileURL)
    }
}

enum OAuthError: Error, LocalizedError {
    case parseFailed(output: String, exitCode: Int32)
    case timeout
    case cancelled
    case refreshNotSupported

    var errorDescription: String? {
        switch self {
        case let .parseFailed(output, exitCode):
            let cleanedOutput = output
                .replacingOccurrences(of: #"\u{001B}\[[0-9;]*m"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanedOutput.isEmpty {
                return "Failed to parse Device Code from output (exit code \(exitCode), no output)"
            }
            return "Failed to parse Device Code from output (exit code \(exitCode)): \(cleanedOutput)"
        case .timeout: return "Login timeout (15 minutes)"
        case .cancelled: return "Login cancelled"
        case .refreshNotSupported: return "Token refresh requires re-authentication via browser"
        }
    }
}
