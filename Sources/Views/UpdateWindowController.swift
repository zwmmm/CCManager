import AppKit
import Down
import SwiftUI

private var appIconImage: NSImage? {
    NSApplication.shared.applicationIconImage
}

final class UpdateWindowController: NSWindowController, NSWindowDelegate {
    private let onInstall: () -> Void
    private let onSkip: () -> Void
    private var didChooseAction = false

    init(updateItem: UpdateFeedItem, onInstall: @escaping () -> Void, onSkip: @escaping () -> Void) {
        self.onInstall = onInstall
        self.onSkip = onSkip

        let contentView = UpdateContentView(
            updateItem: updateItem,
            onInstall: onInstall,
            onSkip: onSkip
        )
        .environmentObject(ThemeManager.shared)
        .environmentObject(UpdateManager.shared)

        let hostingView = NSHostingView(rootView: contentView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.title = "Update Available"
        window.appearance = NSApp.appearance
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeAfterAction() {
        didChooseAction = true
        close()
    }

    func windowWillClose(_ notification: Notification) {
        if !didChooseAction {
            didChooseAction = true
            onSkip()
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        didChooseAction || !(UpdateManager.shared.isInstallingUpdate)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct MarkdownTextView: NSViewRepresentable {
    let markdown: String
    let textColor: NSColor
    let headingColor: NSColor
    let monoFont: NSFont

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = true
        textView.usesFontPanel = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        scrollView.documentView = textView
        updateTextView(textView)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            updateTextView(textView)
        }
    }

    private func updateTextView(_ textView: NSTextView) {
        let down = Down(markdownString: markdown)

        guard let attributedString = try? down.toAttributedString() else {
            textView.string = markdown
            textView.font = monoFont
            textView.textColor = textColor
            return
        }

        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutableString.length)

        mutableString.enumerateAttributes(in: fullRange) { attributes, range, _ in
            let existingFont = attributes[.font] as? NSFont ?? monoFont
            let isHeading = existingFont.pointSize > monoFont.pointSize || existingFont.fontDescriptor.symbolicTraits.contains(.bold)
            let font = NSFont.monospacedSystemFont(
                ofSize: isHeading ? max(existingFont.pointSize, 13) : monoFont.pointSize,
                weight: isHeading ? .semibold : .regular
            )

            mutableString.addAttribute(.font, value: font, range: range)
            mutableString.addAttribute(.foregroundColor, value: isHeading ? headingColor : textColor, range: range)
        }

        // Remove list item prefixes (e.g., "1.", "2.", "•", "-")
        if let plainText = mutableString.mutableString as NSMutableString? {
            let patterns = [
                "^\\s*\\d+\\.\\s*",  // numbered list: "1.", "2."
                "^\\s*[•·▪▫]\\s*",   // bullet list: "•", "·"
            ]
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) {
                    regex.replaceMatches(in: plainText, options: [], range: fullRange, withTemplate: "")
                }
            }
        }

        textView.textStorage?.setAttributedString(mutableString)
    }
}

private struct UpdateContentView: View {
    let updateItem: UpdateFeedItem
    let onInstall: () -> Void
    let onSkip: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var updateManager: UpdateManager

    private var monoFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    }

    private var isInstalling: Bool {
        updateManager.isInstallingUpdate
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let iconImage = appIconImage {
                    Image(nsImage: iconImage)
                        .resizable()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(themeManager.brandColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("CCManager")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)

                    Text("Version \(updateItem.shortVersion)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            if let releaseNotes = updateItem.releaseNotes, !releaseNotes.isEmpty {
                MarkdownTextView(
                    markdown: releaseNotes,
                    textColor: .labelColor,
                    headingColor: .labelColor,
                    monoFont: monoFont
                )
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            } else {
                Text("No release notes available.")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }

            Divider()

            HStack(spacing: 12) {
                if isInstalling {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)

                        Text(updateManager.updateStatus)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 32)
                } else {
                    Button {
                        onSkip()
                    } label: {
                        Text("Skip This Version")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        onInstall()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 12, weight: .medium))
                            Text("Install Update")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(themeManager.brandColor)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                if isInstalling {
                    Spacer()

                    Text("Please wait")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 420)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
