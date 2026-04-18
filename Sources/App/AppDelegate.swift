import AppKit
import SwiftUI

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let restoreMainWindow = Notification.Name("restoreMainWindow")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var window: NSWindow?
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        statusBarController = StatusBarController()

        if #available(macOS 13.0, *) {
            LaunchAtLoginManager.shared.bootstrapDefaultPreference()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRestoreMainWindow),
            name: .restoreMainWindow,
            object: nil
        )

        let contentView = ContentView()
            .environmentObject(ProviderStore.shared)
            .environmentObject(ThemeManager.shared)
            .environmentObject(EditorManager.shared)
            .environmentObject(UpdateManager.shared)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window?.isReleasedWhenClosed = false
        window?.center()
        window?.setFrameAutosaveName("CCManagerMainWindow")
        window?.contentView = NSHostingView(rootView: contentView)
        window?.title = "CC Manager"
        window?.titlebarAppearsTransparent = false
        window?.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }

    @objc private func handleRestoreMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = window {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            window?.makeKeyAndOrderFront(nil)
        }
        return true
    }

    // MARK: - Menu

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit CC Manager", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // Edit menu — required for Cut/Copy/Paste/Select All to work in text fields
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo",       action: #selector(UndoManager.undo),          keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo",       action: #selector(UndoManager.redo),        keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut",        action: #selector(NSText.cut(_:)),            keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy",       action: #selector(NSText.copy(_:)),         keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste",      action: #selector(NSText.paste(_:)),        keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)),     keyEquivalent: "a")

        // Window menu with shortcuts
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }
}