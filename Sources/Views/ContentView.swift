import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var providerStore: ProviderStore
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var updateManager: UpdateManager

    @State private var showingAddSheet = false
    @State private var showingSettings = false
    @State private var selectedProviderId: UUID?
    @State private var editingProvider: Provider?
    @State private var showShortcutToast = false

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(
                selectedProviderId: $selectedProviderId,
                showingAddSheet: $showingAddSheet,
                showingSettings: $showingSettings,
                editingProvider: $editingProvider
            )
            .frame(width: 232)

            ZStack {
                AppTheme.background

                if let provider = providerStore.providers.first(where: { $0.id == selectedProviderId }) {
                    ProviderDetailView(provider: provider, onEdit: { editingProvider = $0 })
                        .id(provider.id)
                        .transition(.opacity.animation(.easeOut(duration: 0.2)))
                } else {
                    EmptyStateView()
                }
            }
        }
        .background(AppTheme.background)
        .fontDesign(.monospaced)
        .preferredColorScheme(themeManager.colorScheme)
        .accentColor(themeManager.brandColor)
        .onAppear {
            if selectedProviderId == nil, let first = providerStore.providers.first {
                selectedProviderId = first.id
            }
        }
        .onChange(of: providerStore.providers) { providers in
            if selectedProviderId == nil, let first = providers.first {
                selectedProviderId = first.id
            }
        }
        .onChange(of: updateManager.updateInstalled) { installed in
            if installed {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    updateManager.updateInstalled = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            showingSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .newProvider)) { _ in
            showingAddSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .editSelectedProvider)) { _ in
            editSelectedProvider()
        }
        .onReceive(NotificationCenter.default.publisher(for: .applySelectedProvider)) { _ in
            applySelectedProvider()
        }
        .sheet(isPresented: $showingAddSheet) {
            ProviderFormView(mode: .add) { provider in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    providerStore.addProvider(provider)
                    selectedProviderId = provider.id
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            ThemeSettingsView()
        }
        .sheet(item: $editingProvider) { provider in
            ProviderFormView(mode: .edit(provider)) { updatedProvider in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    providerStore.updateProvider(updatedProvider)
                }
            }
        }
        .toast(isPresented: $showShortcutToast, message: "Config Applied")
    }

    private func selectedProvider() -> Provider? {
        providerStore.providers.first { $0.id == selectedProviderId }
    }

    private func editSelectedProvider() {
        guard let provider = selectedProvider() else { return }
        editingProvider = provider
    }

    private func applySelectedProvider() {
        guard let provider = selectedProvider() else { return }
        try? ConfigWriter.shared.writeProviderToConfig(provider)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            providerStore.setActiveProvider(provider)
        }
        showShortcutToast = true
    }
}

struct SidebarView: View {
    @EnvironmentObject var providerStore: ProviderStore
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("providerGroupCollapsed_claudeCode") private var isClaudeCodeCollapsed: Bool = false
    @AppStorage("providerGroupCollapsed_codex") private var isCodexCollapsed: Bool = false

    private var groupingEnabled: Bool {
        themeManager.providerGroupingEnabled
    }

    @Binding var selectedProviderId: UUID?
    @Binding var showingAddSheet: Bool
    let showingSettings: Binding<Bool>
    @Binding var editingProvider: Provider?
    @State private var hoveredProviderId: UUID?
    @State private var draggingProviderId: UUID?
    @State private var draggingGroupType: ProviderType?
    @State private var reorderBaselineProviders: [Provider] = []

    private var claudeCodeProviders: [Provider] {
        providerStore.providers.filter { $0.type == .claudeCode }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var codexProviders: [Provider] {
        providerStore.providers
            .filter { $0.type == .codex || $0.type == .codexOAuth }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    @ViewBuilder
    private func flatContentView() -> some View {
        LazyVStack(spacing: 8) {
            ForEach(providerStore.providers) { provider in
                rowView(for: provider)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private func groupedContentView() -> some View {
        LazyVStack(spacing: 8) {
            CollapsibleGroup(
                isExpanded: $isClaudeCodeCollapsed,
                title: "Claude Code",
                count: claudeCodeProviders.count
            ) {
                VStack(spacing: 8) {
                    ForEach(claudeCodeProviders) { provider in
                        rowView(for: provider)
                    }
                }
            }

            CollapsibleGroup(
                isExpanded: $isCodexCollapsed,
                title: "Codex",
                count: codexProviders.count
            ) {
                VStack(spacing: 8) {
                    ForEach(codexProviders) { provider in
                        rowView(for: provider)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 14)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CC Manager")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Provider routing and API config")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            ScrollView {
                if groupingEnabled {
                    groupedContentView()
                } else {
                    flatContentView()
                }
            }

            VStack(spacing: 10) {
                Rectangle()
                    .fill(AppTheme.separator)
                    .frame(height: 1)

                HStack(spacing: 8) {
                    Spacer()

                    sidebarIconButton(systemName: "plus") {
                        showingAddSheet = true
                    }
                    .help("New Provider (⌘T)")

                    sidebarIconButton(systemName: "gearshape") {
                        showingSettings.wrappedValue = true
                    }
                    .help("Settings (⌘,)")

                    Menu {
                        Button("Claude Code") {
                            openConfig(for: .claudeCode)
                        }
                        Button("Codex") {
                            openConfig(for: .codex)
                        }
                    } label: {
                        sidebarToolbarIcon(systemName: "square.and.pencil")
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .help("Open config file")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        AppTheme.sidebar,
                        AppTheme.sidebar.opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AppTheme.separator, AppTheme.separator.opacity(0.32)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1)
        }
    }

    private enum ConfigTarget {
        case claudeCode
        case codex
    }

    private func openConfig(for target: ConfigTarget) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let url: URL
        switch target {
        case .claudeCode:
            url = home.appendingPathComponent(".claude/settings.json")
        case .codex:
            url = home.appendingPathComponent(".codex/config.toml")
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            let parent = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: url.path, contents: nil)
            return
        }

        if let editor = EditorManager.shared.selectedEditor {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = ["-a", editor.cliCommand, url.path]
            try? task.run()
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    @ViewBuilder
    private func rowView(for provider: Provider) -> some View {
        let isSelected = selectedProviderId == provider.id
        let isHovered = hoveredProviderId == provider.id
        let isDragging = draggingProviderId == provider.id
        let reorderGroupType = groupingEnabled ? provider.reorderGroupType : nil

        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isSelected ? themeManager.brandColor.opacity(0.14) : AppTheme.subtleFill)
                    .frame(width: 34, height: 34)
                CachedPixelAvatarView(name: provider.name, type: provider.type, size: 24)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(provider.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Text(provider.type.rawValue)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if provider.isActive {
                ProviderActiveIndicator(accent: themeManager.brandColor)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isSelected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        themeManager.brandColor.opacity(0.22),
                                        AppTheme.surfaceElevated.opacity(0.86)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(isHovered ? AppTheme.hoverFill : AppTheme.cardFill)
                    )

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? themeManager.brandColor.opacity(0.38) : AppTheme.cardStroke.opacity(isHovered ? 0.95 : 0.52),
                        lineWidth: 1
                    )
            }
        )
        .shadow(
            color: isDragging ? Color.clear : (isSelected ? themeManager.brandColor.opacity(0.16) : (isHovered ? AppTheme.shadow : Color.clear)),
            radius: isDragging ? 0 : (isSelected ? 14 : (isHovered ? 8 : 0)),
            x: 0,
            y: isDragging ? 0 : (isSelected ? 6 : 4)
        )
        .opacity(isDragging ? 0 : 1)
        .contentShape(Rectangle())
        .offset(y: isHovered && !isSelected && draggingProviderId == nil ? -1 : 0)
        .animation(.easeOut(duration: 0.16), value: isHovered)
        .onHover { hovering in
            hoveredProviderId = hovering ? provider.id : nil
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                selectedProviderId = provider.id
            }
        }
        .onDrag {
            draggingProviderId = provider.id
            draggingGroupType = reorderGroupType
            reorderBaselineProviders = providerStore.providers
            return NSItemProvider(object: provider.id.uuidString as NSString)
        } preview: {
            providerDragPreview(for: provider)
        }
        .onDrop(
            of: [UTType.text],
            delegate: ProviderReorderDropDelegate(
                targetProvider: provider,
                providerStore: providerStore,
                draggedProviderId: $draggingProviderId,
                draggedGroupType: $draggingGroupType,
                reorderBaselineProviders: $reorderBaselineProviders,
                targetGroupType: reorderGroupType
            )
        )
        .contextMenu {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    providerStore.setActiveProvider(provider)
                }
            } label: {
                Label("Set Active", systemImage: "checkmark.circle")
            }
            .disabled(provider.isActive)

            Button {
                editingProvider = provider
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    providerStore.deleteProvider(provider)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func providerDragPreview(for provider: Provider) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(AppTheme.subtleFill)
                    .frame(width: 34, height: 34)
                CachedPixelAvatarView(name: provider.name, type: provider.type, size: 24)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(provider.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Text(provider.type.rawValue)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if provider.isActive {
                ProviderActiveIndicator(accent: themeManager.brandColor)
            }
        }
        .frame(width: 208, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.surfaceElevated.opacity(0.96))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(themeManager.brandColor.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: AppTheme.shadow.opacity(0.8), radius: 18, x: 0, y: 10)
    }

    @ViewBuilder
    private func sidebarIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            sidebarToolbarIcon(systemName: systemName)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private func sidebarToolbarIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(AppTheme.textSecondary)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(AppTheme.cardFill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(AppTheme.cardStroke, lineWidth: 1)
            }
            .shadow(color: AppTheme.shadow, radius: 6, x: 0, y: 4)
    }
}

private struct ProviderReorderDropDelegate: DropDelegate {
    let targetProvider: Provider
    let providerStore: ProviderStore
    @Binding var draggedProviderId: UUID?
    @Binding var draggedGroupType: ProviderType?
    @Binding var reorderBaselineProviders: [Provider]
    let targetGroupType: ProviderType?

    func dropEntered(info: DropInfo) {
        guard
            let draggedProviderId,
            draggedProviderId != targetProvider.id,
            draggedGroupType == targetGroupType
        else { return }

        withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.9, blendDuration: 0.08)) {
            providerStore.previewMoveProvider(
                moving: draggedProviderId,
                to: targetProvider.id,
                inGroup: targetGroupType
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        let baselineProviders = reorderBaselineProviders
        draggedProviderId = nil
        draggedGroupType = nil
        reorderBaselineProviders = []

        providerStore.persistProviderSortOrderChanges(from: baselineProviders)
        return true
    }
}

private extension Provider {
    var reorderGroupType: ProviderType {
        switch type {
        case .claudeCode:
            return .claudeCode
        case .codex, .codexOAuth:
            return .codex
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.cardFill, AppTheme.subtleFill],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)

                    Image(systemName: "server.rack")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                VStack(spacing: 8) {
                    Text("No Provider Selected")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Choose a provider from the sidebar or create a new configuration to get started.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 340)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct ProviderDetailView: View {
    @EnvironmentObject var providerStore: ProviderStore
    @EnvironmentObject var themeManager: ThemeManager
    let provider: Provider
    let onEdit: (Provider) -> Void

    @State private var isAppearing = false
    @State private var showSuccessToast = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.subtleFill)
                            .frame(width: 68, height: 68)
                            .overlay {
                                Circle()
                                    .stroke(AppTheme.cardStroke, lineWidth: 1)
                            }

                        CachedPixelAvatarView(name: provider.name, type: provider.type, size: 48)
                    }
                    .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)

                    VStack(spacing: 4) {
                        Text(provider.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)

                        Text(provider.type.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)

                        if let model = provider.model, !model.isEmpty {
                            Text(model)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .multilineTextAlignment(.center)

                    if provider.isActive {
                        ProviderActiveBadge(accent: themeManager.brandColor, compact: true)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .scaleEffect(isAppearing ? 1 : 0.985)
                .opacity(isAppearing ? 1 : 0)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("CONFIGURATION")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .kerning(0.8)
                            .foregroundStyle(AppTheme.textTertiary)
                        Spacer()
                    }

                    VStack(spacing: 0) {
                        let labels = configLabels(for: provider.type)
                        if provider.type == .codexOAuth {
                            ConfigRowView(label: "ACCOUNT", value: provider.oauthDisplayName?.isEmpty == false ? provider.oauthDisplayName! : "ChatGPT Account")
                            premiumDivider()
                        } else {
                            ConfigRowView(label: labels.apiKey, value: maskAPIKey(provider.apiKey ?? ""))
                            premiumDivider()
                        }

                        if provider.type != .codexOAuth {
                            ConfigRowView(label: labels.baseUrl, value: provider.baseUrl)
                        }

                        if let model = provider.model, !model.isEmpty {
                            premiumDivider()
                            ConfigRowView(label: labels.model, value: model)
                        }

                        if provider.type == .claudeCode {
                            if let thinkingModel = provider.thinkingModel, !thinkingModel.isEmpty {
                                premiumDivider()
                                ConfigRowView(label: "ANTHROPIC_SMALL_FAST_MODEL", value: thinkingModel)
                            }
                            if let haikuModel = provider.haikuModel, !haikuModel.isEmpty {
                                premiumDivider()
                                ConfigRowView(label: "ANTHROPIC_DEFAULT_HAIKU_MODEL", value: haikuModel)
                            }
                            if let sonnetModel = provider.sonnetModel, !sonnetModel.isEmpty {
                                premiumDivider()
                                ConfigRowView(label: "ANTHROPIC_DEFAULT_SONNET_MODEL", value: sonnetModel)
                            }
                            if let opusModel = provider.opusModel, !opusModel.isEmpty {
                                premiumDivider()
                                ConfigRowView(label: "ANTHROPIC_DEFAULT_OPUS_MODEL", value: opusModel)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppTheme.cardFill,
                                        AppTheme.surfaceElevated.opacity(0.72)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppTheme.cardStroke, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 12)
                }
                .opacity(isAppearing ? 1 : 0)
                .offset(y: isAppearing ? 0 : 12)

                HStack(spacing: 12) {
                    Button {
                        onEdit(provider)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(minWidth: 102)
                    }
                    .buttonStyle(SecondaryDashboardButtonStyle())

                    Button {
                        try? ConfigWriter.shared.writeProviderToConfig(provider)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            providerStore.setActiveProvider(provider)
                        }
                        showSuccessToast = true
                    } label: {
                        Label("Apply Config", systemImage: "arrow.up.doc")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(minWidth: 152)
                    }
                    .buttonStyle(PrimaryDashboardButtonStyle(accent: themeManager.brandColor))
                }
                .opacity(isAppearing ? 1 : 0)
                .offset(y: isAppearing ? 0 : 12)
                .padding(.bottom, 14)
            }
            .padding(.horizontal, 28)
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.surface.opacity(0.28),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .toast(isPresented: $showSuccessToast, message: "Config Applied")
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.05)) {
                isAppearing = true
            }
        }
    }

    private struct ConfigLabels {
        let apiKey: String
        let baseUrl: String
        let model: String
    }

    private func configLabels(for type: ProviderType) -> ConfigLabels {
        switch type {
        case .claudeCode:
            return ConfigLabels(apiKey: "ANTHROPIC_AUTH_TOKEN", baseUrl: "ANTHROPIC_BASE_URL", model: "ANTHROPIC_MODEL")
        case .codex:
            return ConfigLabels(apiKey: "api_key", baseUrl: "base_url", model: "MODEL")
        case .codexOAuth:
            return ConfigLabels(apiKey: "oauth_access_token", baseUrl: "base_url", model: "MODEL")
        }
    }

    @ViewBuilder
    private func premiumDivider() -> some View {
        Rectangle()
            .fill(AppTheme.separator)
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    private func maskAPIKey(_ key: String) -> String {
        if key.count <= 8 {
            return String(repeating: "*", count: key.count)
        }
        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(4))
        return "\(prefix)****\(suffix)"
    }
}

private struct ProviderActiveBadge: View {
    let accent: Color
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 5 : 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: compact ? 9.5 : 11, weight: .semibold))

            Text("ACTIVE")
                .font(.system(size: compact ? 9.5 : 11, weight: .bold, design: .monospaced))
                .kerning(compact ? 0.4 : 0.7)
        }
        .foregroundStyle(accent)
        .padding(.horizontal, compact ? 7 : 12)
        .padding(.vertical, compact ? 3.5 : 7)
        .background(
            Capsule()
                .fill(accent.opacity(compact ? 0.1 : 0.12))
        )
        .overlay {
            Capsule()
                .stroke(accent.opacity(compact ? 0.18 : 0.28), lineWidth: 1)
        }
        .shadow(color: accent.opacity(compact ? 0.1 : 0.14), radius: compact ? 8 : 12, x: 0, y: compact ? 4 : 6)
    }
}

private struct ProviderActiveIndicator: View {
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.12))
                .frame(width: 20, height: 20)

            Circle()
                .stroke(accent.opacity(0.22), lineWidth: 1)
                .frame(width: 20, height: 20)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(accent)
        }
        .shadow(color: accent.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

private struct ConfigRowView: View {
    let label: String
    let value: String

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(label)
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .kerning(0.5)
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: 176, alignment: .leading)

            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 22, height: 22)
                    .background(AppTheme.subtleFill)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)
            .animation(.easeOut(duration: 0.18), value: isHovering)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(isHovering ? AppTheme.hoverFill.opacity(0.55) : Color.clear)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct PrimaryDashboardButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(configuration.isPressed ? 0.86 : 0.98),
                                accent.opacity(configuration.isPressed ? 0.72 : 0.82)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: accent.opacity(configuration.isPressed ? 0.12 : 0.25), radius: 14, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct SecondaryDashboardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(configuration.isPressed ? AppTheme.hoverFill : AppTheme.cardFill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(AppTheme.cardStroke, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
