import Foundation
import Sparkle
import Combine

/// 管理应用自动更新的单例类
/// 封装 Sparkle 的 SPUStandardUpdaterController，提供 SwiftUI 友好的接口
final class UpdateManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = UpdateManager()

    // MARK: - Published Properties

    /// 是否可以检查更新（用于 UI 按钮状态绑定）
    @Published var canCheckForUpdates: Bool = false

    /// 最后一次检查更新的时间
    @Published var lastUpdateCheckDate: Date?

    // MARK: - Private Properties

    private let updaterController: SPUStandardUpdaterController
    private var cancellables = Set<AnyCancellable>()

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
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }

    /// 自动检查间隔（秒）
    var updateCheckInterval: TimeInterval {
        get { updaterController.updater.updateCheckInterval }
        set { updaterController.updater.updateCheckInterval = newValue }
    }

    // MARK: - Initialization

    private override init() {
        // 初始化 Sparkle 更新控制器
        // startingUpdater: true 表示立即启动更新器
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        super.init()

        setupBindings()
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // 使用 KVO 绑定 canCheckForUpdates 属性
        // Sparkle 的 canCheckForUpdates 是 KVO 兼容的
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)

        // 绑定最后检查时间
        updaterController.updater.publisher(for: \.lastUpdateCheckDate)
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastUpdateCheckDate)
    }

    // MARK: - Public Methods

    /// 用户手动检查更新
    /// 会显示 Sparkle 标准更新对话框
    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        updaterController.checkForUpdates(nil)
    }

    /// 后台静默检查更新
    /// 不会显示 UI，只在发现新版本时通知用户
    func checkForUpdatesInBackground() {
        updaterController.updater.checkForUpdatesInBackground()
    }

    /// 重置更新周期
    /// 在更改 feed URL 或渠道后调用
    func resetUpdateCycle() {
        updaterController.updater.resetUpdateCycle()
    }
}
