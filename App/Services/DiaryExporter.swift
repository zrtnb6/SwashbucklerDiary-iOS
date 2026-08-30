import Foundation

/// 单篇日记的导出。
///
/// 原项目首页菜单里的「导出」就是把这一篇写成文件再分享出去，
/// 支持 md / txt。这里先落地 md + txt，json 等到做整库导出期再补。
enum DiaryExporter {
    /// 带 front-matter 的 Markdown。心情 / 天气 / 位置 / 标签都写进头部，
    /// 再导回任何支持 front-matter 的笔记软件都不会丢元信息。
    static func markdown(for diary: Diary) -> String {
        var lines: [String] = ["---"]
        lines.append("title: \(diary.displayTitle)")
        lines.append("date: \(iso8601(diary.createTime))")
        lines.append("updated: \(iso8601(diary.updateTime))")
        if !diary.mood.isEmpty { lines.append("mood: \(diary.mood)") }
        if !diary.weather.isEmpty { lines.append("weather: \(diary.weather)") }
        if !diary.locationName.isEmpty { lines.append("location: \(diary.locationName)") }
        if !diary.tags.isEmpty {
            lines.append("tags: [\(diary.tags.map(\.name).joined(separator: ", "))]")
        }
        lines.append("---")
        lines.append("")
        if !diary.title.isEmpty {
            lines.append("# \(diary.title)")
            lines.append("")
        }
        lines.append(diary.content)
        return lines.joined(separator: "\n")
    }

    static func plainText(for diary: Diary) -> String {
        var lines: [String] = []
        lines.append(diary.displayTitle)
        lines.append(diary.createTime.formatted(with: "yyyy/MM/dd HH:mm"))
        var meta: [String] = []
        if !diary.mood.isEmpty { meta.append("心情：\(diary.mood)") }
        if !diary.weather.isEmpty { meta.append("天气：\(diary.weather)") }
        if !diary.locationName.isEmpty { meta.append("位置：\(diary.locationName)") }
        if !meta.isEmpty { lines.append(meta.joined(separator: "  ")) }
        if !diary.tags.isEmpty {
            lines.append("标签：\(diary.tags.map(\.name).joined(separator: "、"))")
        }
        lines.append("")
        lines.append(diary.content)
        return lines.joined(separator: "\n")
    }

    /// 写成临时文件供分享面板使用。
    ///
    /// 文件名要能进文件系统，日记标题里的 `/` `:`，以及 iOS 文件名里
    /// 容易踩坑的全角符号都得替换掉。
    static func writeTemporaryFile(for diary: Diary, format: ExportFormat) -> URL? {
        let text = format == .markdown ? markdown(for: diary) : plainText(for: diary)
        let base = sanitizedFileName(diary.displayTitle.isEmpty ? "无标题" : diary.displayTitle)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(base).\(format.fileExtension)")
        do {
            try text.data(using: .utf8)?.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    enum ExportFormat: String, CaseIterable, Identifiable {
        case markdown = "Markdown"
        case text = "纯文本"

        var id: String { rawValue }

        var fileExtension: String {
            switch self {
            case .markdown: return "md"
            case .text: return "txt"
            }
        }
    }

    private static func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func sanitizedFileName(_ raw: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let collapsed = raw
            .components(separatedBy: forbidden)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.isEmpty ? "日记" : String(collapsed.prefix(60))
    }
}
