import AppKit
import SwiftUI

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var themePreference: String {
        didSet {
            UserDefaults.standard.set(themePreference, forKey: "themePreference")
            applyTheme()
        }
    }

    @Published var themeColorHex: String {
        didSet {
            UserDefaults.standard.set(themeColorHex, forKey: "themeColorHex")
            applyThemeColor()
        }
    }

    // Cached derived values — updated only when themeColorHex changes
    @Published private(set) var cachedBrandColor: Color = .green
    @Published private(set) var cachedBrandNSColor: NSColor = .systemGreen
    @Published private(set) var cachedThemeColor: ChineseColor = ColorPalette.defaultBrandColor

    private init() {
        self.themePreference = UserDefaults.standard.string(forKey: "themePreference") ?? "system"
        self.themeColorHex = UserDefaults.standard.string(forKey: "themeColorHex") ?? ColorPalette.defaultBrandColor.hex
        applyTheme()
        applyThemeColor()
    }

    var colorScheme: ColorScheme? {
        switch themePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var brandColor: Color { cachedBrandColor }
    var brandNSColor: NSColor { cachedBrandNSColor }
    var currentThemeColor: ChineseColor { cachedThemeColor }

    private func applyTheme() {
        NSApp.appearance = nil
        switch themePreference {
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            break
        }
    }

    private func applyThemeColor() {
        cachedBrandColor = Color(hex: themeColorHex)
        cachedBrandNSColor = NSColor(hex: themeColorHex) ?? .systemGreen
        cachedThemeColor = ColorPalette.allColors.first { $0.hex == themeColorHex } ?? ColorPalette.defaultBrandColor
    }

    func setThemeColor(_ color: ChineseColor) {
        themeColorHex = color.hex
    }
}
