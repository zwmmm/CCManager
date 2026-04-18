import AppKit
import SwiftUI

final class StatusBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private var panel: StatusMenuPanel?
    private var isPanelVisible = false

    init() {
        setupStatusItem()
        setupPanel()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            if let image = NSImage(contentsOfFile: Bundle.main.path(forResource: "MingcuteClaudeFill", ofType: "png") ?? "") {
                let targetSize = NSSize(width: 18, height: 18)
                let resized = NSImage(size: targetSize)
                resized.lockFocus()
                image.draw(in: NSRect(origin: .zero, size: targetSize),
                          from: NSRect(origin: .zero, size: image.size),
                          operation: .copy,
                          fraction: 1.0)
                resized.unlockFocus()
                resized.isTemplate = true
                button.image = resized
            } else {
                button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "CC Manager")
            }
            button.action = #selector(handleStatusBarClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
    }

    @objc private func handleStatusBarClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right click: toggle panel
            if isPanelVisible {
                hidePanel()
            } else {
                showPanel()
            }
        } else {
            // Left click: show main window
            hidePanel()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .restoreMainWindow, object: nil)
            }
        }
    }

    private func setupPanel() {
        panel = StatusMenuPanel(
            onSelectProvider: { provider in
                try? ConfigWriter.shared.writeProviderToConfig(provider)
                ProviderStore.shared.setActiveProvider(provider)
            },
            onOpenMainWindow: { [weak self] in
                self?.hidePanel()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(name: .restoreMainWindow, object: nil)
                }
            },
            onQuit: {
                NSApp.stopModal()
                for window in NSApp.windows {
                    window.close()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    exit(0)
                }
            },
            onPanelHidden: { [weak self] in
                self?.isPanelVisible = false
            }
        )
    }

    @objc private func togglePanel() {
        if isPanelVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let button = statusItem?.button, let panel = panel else { return }

        let buttonFrame = button.window?.convertToScreen(button.bounds)
        panel.positionNear(buttonFrame: buttonFrame)
        panel.makeKeyAndOrderFront(nil)
        isPanelVisible = true
    }

    private func hidePanel() {
        panel?.orderOut(nil)
        isPanelVisible = false
    }
}

// MARK: - Custom Panel

final class StatusMenuPanel: NSPanel {
    private let onSelectProvider: (Provider) -> Void
    private let onOpenMainWindow: () -> Void
    private let onQuit: () -> Void
    private let onPanelHidden: () -> Void

    init(
        onSelectProvider: @escaping (Provider) -> Void,
        onOpenMainWindow: @escaping () -> Void,
        onQuit: @escaping () -> Void,
        onPanelHidden: @escaping () -> Void
    ) {
        self.onSelectProvider = onSelectProvider
        self.onOpenMainWindow = onOpenMainWindow
        self.onQuit = onQuit
        self.onPanelHidden = onPanelHidden

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        setupPanel()
    }

    private func setupPanel() {
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        acceptsMouseMovedEvents = true
        hasShadow = true
        backgroundColor = .clear

        let menuView = StatusBarMenuView(
            onSelectProvider: onSelectProvider,
            onOpenMainWindow: onOpenMainWindow,
            onQuit: onQuit
        )
        .environmentObject(ProviderStore.shared)
        .environmentObject(ThemeManager.shared)
        .environmentObject(EditorManager.shared)

        let hostingView = NSHostingView(rootView: menuView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 280, height: 400)

        contentView = hostingView
    }

    func positionNear(buttonFrame: NSRect?) {
        guard let buttonFrame = buttonFrame else { return }

        let panelWidth: CGFloat = 280
        let panelHeight: CGFloat = 400
        let margin: CGFloat = 8

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

        var x = buttonFrame.origin.x + buttonFrame.width / 2 - panelWidth / 2
        var y = buttonFrame.origin.y - panelHeight - margin

        // 确保不超出屏幕边界
        x = max(screenFrame.origin.x + margin, min(x, screenFrame.origin.x + screenFrame.width - panelWidth - margin))
        y = max(screenFrame.origin.y + margin, y)

        setFrameOrigin(NSPoint(x: x, y: y))
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // 点击外部关闭
    override func resignKey() {
        super.resignKey()
        orderOut(nil)
        onPanelHidden()
    }
}

// MARK: - SwiftUI Menu View

struct StatusBarMenuView: View {
    @EnvironmentObject var providerStore: ProviderStore
    @EnvironmentObject var themeManager: ThemeManager

    let onSelectProvider: (Provider) -> Void
    let onOpenMainWindow: () -> Void
    let onQuit: () -> Void

    @State private var pressedProviderId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("CC Manager")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    onOpenMainWindow()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(themeManager.brandColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Provider List
            ScrollView {
                VStack(spacing: 0) {
                    // Claude Code Section
                    if !claudeProviders.isEmpty {
                        SectionHeader(title: "Claude Code")
                        ForEach(claudeProviders) { provider in
                            ProviderMenuRowView(
                                provider: provider,
                                isActive: provider.isActive,
                                isPressed: pressedProviderId == provider.id,
                                onTap: {
                                    withAnimation(.easeOut(duration: 0.12)) {
                                        pressedProviderId = provider.id
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                        pressedProviderId = nil
                                        onSelectProvider(provider)
                                    }
                                }
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }

                    // Codex Section
                    if !codexProviders.isEmpty {
                        SectionHeader(title: "Codex")
                        ForEach(codexProviders) { provider in
                            ProviderMenuRowView(
                                provider: provider,
                                isActive: provider.isActive,
                                isPressed: pressedProviderId == provider.id,
                                onTap: {
                                    withAnimation(.easeOut(duration: 0.12)) {
                                        pressedProviderId = provider.id
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                        pressedProviderId = nil
                                        onSelectProvider(provider)
                                    }
                                }
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }

                    // Empty State
                    if providerStore.providers.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "server.rack")
                                .font(.system(size: 32, weight: .light))
                                .foregroundStyle(.secondary)

                            Text("No Providers")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)

                            Button {
                                onOpenMainWindow()
                            } label: {
                                Text("Add Provider")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(themeManager.brandColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding(.vertical, 8)
            }

            Divider()

            // Footer
            HStack {
                Button {
                    onQuit()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "power")
                            .font(.system(size: 11))
                        Text("Quit")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Menu {
                    Button("Claude Code") {
                        openConfig(for: .claudeCode)
                    }
                    Button("Codex") {
                        openConfig(for: .codex)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 10, weight: .medium))
                        Text("Config")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(themeManager.brandColor)
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 280, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }

    private var claudeProviders: [Provider] {
        providerStore.providers.filter { $0.type == .claudeCode }
    }

    private var codexProviders: [Provider] {
        providerStore.providers.filter { $0.type == .codex }
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
}

// MARK: - Provider Row

struct ProviderMenuRowView: View {
    let provider: Provider
    let isActive: Bool
    let isPressed: Bool
    let onTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            CachedPixelAvatarView(
                name: provider.name,
                type: provider.type,
                size: 28
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let model = provider.model, !model.isEmpty {
                    Text(model)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isActive {
                Circle()
                    .fill(themeManager.brandColor)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isPressed ? 1.5 : 1.0)
                    .animation(.easeOut(duration: 0.12), value: isPressed)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isActive ? themeManager.brandColor.opacity(0.1) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.97 : (isHovered ? 1.01 : 1.0))
        .animation(.easeOut(duration: 0.12), value: isPressed)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Section Header (no icon)

struct SectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}