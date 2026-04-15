import AppKit
import SwiftUI

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        statusBarController = StatusBarController()

        let contentView = ContentView()
            .environmentObject(ProviderStore.shared)
            .environmentObject(ThemeManager.shared)
            .environmentObject(EditorManager.shared)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
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
        editMenu.addItem(withTitle: "Redo",       action: Selector(("redo:")),                  keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut",        action: #selector(NSText.cut(_:)),            keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy",       action: #selector(NSText.copy(_:)),           keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste",      action: #selector(NSText.paste(_:)),          keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)),      keyEquivalent: "a")

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
