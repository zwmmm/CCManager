import AppKit
import SwiftUI

// MARK: - Pixel Avatar Cache

final class PixelAvatarCache {
    static let shared = PixelAvatarCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 100
    }

    func avatar(for name: String, type: ProviderType, size: CGFloat) -> NSImage {
        let key = "\(name)-\(type.rawValue)-\(Int(size))" as NSString

        if let cached = cache.object(forKey: key) {
            return cached
        }

        // renderAvatar must run on main thread (AppKit restriction)
        var image: NSImage?
        if Thread.isMainThread {
            image = renderAvatar(name: name, type: type, size: size)
        } else {
            DispatchQueue.main.sync {
                image = renderAvatar(name: name, type: type, size: size)
            }
        }

        if let img = image {
            cache.setObject(img, forKey: key)
            return img
        }

        // Fallback if rendering failed
        let fallback = NSImage(size: NSSize(width: size, height: size))
        fallback.lockFocus()
        NSColor.gray.setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill()
        fallback.unlockFocus()
        return fallback
    }

    private func renderAvatar(name: String, type: ProviderType, size: CGFloat) -> NSImage {
        let view = PixelAvatarView(name: name, type: type, size: size)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: size, height: size)
        hostingView.layoutSubtreeIfNeeded()

        guard let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            // Fallback: Return a simple colored square when bitmap capture fails (e.g., view not in window hierarchy)
            let fallback = NSImage(size: NSSize(width: size, height: size))
            fallback.lockFocus()
            NSColor.gray.setFill()
            NSRect(x: 0, y: 0, width: size, height: size).fill()
            fallback.unlockFocus()
            return fallback
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)

        let image = NSImage(size: NSSize(width: size, height: size))
        image.addRepresentation(bitmapRep)
        return image
    }

    func clearCache() {
        cache.removeAllObjects()
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
