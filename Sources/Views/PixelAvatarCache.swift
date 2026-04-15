import AppKit
import SwiftUI

// MARK: - Pixel Avatar Cache

final class PixelAvatarCache {
    static let shared = PixelAvatarCache()

    private var cache: [String: NSImage] = [:]
    private let queue = DispatchQueue(label: "com.ccmanager.avatarCache", attributes: .concurrent)

    private init() {}

    func avatar(for name: String, type: ProviderType, size: CGFloat) -> NSImage {
        let key = "\(name)-\(type.rawValue)-\(Int(size))"

        return queue.sync {
            if let cached = cache[key], cached.isValid {
                return cached
            }

            let image = renderAvatar(name: name, type: type, size: size)
            cache[key] = image
            return image
        }
    }

    private func renderAvatar(name: String, type: ProviderType, size: CGFloat) -> NSImage {
        let view = PixelAvatarView(name: name, type: type, size: size)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: size, height: size)
        hostingView.layoutSubtreeIfNeeded()

        let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds)!
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)

        let image = NSImage(size: NSSize(width: size, height: size))
        image.addRepresentation(bitmapRep)
        return image
    }

    func clearCache() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}

// MARK: - Cached Pixel Avatar View

struct CachedPixelAvatarView: View {
    let name: String
    let type: ProviderType
    let size: CGFloat

    @State private var renderedImage: NSImage?

    var body: some View {
        Group {
            if let image = renderedImage {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: size, height: size)
            } else {
                // Placeholder while rendering
                PixelAvatarView(name: name, type: type, size: size)
            }
        }
        .onAppear {
            renderAsync()
        }
    }

    private func renderAsync() {
        DispatchQueue.global(qos: .userInitiated).async {
            let cached = PixelAvatarCache.shared.avatar(for: name, type: type, size: size)
            DispatchQueue.main.async {
                self.renderedImage = cached
            }
        }
    }
}
