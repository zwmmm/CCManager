import SwiftUI

// MARK: - Provider Avatar

struct PixelAvatarView: View {
    let name: String
    let type: ProviderType
    let size: CGFloat

    var body: some View {
        PixelCreatureCanvas(seed: name, type: type, size: size)
    }
}

// MARK: - 像素生物画布

private struct PixelCreatureCanvas: View {
    let seed: String
    let type: ProviderType
    let size: CGFloat

    // 像素颜色层: 0=透明 1=身体色 2=眼睛色 3=点缀色 4=深色细节

    // 猫 12×12: 尖耳、双眼、粉鼻、嘴角（鼻嘴间隔一行）
    private static let catTemplate: [[UInt8]] = [
        [0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0], // 0: 耳尖
        [0, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 0], // 1: 耳体
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], // 2: 额头
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], // 3: 额头
        [1, 1, 2, 2, 1, 1, 1, 1, 2, 2, 1, 1], // 4: 眼上半
        [1, 1, 2, 4, 1, 1, 1, 1, 2, 4, 1, 1], // 5: 眼下半+瞳孔
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], // 6: 眼下方
        [1, 1, 1, 1, 1, 3, 3, 1, 1, 1, 1, 1], // 7: 鼻子
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], // 8: 间隔
        [1, 1, 1, 1, 4, 1, 1, 4, 1, 1, 1, 1], // 9: 嘴角
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], // 10: 下巴
        [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0], // 11: 下巴边缘
    ]

    // 狗 12×12: 垂耳、双眼、大口鼻、鼻孔
    private static let dogTemplate: [[UInt8]] = [
        [1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1], // 0: 垂耳顶
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], // 1: 耳+头顶
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], // 2: 头
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], // 3: 头
        [1, 1, 2, 2, 1, 1, 1, 1, 2, 2, 1, 1], // 4: 眼上半
        [1, 1, 2, 4, 1, 1, 1, 1, 2, 4, 1, 1], // 5: 眼下半+瞳孔
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], // 6: 眼下方
        [0, 1, 3, 3, 3, 3, 3, 3, 3, 3, 1, 0], // 7: 口鼻上
        [0, 1, 3, 3, 4, 3, 3, 4, 3, 3, 1, 0], // 8: 鼻孔
        [0, 1, 3, 3, 3, 4, 4, 3, 3, 3, 1, 0], // 9: 嘴
        [0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0], // 10: 下巴
        [0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0], // 11: 下巴底
    ]

    private var template: [[UInt8]] {
        type == .codex ? Self.dogTemplate : Self.catTemplate
    }

    private var hash: Int { abs(seed.hashValue) }

    // 猫: 橘/银灰/黑/棕/奶油/蓝灰  狗: 金毛/白/巧克力/米/黑/棕
    private var bodyColor: Color {
        let catColors: [Color] = [
            Color(red: 0.88, green: 0.62, blue: 0.35), // 橘猫
            Color(red: 0.86, green: 0.86, blue: 0.86), // 银灰
            Color(red: 0.22, green: 0.22, blue: 0.25), // 黑猫
            Color(red: 0.70, green: 0.56, blue: 0.42), // 棕虎斑
            Color(red: 0.93, green: 0.87, blue: 0.76), // 奶油白
            Color(red: 0.58, green: 0.60, blue: 0.68), // 蓝灰
        ]
        let dogColors: [Color] = [
            Color(red: 0.85, green: 0.68, blue: 0.28), // 金毛
            Color(red: 0.92, green: 0.90, blue: 0.88), // 白
            Color(red: 0.40, green: 0.24, blue: 0.14), // 巧克力
            Color(red: 0.88, green: 0.80, blue: 0.65), // 米色
            Color(red: 0.15, green: 0.15, blue: 0.18), // 黑
            Color(red: 0.62, green: 0.42, blue: 0.28), // 棕
        ]
        let colors = type == .codex ? dogColors : catColors
        return colors[hash % colors.count]
    }

    private var eyeColor: Color {
        let colors: [Color] = [
            Color(red: 0.18, green: 0.72, blue: 0.28), // 翠绿
            Color(red: 0.90, green: 0.75, blue: 0.08), // 琥珀黄
            Color(red: 0.15, green: 0.52, blue: 0.88), // 蓝色
            Color(red: 0.85, green: 0.50, blue: 0.12), // 橙色
        ]
        return colors[(hash / 7) % colors.count]
    }

    // 猫=粉鼻  狗=浅色口鼻区
    private var accentColor: Color {
        type == .codex
            ? Color(red: 0.92, green: 0.85, blue: 0.72) // 狗: 米白口鼻
            : Color(red: 0.92, green: 0.62, blue: 0.70) // 猫: 粉鼻
    }

    private let detailColor = Color(red: 0.08, green: 0.06, blue: 0.10)

    var body: some View {
        Canvas { context, canvasSize in
            let px = canvasSize.width / 12.0

            for (row, rowPixels) in template.enumerated() {
                for (col, cell) in rowPixels.enumerated() {
                    guard cell != 0 else { continue }

                    let rect = CGRect(
                        x: CGFloat(col) * px,
                        y: CGFloat(row) * px,
                        width: ceil(px),
                        height: ceil(px)
                    )
                    let color: Color
                    switch cell {
                    case 1:  color = bodyColor
                    case 2:  color = eyeColor
                    case 3:  color = accentColor
                    default: color = detailColor
                    }
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: size, height: size)
    }
}
