import SwiftUI

// MARK: - Provider Avatar (DiceBear Adventurer)

struct PixelAvatarView: View {
    let name: String
    let type: ProviderType
    let size: CGFloat

    @State private var imageData: Data?
    @State private var isLoading = false

    private var diceBearURL: URL? {
        // DiceBear: Claude Code → adventurer, Codex → open-peeps
        // https://www.dicebear.com/styles/adventurer/
        // https://www.dicebear.com/styles/open-peeps/
        let style = type == .codex ? "open-peeps" : "adventurer"
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.dicebear.com"
        components.path = "/7.x/\(style)/svg"
        components.queryItems = [
            URLQueryItem(name: "seed", value: name)
        ]
        return components.url
    }

    var body: some View {
        Group {
            if let data = imageData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Placeholder while loading
                Color.gray.opacity(0.3)
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.5)
                        }
                    }
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(x: type == .claudeCode ? -1 : 1, y: 1) // Claude Code 朝左需翻转，其他朝右
        .clipShape(RoundedRectangle(cornerRadius: size * 0.15))
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url = diceBearURL else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            await MainActor.run {
                self.imageData = data
            }
        } catch {
            // Fallback: keep placeholder on error
        }
    }
}
