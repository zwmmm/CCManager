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

    var providerGroupingEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "providerGroupingEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "providerGroupingEnabled") }
    }

    var providerGroupCollapsed_claudeCode: Bool {
        get { UserDefaults.standard.bool(forKey: "providerGroupCollapsed_claudeCode") }
        set { UserDefaults.standard.set(newValue, forKey: "providerGroupCollapsed_claudeCode") }
    }

    var providerGroupCollapsed_codex: Bool {
        get { UserDefaults.standard.bool(forKey: "providerGroupCollapsed_codex") }
        set { UserDefaults.standard.set(newValue, forKey: "providerGroupCollapsed_codex") }
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

enum AppTheme {
    static let background = Color(nsColor: NSColor(light: "F6F7F2", dark: "0B0E13"))
    static let sidebar = Color(nsColor: NSColor(light: "EEF0E8", dark: "11151B"))
    static let surface = Color(nsColor: NSColor(light: "FFFFFF", dark: "15191F"))
    static let surfaceElevated = Color(nsColor: NSColor(light: "FAFBF7", dark: "1A1E25"))
    static let separator = Color(nsColor: NSColor(light: "D9DCD2", dark: "2B3038"))
    static let textPrimary = Color(nsColor: NSColor(light: "171A1F", dark: "F4F2EA"))
    static let textSecondary = Color(nsColor: NSColor(light: "5F655F", dark: "A3A6AD"))
    static let textTertiary = Color(nsColor: NSColor(light: "8B9089", dark: "737780"))
    static let subtleFill = Color(nsColor: NSColor(light: "E5E8DE", dark: "FFFFFF", lightAlpha: 0.58, darkAlpha: 0.04))
    static let hoverFill = Color(nsColor: NSColor(light: "DDE1D6", dark: "FFFFFF", lightAlpha: 0.72, darkAlpha: 0.06))
    static let cardFill = Color(nsColor: NSColor(light: "FFFFFF", dark: "FFFFFF", lightAlpha: 0.78, darkAlpha: 0.04))
    static let cardStroke = Color(nsColor: NSColor(light: "C9CEC1", dark: "FFFFFF", lightAlpha: 0.8, darkAlpha: 0.08))
    static let shadow = Color(nsColor: NSColor(light: "000000", dark: "000000", lightAlpha: 0.09, darkAlpha: 0.24))
}

private extension NSColor {
    convenience init(light: String, dark: String, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) {
        self.init(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let color = NSColor(hex: isDark ? dark : light) ?? (isDark ? .black : .white)
            return color.withAlphaComponent(isDark ? darkAlpha : lightAlpha)
        }
    }
}
