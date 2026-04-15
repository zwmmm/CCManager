import AppKit
import Foundation

struct KnownEditor: Identifiable, Equatable {
    let id: String          // = bundleId，作为唯一标识
    let displayName: String
    let bundleId: String
    let cliCommand: String
}

final class EditorManager: ObservableObject {
    static let shared = EditorManager()

    @Published var selectedBundleId: String? {
        didSet { UserDefaults.standard.set(selectedBundleId, forKey: "selectedEditorBundleId") }
    }

    /// 已安装的编辑器（缓存，只在首次访问或刷新时计算）
    private(set) var installedEditors: [KnownEditor] = []

    // 主流编辑器列表（按常用度排序）
    static let all: [KnownEditor] = [
        KnownEditor(id: "com.todesktop.230313mzl4w4u92", displayName: "Cursor",           bundleId: "com.todesktop.230313mzl4w4u92", cliCommand: "cursor"),
        KnownEditor(id: "com.microsoft.VSCode",           displayName: "VS Code",          bundleId: "com.microsoft.VSCode",           cliCommand: "code"),
        KnownEditor(id: "com.microsoft.VSCodeInsiders",   displayName: "VS Code Insiders", bundleId: "com.microsoft.VSCodeInsiders",   cliCommand: "code-insiders"),
        KnownEditor(id: "com.exafunction.windsurf",        displayName: "Windsurf",         bundleId: "com.exafunction.windsurf",        cliCommand: "windsurf"),
        KnownEditor(id: "dev.zed.Zed",                    displayName: "Zed",              bundleId: "dev.zed.Zed",                    cliCommand: "zed"),
        KnownEditor(id: "dev.zed.Zed-Preview",            displayName: "Zed Preview",      bundleId: "dev.zed.Zed-Preview",            cliCommand: "zed"),
        KnownEditor(id: "com.vscodium",                   displayName: "VSCodium",         bundleId: "com.vscodium",                   cliCommand: "codium"),
        KnownEditor(id: "com.jetbrains.fleet",            displayName: "Fleet",            bundleId: "com.jetbrains.fleet",            cliCommand: "fleet"),
        KnownEditor(id: "com.sublimetext.4",              displayName: "Sublime Text",     bundleId: "com.sublimetext.4",              cliCommand: "subl"),
        KnownEditor(id: "com.sublimetext.3",              displayName: "Sublime Text 3",   bundleId: "com.sublimetext.3",              cliCommand: "subl"),
        KnownEditor(id: "com.apple.dt.Xcode",             displayName: "Xcode",            bundleId: "com.apple.dt.Xcode",             cliCommand: "xed"),
        KnownEditor(id: "com.panic.Nova",                 displayName: "Nova",             bundleId: "com.panic.Nova",                 cliCommand: "nova"),
        KnownEditor(id: "com.macromates.TextMate",        displayName: "TextMate",         bundleId: "com.macromates.TextMate",        cliCommand: "mate"),
    ]

    var installed: [KnownEditor] {
        if installedEditors.isEmpty {
            refreshInstalledEditors()
        }
        return installedEditors
    }

    var selectedEditor: KnownEditor? {
        guard let id = selectedBundleId else { return nil }
        return Self.all.first { $0.bundleId == id }
    }

    /// 从 app bundle 取真实图标
    func icon(for bundleId: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 32, height: 32)
        return icon
    }

    func refreshInstalledEditors() {
        installedEditors = Self.all.filter {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleId) != nil
        }
    }

    private init() {
        selectedBundleId = UserDefaults.standard.string(forKey: "selectedEditorBundleId")
        refreshInstalledEditors()
    }
}
