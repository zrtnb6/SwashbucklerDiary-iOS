import Foundation
import SwiftData

@Model
final class Diary {
    @Attribute(.unique) var id: UUID = UUID()
    var createTime: Date = Date()
    var updateTime: Date = Date()

    var title: String = ""
    var content: String = ""
    var mood: String = ""
    var weather: String = ""
    var locationName: String = ""

    var isPinned: Bool = false
    var isTemplate: Bool = false
    /// 隐私模式的日记。原项目用独立的「隐私库」实现，这里退化为布尔标记 +
    /// 入口密码（Keychain）——单库方案对 SwiftData 更稳妥，行为上等价。
    var isPrivate: Bool = false

    @Relationship(inverse: \Tag.diaries) var tags: [Tag] = []
    @Relationship(inverse: \Resource.diaries) var resources: [Resource] = []

    init(
        title: String = "",
        content: String = "",
        mood: String = "",
        weather: String = "",
        locationName: String = ""
    ) {
        self.title = title
        self.content = content
        self.mood = mood
        self.weather = weather
        self.locationName = locationName
        self.createTime = Date()
        self.updateTime = Date()
    }

    /// Plain-text summary used on list cells, with common Markdown noise stripped out.
    var plainSummary: String {
        var text = content
        // (正则, 替换模板)。链接保留可读的标签文字，其余噪声直接抹掉。
        let rules: [(pattern: String, template: String)] = [
            (#"```[\s\S]*?```"#, ""),          // 围栏代码块
            (#"`[^`]*`"#, ""),                 // 行内代码
            (#"!\[[^\]]*\]\([^)]*\)"#, ""),    // 图片
            (#"\[([^\]]*)\]\([^)]*\)"#, "$1")  // 链接 -> 保留标签
        ]

        for rule in rules {
            guard let regex = try? NSRegularExpression(pattern: rule.pattern) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: rule.template)
        }

        let flattened = text
            .replacingOccurrences(of: #"[#>*_~`-]"#, with: "", options: .regularExpression)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return String(flattened.prefix(140))
    }

    var wordCount: Int {
        content.filter { !$0.isWhitespace && !$0.isNewline }.count
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let firstLine = content
            .components(separatedBy: .newlines)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return firstLine.map { String($0.prefix(40)) } ?? ""
    }

    func touch() {
        updateTime = Date()
    }

    /// 复制一份出来（原项目「复制日记」）。关联与资源沿用同一批对象，
    /// 时间戳重置为当下，标题加「副本」后缀。
    func makeCopy() -> Diary {
        let copy = Diary(
            title: title.isEmpty ? "" : "\(title) 副本",
            content: content,
            mood: mood,
            weather: weather,
            locationName: locationName
        )
        copy.tags = tags
        copy.resources = resources
        return copy
    }
}

// MARK: - 展示辅助

extension Diary {
    /// 心情 -> SF Symbol。没匹配上就给个通用的表情图标，不至于空着难看。
    var moodSymbol: String {
        Self.symbol(for: mood, table: Self.moodTable, fallback: "face.smiling")
    }

    /// 天气 -> SF Symbol。
    var weatherSymbol: String {
        Self.symbol(for: weather, table: Self.weatherTable, fallback: "cloud.sun")
    }

    private static func symbol(for text: String,
                               table: [String: String],
                               fallback: String) -> String {
        let key = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return fallback }
        if let exact = table[key] { return exact }
        for (word, symbol) in table where key.contains(word) {
            return symbol
        }
        return fallback
    }

    private static let moodTable: [String: String] = [
        "开心": "face.smiling",
        "高兴": "face.smiling",
        "快乐": "face.smiling",
        "愉快": "face.smiling",
        "平静": "face.smiling",
        "一般": "face.meh",
        "普通": "face.meh",
        "平淡": "face.meh",
        "难过": "face.sad",
        "伤心": "face.sad",
        "失落": "face.sad",
        "沮丧": "face.sad",
        "生气": "face.angry",
        "愤怒": "face.angry",
        "烦躁": "face.angry",
        "焦虑": "face.dashed",
        "紧张": "face.dashed",
        "疲惫": "zzz",
        "累": "zzz",
        "兴奋": "flame",
        "感动": "heart",
        "幸福": "heart.fill",
        "困惑": "questionmark.circle",
        "迷茫": "questionmark.circle",
        "孤独": "moon.stars"
    ]

    private static let weatherTable: [String: String] = [
        "晴": "sun.max",
        "太阳": "sun.max",
        "多云": "cloud.sun",
        "阴": "cloud",
        "雨": "cloud.rain",
        "小雨": "cloud.drizzle",
        "大雨": "cloud.heavyrain",
        "暴雨": "cloud.bolt.rain",
        "雷": "cloud.bolt",
        "雪": "cloud.snow",
        "风": "wind",
        "雾": "cloud.fog",
        "霾": "sun.haze",
        "冰雹": "cloud.hail"
    ]

    /// 卡片底部要标注的资源类型（去重后的图标名）。
    var resourceSymbols: [String] {
        var seen: [String] = []
        for resource in resources {
            let symbol = resource.type.systemImage
            if !seen.contains(symbol) { seen.append(symbol) }
        }
        return seen
    }
}
