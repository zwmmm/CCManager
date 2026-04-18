import AppKit
import SwiftUI

// MARK: - DiceBear Avatar Cache

final class DiceBearAvatarCache {
    static let shared = DiceBearAvatarCache()

    private let cache = NSCache<NSString, NSImage>()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: config)
        cache.countLimit = 100
    }

    func avatar(for name: String, type: ProviderType, size: CGFloat) async -> NSImage {
        let key = "\(name)-\(type.rawValue)-\(Int(size))" as NSString

        if let cached = cache.object(forKey: key) {
            return cached
        }

        // DiceBear: Claude Code → adventurer, Codex → open-peeps
        let style = type == .codex ? "open-peeps" : "adventurer"
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.dicebear.com"
        components.path = "/7.x/\(style)/svg"
        components.queryItems = [URLQueryItem(name: "seed", value: name)]

        guard let url = components.url else {
            return fallbackImage(size: size)
        }

        do {
            let (data, _) = try await session.data(from: url)
            if let nsImage = NSImage(data: data) {
                // Render to exact size
                let sizedImage = resize(nsImage, to: size)
                cache.setObject(sizedImage, forKey: key)
                return sizedImage
            }
        } catch {
            // Fall through to fallback
        }

        return fallbackImage(size: size)
    }

    private func resize(_ image: NSImage, to size: CGFloat) -> NSImage {
        let newImage = NSImage(size: NSSize(width: size, height: size))
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(x: 0, y: 0, width: size, height: size),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        newImage.unlockFocus()
        return newImage
    }

    private func fallbackImage(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        NSColor.gray.setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill()
        image.unlockFocus()
        return image
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}

// MARK: - Cached DiceBear Avatar View

struct CachedPixelAvatarView: View {
    let name: String
    let type: ProviderType
    let size: CGFloat

    @State private var renderedImage: NSImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let image = renderedImage {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: size, height: size)
                    .scaleEffect(x: type == .claudeCode ? -1 : 1, y: 1) // Claude Code 朝左需翻转，其他朝右
            } else {
                Color.gray.opacity(0.3)
                    .frame(width: size, height: size)
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.5)
                        }
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: size * 0.15))
        .task {
            await loadAvatar()
        }
    }

    private func loadAvatar() async {
        isLoading = true
        defer { isLoading = false }
        renderedImage = await DiceBearAvatarCache.shared.avatar(
            for: name,
            type: type,
            size: size
        )
    }
}
