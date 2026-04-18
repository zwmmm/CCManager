import Foundation
import ServiceManagement

@available(macOS 13.0, *)
final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()

    private let userDefaultsKey = "launchAtLoginEnabled"

    /// Current enabled state
    private(set) var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: userDefaultsKey)
        }
    }

    /// Last error that occurred during registration/unregistration
    private(set) var lastError: Error?

    private init() {
        // Load cached preference (non-blocking, status will be refreshed async)
        isEnabled = UserDefaults.standard.object(forKey: userDefaultsKey) as? Bool ?? true
    }

    /// Bootstrap the default preference without blocking app launch.
    /// SMAppService.mainApp.status is a synchronous XPC call that can take 5+ seconds.
    func bootstrapDefaultPreference() {
        Task {
            await refreshStatusAsync()
        }
    }

    /// Refresh status asynchronously for UI sync.
    func refreshStatusAsync() async {
        let status = SMAppService.mainApp.status
        let enabled = (status == .enabled)
        if isEnabled != enabled {
            isEnabled = enabled
        }
    }

    /// Enable or disable launch at login.
    /// - Returns: true if operation succeeded
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled {
                    return true
                }
                try SMAppService.mainApp.register()
            } else {
                if SMAppService.mainApp.status != .enabled {
                    return true
                }
                try SMAppService.mainApp.unregister()
            }
            isEnabled = enabled
            lastError = nil
            return true
        } catch {
            lastError = error
            return false
        }
    }

    /// Toggle current state.
    func toggle() {
        setEnabled(!isEnabled)
    }
}