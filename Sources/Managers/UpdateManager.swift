import AppKit
import Sparkle
import Combine

/// 自定义 UserDriver，将更新流程桥接到自定义弹窗
final class UpdateUserDriver: NSObject, SPUUserDriver {
    private let standardDriver: SPUStandardUserDriver
    private var updateWindowController: UpdateWindowController?

    override init() {
        self.standardDriver = SPUStandardUserDriver(hostBundle: .main, delegate: nil)
        super.init()
    }

    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping @Sendable (SUUpdatePermissionResponse) -> Void) {
        standardDriver.show(request, reply: reply)
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        standardDriver.showUserInitiatedUpdateCheck(cancellation: cancellation)
    }

    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping @Sendable (SPUUserUpdateChoice) -> Void) {
        updateWindowController = UpdateWindowController(
            appcastItem: appcastItem,
            onInstall: { [weak self] in
                reply(.install)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.closeWindowController()
                }
            },
            onSkip: { [weak self] in
                reply(.skip)
                self?.closeWindowController()
            },
            onDismiss: { [weak self] in
                reply(.skip)
                self?.closeWindowController()
            }
        )
        updateWindowController?.show()
    }

    private func closeWindowController() {
        updateWindowController?.close()
        updateWindowController = nil
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {
        standardDriver.showUpdateReleaseNotes(with: downloadData)
    }

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {
        standardDriver.showUpdateReleaseNotesFailedToDownloadWithError(error)
    }

    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        standardDriver.showUpdateNotFoundWithError(error, acknowledgement: acknowledgement)
    }

    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        standardDriver.showUpdaterError(error, acknowledgement: acknowledgement)
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        standardDriver.showDownloadInitiated(cancellation: cancellation)
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        standardDriver.showDownloadDidReceiveExpectedContentLength(expectedContentLength)
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        standardDriver.showDownloadDidReceiveData(ofLength: length)
    }

    func showDownloadDidStartExtractingUpdate() {
        closeWindowController()
        standardDriver.showDownloadDidStartExtractingUpdate()
    }

    func showExtractionReceivedProgress(_ progress: Double) {
        standardDriver.showExtractionReceivedProgress(progress)
    }

    func showReady(toInstallAndRelaunch reply: @escaping @Sendable (SPUUserUpdateChoice) -> Void) {
        NSApp.activate(ignoringOtherApps: true)
        standardDriver.showReady(toInstallAndRelaunch: reply)
    }

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        if !applicationTerminated {
            NSApp.stopModal()
            for window in NSApp.windows {
                window.close()
            }
            retryTerminatingApplication()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                exit(0)
            }
        }
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        standardDriver.showUpdateInstalledAndRelaunched(relaunched, acknowledgement: acknowledgement)
    }

    func showUpdateInFocus() {
        standardDriver.showUpdateInFocus()
    }

    func dismissUpdateInstallation() {
        standardDriver.dismissUpdateInstallation()
    }
}

/// 管理应用自动更新的单例类
/// 封装 Sparkle 的 SPUUpdater，提供 SwiftUI 友好的接口
final class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {

    // MARK: - Singleton

    static let shared = UpdateManager()

    // MARK: - Published Properties

    /// 是否可以检查更新（用于 UI 按钮状态绑定）
    @Published var canCheckForUpdates: Bool = false

    /// 最后一次检查更新的时间
    @Published var lastUpdateCheckDate: Date?

    /// 更新是否成功安装（应用启动后检测到新版本安装完成）
    @Published var updateInstalled: Bool = false

    // MARK: - Private Properties

    private var updater: SPUUpdater!
    private let userDriver: UpdateUserDriver
    private var cancellables = Set<AnyCancellable>()
    private let lastInstalledVersionKey = "CCManager.LastInstalledVersion"

    // MARK: - Computed Properties

    /// 当前应用版本号
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    /// 当前构建号
    var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    /// 是否启用自动检查
    var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }

    /// 自动检查间隔（秒）
    var updateCheckInterval: TimeInterval {
        get { updater.updateCheckInterval }
        set { updater.updateCheckInterval = newValue }
    }

    // MARK: - Initialization

    private override init() {
        // 初始化自定义 UserDriver
        self.userDriver = UpdateUserDriver()

        super.init()

        // 直接创建 SPUUpdater，手动传入自定义 userDriver
        self.updater = SPUUpdater(
            hostBundle: .main,
            applicationBundle: .main,
            userDriver: userDriver,
            delegate: self
        )

        setupBindings()

        // 检测更新是否成功安装（版本发生变化）
        checkForUpdateSuccess()

        // 启动更新器
        do {
            try updater.start()
        } catch {
            print("Failed to start updater: \(error)")
        }
    }

    // MARK: - Private Methods

    // MARK: - SPUUpdaterDelegate

    func updaterWillRelaunchAfterInstalling(_ updater: SPUUpdater) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.terminate(nil)
        }
    }

    private func setupBindings() {
        // 使用 KVO 绑定 canCheckForUpdates 属性
        // Sparkle 的 canCheckForUpdates 是 KVO 兼容的
        updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)

        // 绑定最后检查时间
        updater.publisher(for: \.lastUpdateCheckDate)
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastUpdateCheckDate)
    }

    /// 检查更新是否成功安装
    /// 如果当前版本与上次保存的版本不同，说明刚完成更新
    private func checkForUpdateSuccess() {
        let defaults = UserDefaults.standard
        let lastVersion = defaults.string(forKey: lastInstalledVersionKey) ?? ""
        let currentVersion = "\(currentVersion) (\(currentBuild))"

        if !lastVersion.isEmpty && lastVersion != currentVersion {
            updateInstalled = true
        }

        // 保存当前版本
        defaults.set(currentVersion, forKey: lastInstalledVersionKey)
    }

    // MARK: - Public Methods

    /// 用户手动检查更新
    /// 会显示自定义更新弹窗
    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        updater.checkForUpdates()
    }

    /// 后台静默检查更新
    /// 不会显示 UI，只在发现新版本时通知用户
    func checkForUpdatesInBackground() {
        updater.checkForUpdatesInBackground()
    }

    /// 重置更新周期
    /// 在更改 feed URL 或渠道后调用
    func resetUpdateCycle() {
        updater.resetUpdateCycle()
    }
}