import SwiftUI
import UserNotifications

struct ThemeSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var editorManager: EditorManager
    @EnvironmentObject var providerStore: ProviderStore
    @EnvironmentObject var updateManager: UpdateManager
    @EnvironmentObject var cliInstaller: CLIInstallationManager
    @Environment(\.dismiss) private var dismiss

    @State private var showEditorPicker = false
    @State private var selectedCategory: ChineseColor.ColorCategory = .group0
    @State private var launchAtLoginEnabled = {
        if #available(macOS 13.0, *) {
            return LaunchAtLoginManager.shared.isEnabled
        }
        return false
    }()

    // MARK: - Design Tokens
    private let horizontalPadding: CGFloat = 18
    private let sectionGap: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            headerView

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: sectionGap) {
                    appearanceSection
                    colorSection
                    generalSection
                    cliSection
                    aboutSection
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 12)
            }

            footerView
        }
        .frame(width: 340)
        .background(
            ZStack {
                AppTheme.background

                LinearGradient(
                    colors: [
                        AppTheme.surface.opacity(0.42),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.separator)
                .frame(height: 1)
        }
        .fontDesign(.monospaced)
        .task {
            refreshInstallationStates()
        }
    }

    private func refreshInstallationStates() {
        cliInstaller.checkInstallationStatus()

        if #available(macOS 13.0, *) {
            Task {
                launchAtLoginEnabled = await LaunchAtLoginManager.shared.refreshStatusAsync()
            }
        }
    }

    private var headerView: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Theme, editor, and runtime integrations")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(AppTheme.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AppTheme.cardStroke, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var footerView: some View {
        HStack {
            Spacer()

            Button("Done") {
                dismiss()
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .buttonStyle(.borderedProminent)
            .tint(themeManager.brandColor)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 12)
        .background(AppTheme.surface.opacity(0.38))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.separator)
                .frame(height: 1)
        }
    }

    private var appearanceSection: some View {
        sectionCard {
            sectionHeader("Appearance")

            HStack(spacing: 8) {
                themeOption("System", value: "system", icon: "circle.lefthalf.filled")
                themeOption("Light", value: "light", icon: "sun.max.fill")
                themeOption("Dark", value: "dark", icon: "moon.fill")
            }
        }
    }

    private var colorSection: some View {
        sectionCard {
            sectionHeader("Theme Color")
            colorPickerGrid
        }
    }

    private var generalSection: some View {
        sectionCard {
            sectionHeader("General")

            VStack(spacing: 0) {
                editorSettingRow
                .popover(isPresented: $showEditorPicker, arrowEdge: .bottom) {
                    EditorPickerPopover(editorManager: editorManager) {
                        showEditorPicker = false
                    }
                }

                separatorLine

                settingToggleRow(
                    title: "Provider Grouping",
                    isOn: Binding(
                        get: { ThemeManager.shared.providerGroupingEnabled },
                        set: { newValue in
                            let wasEnabled = ThemeManager.shared.providerGroupingEnabled
                            ThemeManager.shared.providerGroupingEnabled = newValue
                            if !wasEnabled && newValue {
                                ProviderStore.shared.reassignSortOrderOnGroupingEnabled()
                            }
                        }
                    )
                )

                if #available(macOS 13.0, *) {
                    separatorLine

                    settingToggleRow(
                        title: "Launch at Login",
                        isOn: Binding(
                            get: { launchAtLoginEnabled },
                            set: { newValue in
                                launchAtLoginEnabled = newValue
                                if !LaunchAtLoginManager.shared.setEnabled(newValue) {
                                    launchAtLoginEnabled = LaunchAtLoginManager.shared.isEnabled
                                }
                            }
                        )
                    )
                }

                separatorLine

                HStack(spacing: 10) {
                    Text("Import / Export")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    HStack(spacing: 6) {
                        iconActionButton(systemName: "square.and.arrow.up") {
                            exportProviders()
                        }

                        iconActionButton(systemName: "square.and.arrow.down") {
                            importProviders()
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Color Picker Grid
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
                                .background(selectedCategory == category ? themeManager.brandColor.opacity(0.14) : AppTheme.cardFill)
                                .foregroundStyle(selectedCategory == category ? themeManager.brandColor : AppTheme.textSecondary)
                                .contentShape(Rectangle())
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(selectedCategory == category ? themeManager.brandColor.opacity(0.18) : AppTheme.cardStroke, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Color grid
            let filteredColors = ColorPalette.colorsByCategory[selectedCategory] ?? []
            let columns = Array(repeating: GridItem(.fixed(52), spacing: 8), count: 5)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(filteredColors) { color in
                    colorButton(for: color)
                }
            }
            .padding(8)
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
                        .frame(width: 30, height: 30)

                    if isSelected {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 2)
                            .frame(width: 30, height: 30)

                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    }
                }

                Text(color.name)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(isSelected ? themeManager.brandColor : AppTheme.textSecondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(color.name) (\(color.hex))")
    }

    // MARK: - Section Header
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textTertiary)
            Spacer()
        }
        .padding(.bottom, 8)
    }

    // MARK: - Theme Option
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
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(isSelected ? themeManager.brandColor.opacity(0.14) : AppTheme.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? themeManager.brandColor.opacity(0.18) : AppTheme.cardStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? themeManager.brandColor : AppTheme.textPrimary)
    }

    // MARK: - CLI Section
    private var cliSection: some View {
        sectionCard {
            sectionHeader("CLI")

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CLI Path")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)

                    if !cliInstaller.installStatus.isEmpty {
                        Text(cliInstaller.installStatus)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                if cliInstaller.isInstalling {
                    ProgressView()
                        .scaleEffect(0.72)
                        .frame(width: 20, height: 20)
                } else {
                    Button {
                        Task {
                            if cliInstaller.isInstalled {
                                _ = await cliInstaller.uninstallCLI()
                            } else {
                                _ = await cliInstaller.installCLI()
                            }
                        }
                    } label: {
                        Text(cliInstaller.isInstalled ? "Remove" : "Install")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(cliInstaller.isInstalled ? .red : themeManager.brandColor)
                }
            }
        }
    }

    // MARK: - About Section
    private var aboutSection: some View {
        sectionCard {
            sectionHeader("About")

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Version")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text(updateManager.currentVersion)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Spacer()

                Button {
                    updateManager.checkForUpdates()
                } label: {
                    HStack(spacing: 6) {
                        if updateManager.isChecking {
                            ProgressView()
                                .scaleEffect(0.55)
                                .frame(width: 10, height: 10)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10, weight: .medium))
                        }
                        Text("Check for Updates")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(themeManager.brandColor.opacity(0.12))
                    .overlay(
                        Capsule().stroke(themeManager.brandColor.opacity(0.16), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!updateManager.canCheckForUpdates)
                .opacity(updateManager.canCheckForUpdates ? 1.0 : 0.5)
            }
        }
    }

    private var separatorLine: some View {
        Rectangle()
            .fill(AppTheme.separator)
            .frame(height: 1)
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(12)
        .background(AppTheme.cardFill)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 5)
    }

    private func settingToggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(themeManager.brandColor)
        }
        .padding(.vertical, 8)
    }

    private func iconActionButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .medium))
                .frame(width: 26, height: 26)
                .background(AppTheme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.cardStroke, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var editorSettingRow: some View {
        Button {
            showEditorPicker.toggle()
        } label: {
            HStack(spacing: 10) {
                Text("Editor")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                if let selected = editorManager.selectedEditor,
                   let icon = editorManager.icon(for: selected.bundleId) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 14, height: 14)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))

                    Text(selected.displayName)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                } else {
                    Text("Select...")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions
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

        VStack(spacing: 6) {
            if editors.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("No supported editors found")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.cardStroke, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                                .foregroundStyle(isSelected ? themeManager.brandColor : AppTheme.textPrimary)

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(themeManager.brandColor)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSelected ? themeManager.brandColor.opacity(0.08) : AppTheme.cardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(isSelected ? themeManager.brandColor.opacity(0.18) : AppTheme.cardStroke, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(6)
        .frame(width: 276)
        .background(AppTheme.background)
    }
}
