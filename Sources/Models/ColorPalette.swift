import SwiftUI

struct ChineseColor: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let pinyin: String
    let hex: String
    let category: ColorCategory

    var color: Color {
        Color(hex: hex)
    }

    var nsColor: NSColor {
        NSColor(hex: hex) ?? .systemGreen
    }

    enum ColorCategory: String, CaseIterable {
        case yellow = "黄色"
        case orange = "橙黄"
        case red = "红"
        case purple = "紫"
        case blue = "蓝"
        case green = "绿"
        case cyan = "青"
        case brown = "褐"
        case neutral = "中性"
    }
}

// MARK: - Shared hex parsing

private struct RGBA {
    let r: UInt64
    let g: UInt64
    let b: UInt64
    let a: UInt64
}

/// Parse a hex string (3, 6, or 8 chars) into RGBA components.
/// Returns nil if parsing fails.
private func parseHex(_ hex: String) -> RGBA? {
    let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    guard Scanner(string: cleaned).scanHexInt64(&int) else { return nil }
    switch cleaned.count {
    case 3:
        return RGBA(r: (int >> 8) * 17, g: (int >> 4 & 0xF) * 17, b: (int & 0xF) * 17, a: 255)
    case 6:
        return RGBA(r: int >> 16, g: int >> 8 & 0xFF, b: int & 0xFF, a: 255)
    case 8:
        return RGBA(r: int >> 24, g: int >> 16 & 0xFF, b: int >> 8 & 0xFF, a: int & 0xFF)
    default:
        return nil
    }
}

extension Color {
    init(hex: String) {
        if let rgba = parseHex(hex) {
            self.init(.sRGB, red: Double(rgba.r) / 255, green: Double(rgba.g) / 255, blue: Double(rgba.b) / 255, opacity: Double(rgba.a) / 255)
        } else {
            self.init(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)
        }
    }
}

extension NSColor {
    convenience init?(hex: String) {
        guard let rgba = parseHex(hex) else { return nil }
        self.init(red: CGFloat(rgba.r) / 255, green: CGFloat(rgba.g) / 255, blue: CGFloat(rgba.b) / 255, alpha: CGFloat(rgba.a) / 255)
    }
}

struct ColorPalette {
    static let allColors: [ChineseColor] = [
        // 黄色 Yellow
        ChineseColor(name: "乳白", pinyin: "rubai", hex: "f9f4dc", category: .yellow),
        ChineseColor(name: "杏仁黄", pinyin: "xingrenhuang", hex: "f7e8aa", category: .yellow),
        ChineseColor(name: "茉莉黄", pinyin: "molihuang", hex: "f8df72", category: .yellow),
        ChineseColor(name: "麦秆黄", pinyin: "maiganhuang", hex: "f8df70", category: .yellow),
        ChineseColor(name: "油菜花黄", pinyin: "youcaihuahuang", hex: "fbda41", category: .yellow),
        ChineseColor(name: "佛手黄", pinyin: "foshouhuang", hex: "fed71a", category: .yellow),
        ChineseColor(name: "篾黄", pinyin: "miehuang", hex: "f7de98", category: .yellow),
        ChineseColor(name: "柠檬黄", pinyin: "ningmenghuang", hex: "fcd337", category: .yellow),
        ChineseColor(name: "金瓜黄", pinyin: "jinguahuang", hex: "fcd217", category: .yellow),
        ChineseColor(name: "藤黄", pinyin: "tenghuang", hex: "ffd111", category: .yellow),
        ChineseColor(name: "酪黄", pinyin: "laohuang", hex: "f6dead", category: .yellow),
        ChineseColor(name: "淡蜜黄", pinyin: "danmihuang", hex: "f9d367", category: .yellow),
        ChineseColor(name: "大豆黄", pinyin: "dadouhuang", hex: "fbcd31", category: .yellow),
        ChineseColor(name: "素馨黄", pinyin: "suxinhuang", hex: "fccb16", category: .yellow),
        ChineseColor(name: "向日葵黄", pinyin: "xiangrikuihuang", hex: "fecc11", category: .yellow),
        ChineseColor(name: "雅梨黄", pinyin: "yalihuang", hex: "fbc82f", category: .yellow),
        ChineseColor(name: "黄连黄", pinyin: "huanglianhuang", hex: "fcc515", category: .yellow),
        ChineseColor(name: "金盏黄", pinyin: "jinzhanhuang", hex: "fcc307", category: .yellow),
        ChineseColor(name: "蛋壳黄", pinyin: "dankehuang", hex: "f8c387", category: .yellow),
        ChineseColor(name: "秋葵黄", pinyin: "qiukuihuang", hex: "eed045", category: .yellow),
        ChineseColor(name: "硫华黄", pinyin: "liuhuahuang", hex: "f2ce2b", category: .yellow),
        ChineseColor(name: "姜黄", pinyin: "jianghuang", hex: "e2c027", category: .yellow),

        // 橙黄 Orange-Yellow
        ChineseColor(name: "肉色", pinyin: "rouse", hex: "f7c173", category: .orange),
        ChineseColor(name: "鹅掌黄", pinyin: "ezhanghuang", hex: "fbb929", category: .orange),
        ChineseColor(name: "鸡蛋黄", pinyin: "jidanhuang", hex: "fbb612", category: .orange),
        ChineseColor(name: "鼬黄", pinyin: "youhuang", hex: "fcb70a", category: .orange),
        ChineseColor(name: "淡橘橙", pinyin: "danjucheng", hex: "fba414", category: .orange),
        ChineseColor(name: "枇杷黄", pinyin: "pipahuang", hex: "fca106", category: .orange),
        ChineseColor(name: "橙皮黄", pinyin: "chengpihuang", hex: "fca104", category: .orange),
        ChineseColor(name: "北瓜黄", pinyin: "beiguahuang", hex: "fc8c23", category: .orange),
        ChineseColor(name: "杏黄", pinyin: "xinghuang", hex: "f28e16", category: .orange),
        ChineseColor(name: "雄黄", pinyin: "xionghuang", hex: "ff9900", category: .orange),
        ChineseColor(name: "万寿菊黄", pinyin: "wanshoujuhuang", hex: "fb8b05", category: .orange),

        // 红色 Red
        ChineseColor(name: "玫瑰粉", pinyin: "meiguifen", hex: "f8b37f", category: .red),
        ChineseColor(name: "橘橙", pinyin: "jucheng", hex: "f97d1c", category: .red),
        ChineseColor(name: "美人焦橙", pinyin: "meirenjiaocheng", hex: "fa7e23", category: .red),
        ChineseColor(name: "润红", pinyin: "runhong", hex: "f7cdbc", category: .red),
        ChineseColor(name: "淡桃红", pinyin: "dantaohong", hex: "f6cec1", category: .red),
        ChineseColor(name: "海螺橙", pinyin: "hailuocheng", hex: "f0945d", category: .red),
        ChineseColor(name: "桃红", pinyin: "taohong", hex: "f0ada0", category: .red),
        ChineseColor(name: "颊红", pinyin: "jiahong", hex: "eeaa9c", category: .red),
        ChineseColor(name: "晨曦红", pinyin: "chenxihong", hex: "ea8958", category: .red),
        ChineseColor(name: "蟹壳红", pinyin: "xiekehong", hex: "f27635", category: .red),
        ChineseColor(name: "金莲花橙", pinyin: "jinlianhuacheng", hex: "f86b1d", category: .red),
        ChineseColor(name: "草莓红", pinyin: "caomeihong", hex: "ef6f48", category: .red),
        ChineseColor(name: "蜻蜓红", pinyin: "qingtinghong", hex: "f1441d", category: .red),
        ChineseColor(name: "大红", pinyin: "dahong", hex: "f04b22", category: .red),
        ChineseColor(name: "柿红", pinyin: "shihong", hex: "f2481b", category: .red),
        ChineseColor(name: "榴花红", pinyin: "liuhuahong", hex: "f34718", category: .red),
        ChineseColor(name: "银朱", pinyin: "yinzhu", hex: "f43e06", category: .red),
        ChineseColor(name: "朱红", pinyin: "zhuhong", hex: "ed5126", category: .red),
        ChineseColor(name: "粉红", pinyin: "fenhong", hex: "f2b9b2", category: .red),
        ChineseColor(name: "胭脂红", pinyin: "yanzhihong", hex: "f03f24", category: .red),
        ChineseColor(name: "春梅红", pinyin: "chunmeihong", hex: "f1939c", category: .red),
        ChineseColor(name: "珊瑚红", pinyin: "shanhuhong", hex: "f04a3a", category: .red),
        ChineseColor(name: "萝卜红", pinyin: "luobohong", hex: "f13c22", category: .red),
        ChineseColor(name: "艳红", pinyin: "yanhong", hex: "ed5a65", category: .red),
        ChineseColor(name: "樱桃红", pinyin: "yingtaohong", hex: "ed3321", category: .red),
        ChineseColor(name: "夕阳红", pinyin: "xiyanghong", hex: "de2a18", category: .red),

        // 紫色 Purple
        ChineseColor(name: "吊紫", pinyin: "diaozi", hex: "5d3131", category: .purple),
        ChineseColor(name: "暗玉紫", pinyin: "anyuzi", hex: "5c2223", category: .purple),
        ChineseColor(name: "栗紫", pinyin: "lizi", hex: "5a191b", category: .purple),
        ChineseColor(name: "葡萄酱紫", pinyin: "putaojiangzi", hex: "5a1216", category: .purple),
        ChineseColor(name: "山茶红", pinyin: "shanchahong", hex: "ed556a", category: .purple),
        ChineseColor(name: "海棠红", pinyin: "haitanghong", hex: "f03752", category: .purple),
        ChineseColor(name: "玉红", pinyin: "yuhong", hex: "c04851", category: .purple),
        ChineseColor(name: "高粱红", pinyin: "gaolianghong", hex: "c02c38", category: .purple),
        ChineseColor(name: "满江红", pinyin: "manjianghong", hex: "a7535a", category: .purple),
        ChineseColor(name: "枣红", pinyin: "zaohong", hex: "7c1823", category: .purple),
        ChineseColor(name: "葡萄紫", pinyin: "putaozi", hex: "4c1f24", category: .purple),
        ChineseColor(name: "酱紫", pinyin: "jiangzi", hex: "4d1018", category: .purple),

        // 蓝色 Blue
        ChineseColor(name: "远山紫", pinyin: "yuanshanzi", hex: "ccccd6", category: .blue),
        ChineseColor(name: "淡蓝紫", pinyin: "danlanzi", hex: "a7a8bd", category: .blue),
        ChineseColor(name: "山梗紫", pinyin: "shangengzi", hex: "61649f", category: .blue),
        ChineseColor(name: "螺甸紫", pinyin: "luodianzi", hex: "74759b", category: .blue),
        ChineseColor(name: "野菊紫", pinyin: "yejuzi", hex: "525288", category: .blue),
        ChineseColor(name: "满天星紫", pinyin: "mantianxingzi", hex: "2e317c", category: .blue),
        ChineseColor(name: "野葡萄紫", pinyin: "yeputaozi", hex: "302f4b", category: .blue),
        ChineseColor(name: "龙葵紫", pinyin: "longkuizi", hex: "322f3b", category: .blue),
        ChineseColor(name: "暗龙胆紫", pinyin: "anlongdanzi", hex: "22202e", category: .blue),
        ChineseColor(name: "晶石紫", pinyin: "jingshizi", hex: "1f2040", category: .blue),
        ChineseColor(name: "暗蓝紫", pinyin: "anlanzi", hex: "131124", category: .blue),

        // 绿色 Green
        ChineseColor(name: "新禾绿", pinyin: "xinhelv", hex: "d2b116", category: .green),
        ChineseColor(name: "淡灰绿", pinyin: "danhuilv", hex: "ad9e5f", category: .green),
        ChineseColor(name: "草灰绿", pinyin: "caohuilv", hex: "8e804b", category: .green),
        ChineseColor(name: "苔绿", pinyin: "tailv", hex: "887322", category: .green),
        ChineseColor(name: "碧螺春绿", pinyin: "biluochunlv", hex: "867018", category: .green),
        ChineseColor(name: "潭水绿", pinyin: "tanshuilv", hex: "645822", category: .green),
        ChineseColor(name: "橄榄绿", pinyin: "ganlanlv", hex: "5e5314", category: .green),
        ChineseColor(name: "暗海水绿", pinyin: "anhaishuilv", hex: "584717", category: .green),
        ChineseColor(name: "棕榈绿", pinyin: "zonglvlv", hex: "5b4913", category: .green),
        ChineseColor(name: "石绿", pinyin: "shilv", hex: "57c3c2", category: .green),
        ChineseColor(name: "竹簧绿", pinyin: "zhuhuanglv", hex: "b9dec9", category: .green),
        ChineseColor(name: "粉绿", pinyin: "fenlv", hex: "83cbac", category: .green),
        ChineseColor(name: "美蝶绿", pinyin: "meidielv", hex: "12aa9c", category: .green),
        ChineseColor(name: "毛绿", pinyin: "maolv", hex: "66c18c", category: .green),
        ChineseColor(name: "麦苗绿", pinyin: "maimiaolv", hex: "55bb8a", category: .green),
        ChineseColor(name: "瓦绿", pinyin: "walv", hex: "45b787", category: .green),
        ChineseColor(name: "铜绿", pinyin: "tonglv", hex: "2bae85", category: .green),
        ChineseColor(name: "竹绿", pinyin: "zhulv", hex: "1ba784", category: .green),
        ChineseColor(name: "蓝绿", pinyin: "lanlv", hex: "12a182", category: .green),

        // 青色 Cyan
        ChineseColor(name: "景泰蓝", pinyin: "jingtailan", hex: "2775b6", category: .cyan),
        ChineseColor(name: "尼罗蓝", pinyin: "niluolan", hex: "2474b5", category: .cyan),
        ChineseColor(name: "星蓝", pinyin: "xinglan", hex: "93b5cf", category: .cyan),
        ChineseColor(name: "羽扇豆蓝", pinyin: "yushandoulan", hex: "619ac3", category: .cyan),
        ChineseColor(name: "花青", pinyin: "huaqing", hex: "2376b7", category: .cyan),
        ChineseColor(name: "睛蓝", pinyin: "jinglan", hex: "5698c3", category: .cyan),
        ChineseColor(name: "翠蓝", pinyin: "cuilan", hex: "1e9eb3", category: .cyan),
        ChineseColor(name: "淡帆蓝", pinyin: "danfanlan", hex: "0f95b0", category: .cyan),
        ChineseColor(name: "舰鸟蓝", pinyin: "jianniaolan", hex: "1491a8", category: .cyan),
        ChineseColor(name: "玉琴蓝", pinyin: "yuqinlan", hex: "126e82", category: .cyan),

        // 褐色 Brown
        ChineseColor(name: "月灰", pinyin: "yuehui", hex: "b7ae8f", category: .brown),
        ChineseColor(name: "燕羽灰", pinyin: "yanyuhui", hex: "685e48", category: .brown),
        ChineseColor(name: "蟹壳灰", pinyin: "xiekehui", hex: "695e45", category: .brown),
        ChineseColor(name: "银灰", pinyin: "yinhui", hex: "918072", category: .brown),
        ChineseColor(name: "鹤灰", pinyin: "hehui", hex: "4a4035", category: .brown),
        ChineseColor(name: "象灰", pinyin: "xianghui", hex: "9a8878", category: .brown),
        ChineseColor(name: "瓦灰", pinyin: "wahui", hex: "867e76", category: .brown),
        ChineseColor(name: "中灰", pinyin: "zhonghui", hex: "a49c93", category: .brown),
        ChineseColor(name: "深灰", pinyin: "shenhui", hex: "81776e", category: .brown),
        ChineseColor(name: "夜灰", pinyin: "yehui", hex: "847c74", category: .brown),

        // 中性 Neutral
        ChineseColor(name: "象牙白", pinyin: "xiangyabai", hex: "fffef8", category: .neutral),
        ChineseColor(name: "汉白玉", pinyin: "hanbaiyu", hex: "f8f4ed", category: .neutral),
        ChineseColor(name: "雪白", pinyin: "xuebai", hex: "fffef9", category: .neutral),
        ChineseColor(name: "鱼肚白", pinyin: "yudubai", hex: "f7f4ed", category: .neutral),
        ChineseColor(name: "月白", pinyin: "yuebai", hex: "eef7f2", category: .neutral),
        ChineseColor(name: "珍珠灰", pinyin: "zhenzhuhui", hex: "e4dfd7", category: .neutral),
        ChineseColor(name: "浅灰", pinyin: "qianhui", hex: "dad4cb", category: .neutral),
        ChineseColor(name: "铅灰", pinyin: "qianhui2", hex: "bbb5ac", category: .neutral),
    ]

    static let defaultBrandColor = ChineseColor(
        name: "粉绿",
        pinyin: "fenlv",
        hex: "83cbac",
        category: .green
    )

    /// Pre-grouped colors by category — avoids linear scan of allColors for filtering
    static let colorsByCategory: [ChineseColor.ColorCategory: [ChineseColor]] = {
        Dictionary(grouping: allColors, by: { $0.category })
    }()
}
