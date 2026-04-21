import AppKit
import Combine
import CryptoKit
import Foundation

enum UpdateError: LocalizedError {
    case invalidHTTPResponse
    case downloadFailed
    case hashMismatch(expected: String, actual: String)
    case unzipFailed
    case appNotFound
    case replaceFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidHTTPResponse:
            return "更新源响应无效，请稍后重试。"
        case .downloadFailed:
            return "更新包下载失败，请检查网络连接。"
        case .hashMismatch(let expected, let actual):
            return "文件校验失败，可能已损坏或被篡改。\n期望: \(expected.prefix(16))...\n实际: \(actual.prefix(16))..."
        case .unzipFailed:
            return "更新包解压失败，下载文件可能已损坏。"
        case .appNotFound:
            return "解压后未找到 CCManager.app。"
        case .replaceFailed(let reason):
            return "替换应用失败：\(reason)"
        }
    }
}

/// 管理应用热更新的单例类。
/// 使用 GitHub Release 中的 appcast.xml 检查版本，下载 ZIP 后进行 SHA256 校验和原子替换。
final class UpdateManager: NSObject, ObservableObject {
    static let shared = UpdateManager()

    private static let githubRepo = "zwmmm/CCManager"
    private static let appcastURL = URL(string: "https://github.com/\(githubRepo)/releases/latest/download/appcast.xml")!
    private static let releasesURL = URL(string: "https://github.com/\(githubRepo)/releases")!

    @Published var canCheckForUpdates: Bool = true
    @Published var lastUpdateCheckDate: Date?
    @Published var updateInstalled: Bool = false
    @Published var isChecking: Bool = false
    @Published var updateStatus: String = ""

    private let lastInstalledVersionKey = "CCManager.LastInstalledVersion"
    private let session: URLSession
    private var updateWindowController: UpdateWindowController?
    private var automaticCheckTimer: Timer?

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    var isInstallingUpdate: Bool {
        !canCheckForUpdates && !updateStatus.isEmpty && !isChecking
    }

    private override init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 120
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        self.session = URLSession(configuration: configuration)
        super.init()
        checkForUpdateSuccess()
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }

        canCheckForUpdates = false
        isChecking = true
        updateStatus = "Checking..."

        Task {
            do {
                let item = try await fetchLatestUpdate()

                await MainActor.run {
                    self.lastUpdateCheckDate = Date()
                    self.isChecking = false
                    self.canCheckForUpdates = true
                    self.updateStatus = ""
                }

                guard UpdateFeedParser.isVersion(item.shortVersion, newerThan: currentVersion) else {
                    await showNoUpdateAlert()
                    return
                }

                await showUpdateAlert(item)
            } catch {
                await MainActor.run {
                    self.isChecking = false
                    self.canCheckForUpdates = true
                    self.updateStatus = ""
                }
                await showUpdateError(error)
            }
        }
    }

    func checkForUpdatesInBackground() {
        guard canCheckForUpdates, updateWindowController == nil else { return }

        canCheckForUpdates = false

        Task {
            do {
                let item = try await fetchLatestUpdate()

                await MainActor.run {
                    self.lastUpdateCheckDate = Date()
                    self.canCheckForUpdates = true
                }

                guard UpdateFeedParser.isVersion(item.shortVersion, newerThan: currentVersion) else {
                    return
                }

                await showUpdateAlert(item)
            } catch {
                await MainActor.run {
                    self.canCheckForUpdates = true
                }
            }
        }
    }

    func startAutomaticUpdateChecks(interval: TimeInterval = 4 * 60 * 60) {
        automaticCheckTimer?.invalidate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.checkForUpdatesInBackground()
        }

        automaticCheckTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkForUpdatesInBackground()
        }
    }

    func resetUpdateCycle() {
        lastUpdateCheckDate = nil
    }

    private func fetchLatestUpdate() async throws -> UpdateFeedItem {
        let (data, response) = try await session.data(from: Self.appcastURL)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let xml = String(data: data, encoding: .utf8) else {
            throw UpdateError.invalidHTTPResponse
        }
        return try UpdateFeedParser.parse(xml)
    }

    private func performUpdate(_ item: UpdateFeedItem) {
        canCheckForUpdates = false
        updateStatus = "Downloading..."

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            do {
                let appURL = Bundle.main.bundleURL
                let appDirectory = appURL.deletingLastPathComponent()
                let tempDirectory = FileManager.default.temporaryDirectory
                    .appendingPathComponent("CCManagerUpdate-\(UUID().uuidString)", isDirectory: true)
                let zipURL = tempDirectory.appendingPathComponent("CCManager.app.zip")
                let extractURL = tempDirectory.appendingPathComponent("Extracted", isDirectory: true)

                try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: extractURL, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: tempDirectory) }

                let (downloadURL, response) = try await self.session.download(from: item.downloadURL)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw UpdateError.downloadFailed
                }

                try FileManager.default.moveItem(at: downloadURL, to: zipURL)

                if let expectedHash = item.sha256, !expectedHash.isEmpty {
                    await self.updateStatus("Verifying...")
                    let zipData = try Data(contentsOf: zipURL)
                    let actualHash = SHA256.hash(data: zipData).map { String(format: "%02x", $0) }.joined()
                    guard actualHash.lowercased() == expectedHash.lowercased() else {
                        throw UpdateError.hashMismatch(expected: expectedHash, actual: actualHash)
                    }
                }

                await self.updateStatus("Extracting...")
                try self.unzip(zipURL: zipURL, destinationURL: extractURL)

                guard let newAppURL = self.findApp(in: extractURL) else {
                    throw UpdateError.appNotFound
                }

                await self.updateStatus("Installing...")
                try self.clearQuarantineAttribute(at: newAppURL)
                _ = try FileManager.default.replaceItemAt(
                    appURL,
                    withItemAt: newAppURL,
                    backupItemName: nil,
                    options: .usingNewMetadataOnly
                )

                await self.updateStatus("Relaunching...")
                await self.relaunch(appURL: appDirectory.appendingPathComponent("CCManager.app"))
            } catch {
                await MainActor.run {
                    self.canCheckForUpdates = true
                    self.updateStatus = ""
                }
                await self.showUpdateError(error)
            }
        }
    }

    private func unzip(zipURL: URL, destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-oq", zipURL.path, "-d", destinationURL.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw UpdateError.unzipFailed
        }
    }

    private func findApp(in directory: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let url as URL in enumerator {
            if url.lastPathComponent == "CCManager.app" {
                return url
            }
        }

        return nil
    }

    private func clearQuarantineAttribute(at url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-rd", "com.apple.quarantine", url.path]
        try process.run()
        process.waitUntilExit()
    }

    @MainActor
    private func relaunch(appURL: URL) {
        let escapedPath = appURL.path.replacingOccurrences(of: "'", with: "'\\''")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 0.5; /usr/bin/open -n '\(escapedPath)'"]
        try? process.run()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApplication.shared.terminate(nil)
        }
    }

    @MainActor
    private func showUpdateAlert(_ item: UpdateFeedItem) {
        updateWindowController?.close()
        let controller = UpdateWindowController(
            updateItem: item,
            onInstall: { [weak self] in
                self?.performUpdate(item)
            },
            onSkip: { [weak self] in
                self?.updateWindowController?.closeAfterAction()
                self?.updateWindowController = nil
            }
        )

        updateWindowController = controller
        controller.show()
    }

    @MainActor
    private func showNoUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = "已是最新版本"
        alert.informativeText = "当前版本已是最新，无需更新。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    @MainActor
    private func showUpdateError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "更新失败"
        alert.informativeText = "\(error.localizedDescription)\n\n请手动下载安装。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开下载页")
        alert.addButton(withTitle: "取消")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(Self.releasesURL)
        }
    }

    @MainActor
    private func updateStatus(_ message: String) {
        updateStatus = message
    }

    private func checkForUpdateSuccess() {
        let defaults = UserDefaults.standard
        let lastVersion = defaults.string(forKey: lastInstalledVersionKey) ?? ""
        let currentVersion = "\(currentVersion) (\(currentBuild))"

        if !lastVersion.isEmpty && lastVersion != currentVersion {
            updateInstalled = true
        }

        defaults.set(currentVersion, forKey: lastInstalledVersionKey)
    }
}
