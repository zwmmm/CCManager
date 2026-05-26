import Foundation

@MainActor
final class UsageStatsManager: ObservableObject {
    static let shared = UsageStatsManager()

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded(UsageReport)
        case failed(String)
    }

    @Published private(set) var state: LoadState = .idle
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isRefreshing = false

    private let refreshInterval: TimeInterval = 300

    private init() {}

    func refreshIfNeeded() {
        if let lastUpdated, Date().timeIntervalSince(lastUpdated) < refreshInterval {
            return
        }
        refresh()
    }

    func refresh() {
        guard !isRefreshing else { return }

        isRefreshing = true
        if case .loaded = state {
        } else {
            state = .loading
        }

        Task {
            do {
                let environment = UsageCommandResolver.shellEnvironment()
                let data = try await Self.runCcusageDailyJSON(environment: environment)
                let report = try UsageStatsParser.parse(data)

                withAnimationIfAvailable {
                    state = .loaded(report)
                    lastUpdated = Date()
                }

                isRefreshing = false
            } catch {
                isRefreshing = false
                state = .failed(Self.errorMessage(from: error))
            }
        }
    }

    private static func runCcusageDailyJSON(environment: [String: String]) async throws -> Data {
        let executable = try UsageCommandResolver.executablePath(named: "npx", environment: environment)
        let output = try await runProcess(
            executable: executable,
            arguments: ["--yes", "ccusage@latest", "daily", "--json", "--offline", "--since", defaultSinceDateString()],
            timeout: 45,
            environment: environment
        )

        return try jsonData(from: output, commandName: "ccusage")
    }

    private static func jsonData(from output: ProcessOutput, commandName: String) throws -> Data {
        guard output.exitCode == 0 else {
            let message = output.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw UsageStatsProcessError.commandFailed(message.isEmpty ? "\(commandName) exited with code \(output.exitCode)" : message)
        }

        guard let data = output.stdout.data(using: .utf8), !data.isEmpty else {
            throw UsageStatsProcessError.emptyOutput
        }

        return data
    }

    private static func defaultSinceDateString() -> String {
        let calendar = Calendar(identifier: .gregorian)
        let since = calendar.date(byAdding: .day, value: -120, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: since)
    }

    private static func runProcess(
        executable: String,
        arguments: [String],
        timeout: TimeInterval,
        environment: [String: String]? = nil
    ) async throws -> ProcessOutput {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.environment = environment

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            let resumeGate = ProcessResumeGate(continuation: continuation)

            process.terminationHandler = { process in
                let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
                let output = ProcessOutput(
                    stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                    stderr: String(data: stderrData, encoding: .utf8) ?? "",
                    exitCode: process.terminationStatus
                )
                resumeGate.resume(.success(output))
            }

            do {
                try process.run()
            } catch {
                resumeGate.resume(.failure(error))
                return
            }

            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                guard process.isRunning else { return }
                process.terminate()
                resumeGate.resume(.failure(UsageStatsProcessError.timeout))
            }
        }
    }

    private static func errorMessage(from error: Error) -> String {
        switch error {
        case UsageStatsProcessError.timeout:
            return "Usage command timed out while reading local data."
        case UsageStatsProcessError.emptyOutput:
            return "Usage command returned no JSON output."
        case UsageStatsProcessError.commandFailed(let message):
            return message
        case UsageStatsParser.ParseError.unsupportedShape:
            return "ccusage returned an unsupported JSON format."
        default:
            return error.localizedDescription
        }
    }

    private func withAnimationIfAvailable(_ updates: () -> Void) {
        updates()
    }
}

enum UsageCommandResolver {
    static func shellEnvironment() -> [String: String] {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let path = enhancedPath(
            currentPath: ProcessInfo.processInfo.environment["PATH"] ?? "",
            homeDirectory: homeDirectory
        )

        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = path
        environment["HOME"] = homeDirectory.path

        return environment
    }

    static func executablePath(named name: String, environment: [String: String]) throws -> String {
        let path = environment["PATH"] ?? ""
        for directory in path.split(separator: ":").map(String.init) where !directory.isEmpty {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent(name).path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        throw UsageStatsProcessError.commandFailed("Could not find \(name). Install Node.js/npm or make sure \(name) is in PATH.")
    }

    static func enhancedPath(currentPath: String, homeDirectory: URL) -> String {
        let home = homeDirectory.path
        let additions = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(home)/.bun/bin",
            "\(home)/.npm-global/bin",
            "\(home)/Library/pnpm",
            "\(home)/.local/share/pnpm",
            "\(home)/.local/bin",
            "\(home)/.cargo/bin",
            "\(home)/.deno/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]

        var seen = Set<String>()
        let components = (currentPath.split(separator: ":").map(String.init) + additions)
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }

        return components.joined(separator: ":")
    }
}

private struct ProcessOutput {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

private final class ProcessResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private let continuation: CheckedContinuation<ProcessOutput, Error>

    init(continuation: CheckedContinuation<ProcessOutput, Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<ProcessOutput, Error>) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        continuation.resume(with: result)
    }
}

private enum UsageStatsProcessError: Error, Equatable {
    case commandFailed(String)
    case emptyOutput
    case timeout
}
