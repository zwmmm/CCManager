import AppKit
import SwiftUI
import Sparkle
import Down

/// 从 Bundle 获取应用图标
private var appIconImage: NSImage? {
    NSApplication.shared.applicationIconImage
}

/// 自定义更新弹窗，支持 Markdown 格式的更新内容展示
final class UpdateWindowController: NSWindowController {
    private let appcastItem: SUAppcastItem
    private let onInstall: () -> Void
    private let onSkip: () -> Void
    private let onDismiss: () -> Void

    init(appcastItem: SUAppcastItem, onInstall: @escaping () -> Void, onSkip: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.appcastItem = appcastItem
        self.onInstall = onInstall
        self.onSkip = onSkip
        self.onDismiss = onDismiss

        let contentView = UpdateContentView(
            appcastItem: appcastItem,
            onInstall: onInstall,
            onSkip: onSkip,
            onDismiss: onDismiss
        )
        .environmentObject(ThemeManager.shared)

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
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// 用 NSTextView 显示 Down 解析的 Markdown
struct MarkdownTextView: NSViewRepresentable {
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
        textView.isRichText = false
        textView.usesFontPanel = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.autoresizingMask = [.width]

        updateTextView(textView)

        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            updateTextView(textView)
        }
    }

    private func updateTextView(_ textView: NSTextView) {
        let down = Down(markdownString: markdown)
        if let nsAttr = try? down.toAttributedString() {
            // 创建一个可变的副本
            let mutableAttr = NSMutableAttributedString(attributedString: nsAttr)
            let fullRange = NSRange(location: 0, length: mutableAttr.length)

            // 遍历所有属性，应用自定义颜色
            mutableAttr.enumerateAttributes(in: fullRange) { attrs, range, _ in
                // 检查是否是标题（通过检查字体 weight 或 size）
                if let font = attrs[.font] as? NSFont {
                    let isBold = font.fontDescriptor.symbolicTraits.contains(.bold)
                    if isBold && font.pointSize > monoFont.pointSize {
                        // 标题使用 heading 颜色
                        mutableAttr.addAttribute(.foregroundColor, value: headingColor, range: range)
                    } else {
                        // 其他内容使用 text 颜色
                        mutableAttr.addAttribute(.foregroundColor, value: textColor, range: range)
                    }
                    // 统一字体为 monospaced
                    let newFont = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: font.pointSize > 14 ? .bold : .regular)
                    mutableAttr.addAttribute(.font, value: newFont, range: range)
                } else {
                    mutableAttr.addAttribute(.font, value: monoFont, range: range)
                    mutableAttr.addAttribute(.foregroundColor, value: textColor, range: range)
                }
            }

            // 移除列表前缀符号（Down 渲染的 • 等标记）
            let bulletPattern = "^\\s*[•·▪▪]\\s*"
            if let regex = try? NSRegularExpression(pattern: bulletPattern, options: .anchorsMatchLines) {
                let plainText = mutableAttr.mutableString
                regex.replaceMatches(in: plainText, options: [], range: fullRange, withTemplate: "")
            }

            textView.textStorage?.setAttributedString(mutableAttr)
        } else {
            textView.string = markdown
        }
    }
}

/// 更新内容视图
struct UpdateContentView: View {
    let appcastItem: SUAppcastItem
    let onInstall: () -> Void
    let onSkip: () -> Void
    let onDismiss: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    private var monoFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
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

                    Text("Version \(appcastItem.displayVersionString)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            // Release Notes
            if let releaseNotes = appcastItem.itemDescription, !releaseNotes.isEmpty {
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

            // Actions
            HStack(spacing: 12) {
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
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 420)
        .background(Color(nsColor: .windowBackgroundColor))
        .environmentObject(ThemeManager.shared)
    }
}