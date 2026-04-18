import Foundation
import AppKit

/// Manages CLI installation to system PATH
/// Downloads CLI from GitHub releases and installs to /usr/local/bin
final class CLIInstallationManager: ObservableObject {
    static let shared = CLIInstallationManager()

    @Published private(set) var isInstalled: Bool = false
    @Published private(set) var installStatus: String = ""
    @Published private(set) var isInstalling: Bool = false

    private let cliBinaryName = "ccmanager"
    private lazy var targetPath = "/usr/local/bin/\(cliBinaryName)"

    private init() {
        checkInstallationStatus()
    }

    // MARK: - Public

    /// Check if ccmanager is already in PATH
    func checkInstallationStatus() {
        // Check if ccmanager command exists in PATH
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = [cliBinaryName]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

            DispatchQueue.main.async {
                self.isInstalled = (path != nil && !path!.isEmpty)
                self.installStatus = self.isInstalled
                    ? "CLI is installed at \(path ?? self.targetPath)"
                    : "CLI is not installed"
            }
        } catch {
            DispatchQueue.main.async {
                self.isInstalled = false
                self.installStatus = "Failed to check installation status"
            }
        }
    }

    /// Install CLI to PATH by downloading from GitHub
    func installCLI() async -> Bool {
        guard !isInstalling else { return false }

        await MainActor.run {
            isInstalling = true
            installStatus = "Downloading..."
        }

        do {
            // 1. Download CLI binary from GitHub releases
            let cliUrl = "https://github.com/zwmmm/CCManager/releases/latest/download/ccmanager"
            guard let url = URL(string: cliUrl) else {
                throw NSError(domain: "CLIInstallationManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            }

            let (tempURL, response) = try await URLSession.shared.download(from: url)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NSError(domain: "CLIInstallationManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Download failed"])
            }

            // 2. Make it executable
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempURL.path)

            // 3. Install to /usr/local/bin with admin privileges
            try installBinaryWithAdminPrivileges(from: tempURL.path, to: targetPath)

            // 4. Make sure /usr/local/bin is in PATH
            try ensurePathInShellConfig(path: "/usr/local/bin")

            await MainActor.run {
                self.isInstalled = true
                self.installStatus = "CLI installed successfully at \(self.targetPath)"
                self.isInstalling = false
            }
            return true

        } catch {
            await MainActor.run {
                self.installStatus = "Install failed: \(error.localizedDescription)"
                self.isInstalling = false
            }
            return false
        }
    }

    /// Uninstall CLI from PATH
    func uninstallCLI() async -> Bool {
        guard !isInstalling else { return false }

        await MainActor.run {
            isInstalling = true
            installStatus = "Uninstalling..."
        }

        do {
            let fileManager = FileManager.default

            if fileManager.fileExists(atPath: targetPath) {
                try removeSymlinkWithAdminPrivileges(at: targetPath)
            }

            await MainActor.run {
                self.isInstalled = false
                self.installStatus = "CLI uninstalled"
                self.isInstalling = false
            }
            return true

        } catch {
            await MainActor.run {
                self.installStatus = "Uninstall failed: \(error.localizedDescription)"
                self.isInstalling = false
            }
            return false
        }
    }

    /// Install binary file using osascript to request admin privileges
    private func installBinaryWithAdminPrivileges(from sourcePath: String, to targetPath: String) throws {
        let script = """
        do shell script "cp '\(sourcePath)' '\(targetPath)' && chmod +x '\(targetPath)'" with administrator privileges
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let exitCode = process.terminationStatus
        if exitCode != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
            throw NSError(domain: "CLIInstallationManager", code: Int(exitCode), userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
    }

    /// Remove symlink using osascript to request admin privileges
    private func removeSymlinkWithAdminPrivileges(at path: String) throws {
        let script = """
        do shell script "rm '\(path)'" with administrator privileges
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let exitCode = process.terminationStatus
        if exitCode != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
            throw NSError(domain: "CLIInstallationManager", code: Int(exitCode), userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
    }

    /// Ensure a path is in shell config (~/.zshrc)
    private func ensurePathInShellConfig(path: String) throws {
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let shellConfig = homeDir.appendingPathComponent(".zshrc")
        let pathLine = "export PATH=\"/usr/local/bin:$PATH\""

        // Check if already in PATH
        if let content = try? String(contentsOf: shellConfig, encoding: .utf8) {
            if content.contains(path) || content.contains("usr/local/bin") {
                return
            }
        }

        // Append PATH export to .zshrc
        let pathExport = "\n# Added by CCManager\n\(pathLine)\n"

        if fileManager.fileExists(atPath: shellConfig.path) {
            let fileHandle = try FileHandle(forWritingTo: shellConfig)
            fileHandle.seekToEndOfFile()
            if let data = pathExport.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        } else {
            try pathExport.write(to: shellConfig, atomically: true, encoding: .utf8)
        }
    }
}
