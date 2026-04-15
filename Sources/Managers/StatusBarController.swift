import AppKit
import SwiftUI

final class StatusBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var clickMonitor: Any?

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
            button.action = #selector(togglePanel)
            button.target = self
        }
    }

    private func setupPanel() {
        let contentView = StatusBarMenuView(
            onSelectProvider: { provider in
                try? ConfigWriter.shared.writeProviderToConfig(provider)
                ProviderStore.shared.setActiveProvider(provider)
            },
            onOpenMainWindow: { [weak self] in
                self?.closePanel()
                self?.openMainWindow()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        .environmentObject(ProviderStore.shared)
        .environmentObject(ThemeManager.shared)

        let hostingView = NSHostingView(rootView: contentView)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.contentView = hostingView
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        self.panel = panel
    }

    @objc private func togglePanel() {
        if let panel = panel, panel.isVisible {
            closePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let panel = panel, let button = statusItem?.button else { return }

        let buttonFrame = button.window?.convertToScreen(button.frame) ?? .zero
        let panelSize = panel.frame.size

        let xPos = buttonFrame.midX - (panelSize.width / 2)
        let yPos = buttonFrame.minY - panelSize.height - 2

        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let clampedX = max(screenFrame.minX, min(xPos, screenFrame.maxX - panelSize.width))

        panel.setFrameOrigin(NSPoint(x: clampedX, y: yPos))
        panel.makeKeyAndOrderFront(nil)

        if let existing = clickMonitor {
            NSEvent.removeMonitor(existing)
        }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let panel = self?.panel, panel.isVisible else { return }
            let location = event.locationInWindow
            let panelFrame = panel.frame
            if !panelFrame.contains(location) {
                self?.closePanel()
            }
        }
    }

    private func closePanel() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        panel?.orderOut(nil)
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.mainWindow {
            window.makeKeyAndOrderFront(nil)
        }
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
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Provider List
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(width: 280, height: 0)

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
            .frame(maxHeight: 280)

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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }

    private var claudeProviders: [Provider] {
        providerStore.providers.filter { $0.type == .claudeCode }
    }

    private var codexProviders: [Provider] {
        providerStore.providers.filter { $0.type == .codex }
    }
}

// MARK: - Provider Row

struct ProviderMenuRowView: View {
    let provider: Provider
    let isActive: Bool
    let isPressed: Bool
    let onTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            CachedPixelAvatarView(
                name: provider.name,
                type: provider.type,
                size: 24
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
        .background(isActive ? themeManager.brandColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isPressed)
        .onTapGesture {
            onTap()
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
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}
