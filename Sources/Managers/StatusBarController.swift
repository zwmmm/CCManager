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
            contentRect: NSRect(x: 0, y: 0, width: 316, height: 430),
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
        isOpaque = false
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
        hostingView.frame = NSRect(x: 0, y: 0, width: 316, height: 430)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        contentView = hostingView
    }

    func positionNear(buttonFrame: NSRect?) {
        guard let buttonFrame = buttonFrame else { return }

        let panelWidth: CGFloat = 316
        let panelHeight: CGFloat = 430
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
            headerView

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if !claudeProviders.isEmpty {
                        statusMenuSection(title: "Claude Code", count: claudeProviders.count) {
                            ForEach(claudeProviders) { provider in
                                providerRow(provider)
                            }
                        }
                    }

                    if !codexProviders.isEmpty {
                        statusMenuSection(title: "Codex", count: codexProviders.count) {
                            ForEach(codexProviders) { provider in
                                providerRow(provider)
                            }
                        }
                    }

                    if providerStore.providers.isEmpty {
                        emptyStateView
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }

            footerView
        }
        .frame(width: 316, height: 430)
        .background(AppTheme.background)
        .fontDesign(.monospaced)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CC Manager")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Provider routing")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Button {
                onOpenMainWindow()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.cardFill)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 15)
        .padding(.bottom, 12)
    }

    private var footerView: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppTheme.separator)
                .frame(height: 1)

            HStack(spacing: 10) {
                Button {
                    onQuit()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "power")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Quit")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppTheme.cardFill)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer()

                Menu {
                    Button("Claude Code") {
                        openConfig(for: .claudeCode)
                    }
                    Button("Codex") {
                        openConfig(for: .codex)
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Config")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(.white.opacity(0.94))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(
                        LinearGradient(
                            colors: [
                                themeManager.brandColor.opacity(0.86),
                                themeManager.brandColor.opacity(0.66)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .shadow(color: themeManager.brandColor.opacity(0.18), radius: 10, x: 0, y: 6)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.surface.opacity(0.38))
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.subtleFill)
                    .frame(width: 64, height: 64)

                Image(systemName: "server.rack")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            VStack(spacing: 5) {
                Text("No Providers")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Open the app to add your first config.")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Button {
                onOpenMainWindow()
            } label: {
                Text("Add Provider")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.plain)
            .background(themeManager.brandColor.opacity(0.14))
            .foregroundStyle(AppTheme.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private func statusMenuSection<Content: View>(
        title: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .kerning(0.7)
                    .foregroundStyle(AppTheme.textTertiary)

                Text("\(count)")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(AppTheme.cardFill)
                    .clipShape(Capsule())

                Spacer()
            }
            .padding(.horizontal, 2)

            VStack(spacing: 4) {
                content()
            }
        }
    }

    @ViewBuilder
    private func providerRow(_ provider: Provider) -> some View {
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

    private var claudeProviders: [Provider] {
        providerStore.providers.filter { $0.type == .claudeCode }
    }

    private var codexProviders: [Provider] {
        providerStore.providers.filter { $0.type == .codex || $0.type == .codexOAuth }
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
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isActive ? themeManager.brandColor.opacity(0.14) : AppTheme.subtleFill)
                    .frame(width: 36, height: 36)

                CachedPixelAvatarView(
                    name: provider.name,
                    type: provider.type,
                    size: 26
                )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(provider.name)
                    .font(.system(size: 12.5, weight: isActive ? .semibold : .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                if let model = provider.model, !model.isEmpty {
                    Text(model)
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                } else {
                    Text(provider.type.rawValue)
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if isActive {
                ZStack {
                    Circle()
                        .fill(themeManager.brandColor.opacity(0.13))
                        .frame(width: 22, height: 22)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(themeManager.brandColor)
                }
                    .scaleEffect(isPressed ? 1.08 : 1.0)
                    .animation(.easeOut(duration: 0.12), value: isPressed)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isActive
                        ? themeManager.brandColor.opacity(0.12)
                        : (isHovered ? AppTheme.hoverFill : Color.clear)
                )
        )
        .shadow(color: isActive ? themeManager.brandColor.opacity(0.05) : .clear, radius: 8, x: 0, y: 4)
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.975 : 1.0)
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
