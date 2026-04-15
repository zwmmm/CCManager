import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var providerStore: ProviderStore
    @EnvironmentObject var themeManager: ThemeManager

    @State private var showingAddSheet = false
    @State private var showingSettings = false
    @State private var selectedProviderId: UUID?
    @State private var editingProvider: Provider?

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(
                selectedProviderId: $selectedProviderId,
                showingAddSheet: $showingAddSheet,
                showingSettings: $showingSettings,
                editingProvider: $editingProvider
            )
            .frame(width: 240)

            Divider()

            if let provider = providerStore.providers.first(where: { $0.id == selectedProviderId }) {
                ProviderDetailView(provider: provider, onEdit: { editingProvider = $0 })
                    .id(provider.id)
                    .transition(.opacity.animation(.easeOut(duration: 0.2)))
            } else {
                EmptyStateView()
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .accentColor(themeManager.brandColor)
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            showingSettings = true
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
    }
}

struct SidebarView: View {
    @EnvironmentObject var providerStore: ProviderStore
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedProviderId: UUID?
    @Binding var showingAddSheet: Bool
    let showingSettings: Binding<Bool>
    @Binding var editingProvider: Provider?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(providerStore.providers) { provider in
                        rowView(for: provider)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
            }

            // Footer with all buttons
            HStack(spacing: 12) {
                Spacer()

                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .frame(width: 24, height: 24)
                        .background(themeManager.brandColor)
                        .foregroundStyle(.black)
                        .clipShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    showingSettings.wrappedValue = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11, weight: .light))
                        .frame(width: 24, height: 24)
                        .background(themeManager.brandColor)
                        .foregroundStyle(.black)
                        .clipShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())

                Menu {
                    Button("Claude Code") {
                        openConfig(for: .claudeCode)
                    }
                    Button("Codex") {
                        openConfig(for: .codex)
                    }
                } label: {
                    Circle()
                        .fill(themeManager.brandColor)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.black)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
            // Create parent dir and touch the file if missing
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

        HStack(spacing: 10) {
            PixelAvatarView(name: provider.name, type: provider.type, size: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium, design: .monospaced))
                    .lineLimit(1)

                Text(provider.type.rawValue)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if provider.isActive {
                Text("ON")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(themeManager.brandColor)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(isSelected ? themeManager.brandColor.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                selectedProviderId = provider.id
            }
        }
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
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "server.rack")
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("No Provider Selected")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))

                Text("Select a provider or add a new one")
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ProviderDetailView: View {
    @EnvironmentObject var providerStore: ProviderStore
    @EnvironmentObject var themeManager: ThemeManager
    let provider: Provider
    let onEdit: (Provider) -> Void

    @State private var isAppearing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Card
                VStack(spacing: 14) {
                    PixelAvatarView(name: provider.name, type: provider.type, size: 64)

                    VStack(spacing: 6) {
                        Text(provider.name)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))

                        Text(provider.type.rawValue)
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundStyle(.secondary)

                        if let model = provider.model, !model.isEmpty {
                            Text(model)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(Capsule())
                        }
                    }

                    if provider.isActive {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("ACTIVE")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(themeManager.brandColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(themeManager.brandColor.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .scaleEffect(isAppearing ? 1 : 0.96)
                .opacity(isAppearing ? 1 : 0)

                // Config Section
                VStack(alignment: .leading, spacing: 0) {
                    VStack(spacing: 0) {
                        let labels = configLabels(for: provider.type)
                        configRow(labels.apiKey, maskAPIKey(provider.apiKey))
                        Divider()
                        configRow(labels.baseUrl, provider.baseUrl)
                        if let model = provider.model, !model.isEmpty {
                            Divider()
                            configRow(labels.model, model)
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .opacity(isAppearing ? 1 : 0)
                .offset(y: isAppearing ? 0 : 12)

                // Actions
                HStack(spacing: 12) {
                    Button {
                        onEdit(provider)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                    }
                    .buttonStyle(.bordered)

                    Button {
                        try? ConfigWriter.shared.writeProviderToConfig(provider)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            providerStore.setActiveProvider(provider)
                        }
                    } label: {
                        Label("Apply Config", systemImage: "arrow.up.doc")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeManager.brandColor)
                }
                .opacity(isAppearing ? 1 : 0)
                .offset(y: isAppearing ? 0 : 12)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
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
            return ConfigLabels(apiKey: "api_key", baseUrl: "base_url", model: "model")
        }
    }

    private func configRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
