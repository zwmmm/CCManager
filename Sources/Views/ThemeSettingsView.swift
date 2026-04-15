import SwiftUI
import UserNotifications

struct ThemeSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var editorManager: EditorManager
    @EnvironmentObject var providerStore: ProviderStore
    @Environment(\.dismiss) private var dismiss

    @State private var showEditorPicker = false
    @State private var selectedCategory: ChineseColor.ColorCategory = .green

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SETTINGS")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            .padding(18)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    // Appearance
                    sectionHeader("APPEARANCE")

                    HStack(spacing: 0) {
                        themeOption("SYSTEM", value: "system", icon: "circle.lefthalf.filled")
                        themeOption("LIGHT",  value: "light",  icon: "sun.max.fill")
                        themeOption("DARK",   value: "dark",   icon: "moon.fill")
                    }
                    .padding(4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)

                    Divider()
                        .padding(.horizontal, 18)

                    // Theme Color
                    sectionHeader("THEME COLOR")

                    colorPickerGrid
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)

                    Divider()
                        .padding(.horizontal, 18)

                    // Editor
                    sectionHeader("EDITOR")

                    // Editor select trigger
                    Button {
                        showEditorPicker.toggle()
                    } label: {
                        HStack(spacing: 10) {
                            if let selected = editorManager.selectedEditor,
                               let icon = editorManager.icon(for: selected.bundleId) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                Text(selected.displayName)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.primary)
                            } else {
                                Image(systemName: "curlybraces")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text("Select editor...")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(showEditorPicker ? themeManager.brandColor.opacity(0.6) : Color.clear, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
                    .popover(isPresented: $showEditorPicker, arrowEdge: .bottom) {
                        EditorPickerPopover(editorManager: editorManager) {
                            showEditorPicker = false
                        }
                    }

                    Divider()
                        .padding(.horizontal, 18)

                    // Data Management
                    sectionHeader("DATA MANAGEMENT")

                    dataManagementSection
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                }
            }

            Spacer()

            Divider()

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(themeManager.brandColor)
            }
            .padding(18)
        }
        .frame(width: 340, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var colorPickerGrid: some View {
        VStack(spacing: 8) {
            // Category picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ChineseColor.ColorCategory.allCases, id: \.self) { category in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedCategory = category
                            }
                        } label: {
                            Text(category.rawValue)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(selectedCategory == category ? themeManager.brandColor.opacity(0.2) : Color.clear)
                                .foregroundStyle(selectedCategory == category ? themeManager.brandColor : .secondary)
                                .contentShape(Rectangle())
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Color grid
            let filteredColors = ColorPalette.colorsByCategory[selectedCategory] ?? []
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(filteredColors) { color in
                    colorButton(for: color)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func colorButton(for color: ChineseColor) -> some View {
        let isSelected = themeManager.themeColorHex == color.hex

        return Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                themeManager.setThemeColor(color)
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(color.color)
                        .frame(width: 32, height: 32)

                    if isSelected {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 2)
                            .frame(width: 32, height: 32)

                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    }
                }

                Text(color.name)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(isSelected ? themeManager.brandColor : .secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(color.name) (\(color.hex))")
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private func themeOption(_ label: String, value: String, icon: String) -> some View {
        let isSelected = themeManager.themePreference == value

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                themeManager.themePreference = value
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? themeManager.brandColor.opacity(0.25) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? themeManager.brandColor : .primary)
    }

    private var dataManagementSection: some View {
        HStack(spacing: 8) {
            Button {
                exportProviders()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 10, weight: .medium))
                    Text("Export")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(themeManager.brandColor.opacity(0.15))
                .clipShape(Capsule())
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                importProviders()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 10, weight: .medium))
                    Text("Import")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(themeManager.brandColor.opacity(0.30))
                .clipShape(Capsule())
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func exportProviders() {
        let panel = NSSavePanel()
        panel.title = "Export Providers"
        panel.nameFieldStringValue = "providers.json"
        panel.allowedContentTypes = [.json]

        panel.begin { [self] response in
            guard response == .OK, let url = panel.url else { return }
            Task {
                do {
                    _ = try await providerStore.exportProviders(to: url)
                    await MainActor.run {
                        postNotification(title: "Export Complete", body: "Exported \(providerStore.providers.count) provider(s).")
                    }
                } catch {
                    await MainActor.run {
                        postNotification(title: "Export Failed", body: error.localizedDescription)
                    }
                }
            }
        }
    }

    private func importProviders() {
        let panel = NSOpenPanel()
        panel.title = "Import Providers"
        panel.nameFieldStringValue = "providers.json"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        panel.begin { [self] response in
            guard response == .OK, let url = panel.url else { return }
            Task {
                do {
                    _ = try await providerStore.importProviders(from: url)
                    await MainActor.run {
                        postNotification(title: "Import Complete", body: "Providers imported successfully.")
                    }
                } catch {
                    await MainActor.run {
                        postNotification(title: "Import Failed", body: error.localizedDescription)
                    }
                }
            }
        }
    }

    private func postNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                center.add(request)
            }
        }
    }
}

// MARK: - Editor Picker Popover

private struct EditorPickerPopover: View {
    @ObservedObject var editorManager: EditorManager
    @EnvironmentObject var themeManager: ThemeManager
    let onSelect: () -> Void

    var body: some View {
        let editors = editorManager.installed

        VStack(spacing: 4) {
            if editors.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                    Text("No supported editors found")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            } else {
                ForEach(editors) { editor in
                    let isSelected = editorManager.selectedBundleId == editor.bundleId

                    Button {
                        editorManager.selectedBundleId = editor.bundleId
                        onSelect()
                    } label: {
                        HStack(spacing: 10) {
                            if let icon = editorManager.icon(for: editor.bundleId) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 22, height: 22)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }

                            Text(editor.displayName)
                                .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .monospaced))
                                .foregroundStyle(isSelected ? themeManager.brandColor : .primary)

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(themeManager.brandColor)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSelected ? themeManager.brandColor.opacity(0.08) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(6)
        .frame(width: 264)
    }
}
