import Foundation

struct AppShortcut: Identifiable, Equatable {
    let id: String
    let title: String
    let displayLabel: String

    static let defaultShortcuts: [AppShortcut] = [
        AppShortcut(id: "new-provider", title: "New Provider", displayLabel: "⌘T"),
        AppShortcut(id: "edit-selected", title: "Edit Selected", displayLabel: "⌘E"),
        AppShortcut(id: "apply-selected", title: "Apply Selected", displayLabel: "⌘↩"),
        AppShortcut(id: "settings", title: "Settings", displayLabel: "⌘,"),
        AppShortcut(id: "close-window", title: "Close Window", displayLabel: "⌘W")
    ]
}
