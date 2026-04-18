import Foundation
import AppKit

/// Manages CLI installation to system PATH
/// Handles symlink creation in /usr/local/bin and PATH configuration
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

    /// Install CLI to PATH by creating symlink in /usr/local/bin/
    func installCLI() async -> Bool {
        guard !isInstalling else { return false }

        await MainActor.run {
            isInstalling = true
            installStatus = "Installing..."
        }

        do {
            // 1. Find the CLI binary inside the app bundle
            guard let cliPath = findCLIBinary() else {
                await MainActor.run {
                    installStatus = "Error: CLI binary not found in app bundle"
                    isInstalling = false
                }
                return false
            }

            // 2. Check if /usr/local/bin exists, create if needed
            let fileManager = FileManager.default
            let targetDir = URL(fileURLWithPath: "/usr/local/bin")

            if !fileManager.fileExists(atPath: targetDir.path) {
                try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
            }

            // 3. Remove existing symlink if present
            if fileManager.fileExists(atPath: targetPath) {
                try fileManager.removeItem(atPath: targetPath)
            }

            // 4. Create symlink (requires admin privileges via macOS prompt)
            try fileManager.createSymbolicLink(
                atPath: targetPath,
                withDestinationPath: cliPath
            )

            // 5. Make sure /usr/local/bin is in PATH (check shell config)
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
                try fileManager.removeItem(atPath: targetPath)
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

    /// Get the path to CLI binary inside the app bundle
    /// Path: CCManager.app/Contents/MacOS/ccmanager (from Xcode build) or in Resources
    private func findCLIBinary() -> String? {
        let fileManager = FileManager.default

        // Try multiple possible locations
        let possiblePaths = [
            // Built product (Xcode builds CLI into this location inside app bundle)
            Bundle.main.bundlePath + "/Contents/MacOS/ccmanager",
            // Resources folder
            Bundle.main.bundlePath + "/Contents/Resources/ccmanager",
            // macOS binary location
            Bundle.main.bundlePath + "/Contents/MacOS/ccmanager",
        ]

        for path in possiblePaths {
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }

        // If not found in bundle, fall back to DerivedData build product
        // This is useful during development
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let derivedDataPath = homeDir
            .appendingPathComponent("Library/Developer/Xcode/DerivedData")
            .appendingPathComponent("CCManager-hdwlixpvplobhihghnnyvqzfrxaa")
            .appendingPathComponent("Build/Products/Debug/ccmanager")
            .path

        if fileManager.fileExists(atPath: derivedDataPath) {
            return derivedDataPath
        }

        return nil
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
