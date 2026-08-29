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
        let patterns = [
            #"```[\s\S]*?```"#,   // fenced code blocks
            #"`[^`]*`"#,          // inline code
            #"!\[[^\]]*\]\([^)]*\)"#, // images
            #"\[([^\]]*)\]\([^)]*\)"  // links -> keep label
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(text.startIndex..., in: text)
                if pattern.contains("(") && pattern.contains("[") && !pattern.contains("!") {
                    text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "$1")
                } else {
                    text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
                }
            }
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
}
