import AppKit
import SwiftUI

final class UsageStatsWindowController: NSWindowController {
    static let shared = UsageStatsWindowController()

    private init() {
        let contentView = UsageStatsView()
            .environmentObject(ThemeManager.shared)
            .environmentObject(UsageStatsManager.shared)

        let hostingView = NSHostingView(rootView: contentView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.title = "Usage Statistics"
        window.appearance = NSApp.appearance
        window.center()
        window.setFrameAutosaveName("CCManagerUsageStatsWindow")

        super.init(window: window)
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
