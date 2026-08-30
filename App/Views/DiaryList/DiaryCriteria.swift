import Foundation
import SwiftData

/// 时间范围筛选。
enum DiaryTimeRange: String, Codable, CaseIterable, Identifiable {
    case all = "全部时间"
    case today = "今天"
    case week = "最近七天"
    case month = "最近一个月"
    case year = "最近一年"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .all:   return "infinity"
        case .today: return "calendar.day.timeline.left"
        case .week:  return "calendar.badge.clock"
        case .month: return "calendar"
        case .year:  return "calendar.circle"
        }
    }

    func contains(_ date: Date, calendar: Calendar = .current, now: Date = Date()) -> Bool {
        switch self {
        case .all:
            return true
        case .today:
            return calendar.isDateInToday(date)
        case .week:
            guard let cutoff = calendar.date(byAdding: .day, value: -7, to: now) else { return true }
            return date >= cutoff
        case .month:
            guard let cutoff = calendar.date(byAdding: .month, value: -1, to: now) else { return true }
            return date >= cutoff
        case .year:
            guard let cutoff = calendar.date(byAdding: .year, value: -1, to: now) else { return true }
            return date >= cutoff
        }
    }
}

/// 资源类型筛选。原项目首页筛选面板里的「文件」维度。
enum DiaryResourceFilter: String, Codable, CaseIterable, Identifiable {
    case any = "不限"
    case withMedia = "含媒体"
    case image = "含图片"
    case audio = "含音频"
    case video = "含视频"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .any:       return "square.dashed"
        case .withMedia: return "photo.on.rectangle"
        case .image:     return "photo"
        case .audio:     return "waveform"
        case .video:     return "film"
        }
    }

    func matches(_ diary: Diary) -> Bool {
        switch self {
        case .any:
            return true
        case .withMedia:
            return !diary.resources.isEmpty
        case .image, .audio, .video:
            let raw = self == .image ? "image" : (self == .audio ? "audio" : "video")
            return diary.resources.contains { $0.rawType == raw }
        }
    }
}

/// 首页筛选条件的完整快照。
///
/// 原项目是「标签 + 时间 + 文件 + 置顶」四个维度叠加，且筛选状态会持久化。
/// 这里把状态收进一个结构体，方便直接 Codable 落盘。
struct DiaryCriteria: Equatable, Codable {
    var tagIDs: Set<UUID> = []
    var timeRange: DiaryTimeRange = .all
    var resourceFilter: DiaryResourceFilter = .any
    var pinnedOnly: Bool = false
    var searchText: String = ""

    var isActive: Bool {
        !tagIDs.isEmpty
            || timeRange != .all
            || resourceFilter != .any
            || pinnedOnly
            || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 生效条件数量，用于筛选按钮上的角标。
    var activeCount: Int {
        var count = 0
        if !tagIDs.isEmpty { count += 1 }
        if timeRange != .all { count += 1 }
        if resourceFilter != .any { count += 1 }
        if pinnedOnly { count += 1 }
        return count
    }

    func matches(_ diary: Diary, calendar: Calendar = .current, now: Date = Date()) -> Bool {
        if pinnedOnly && !diary.isPinned { return false }
        if !tagIDs.isEmpty {
            let owned = Set(diary.tags.map(\.id))
            // 标签是「或」关系：命中任意一个即可，和原项目一致。
            if owned.isDisjoint(with: tagIDs) { return false }
        }
        if !timeRange.contains(diary.updateTime, calendar: calendar, now: now) { return false }
        if !resourceFilter.matches(diary) { return false }
        return matchesSearch(diary)
    }

    private func matchesSearch(_ diary: Diary) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let needle = query.lowercased()
        return diary.title.lowercased().contains(needle)
            || diary.content.lowercased().contains(needle)
            || diary.locationName.lowercased().contains(needle)
            || diary.mood.lowercased().contains(needle)
            || diary.weather.lowercased().contains(needle)
            || diary.tags.contains { $0.name.lowercased().contains(needle) }
    }
}

extension Array where Element == Diary {
    /// 按 `SortOption` 排序。`field` 里 `count` 对日记解释为字数，`name` 解释为标题。
    func sorted(by option: SortOption) -> [Diary] {
        sorted { lhs, rhs in
            let ascending: Bool = {
                switch option.field {
                case .createTime:
                    return lhs.createTime < rhs.createTime
                case .updateTime:
                    return lhs.updateTime < rhs.updateTime
                case .count:
                    return lhs.wordCount < rhs.wordCount
                case .name:
                    return lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending
                }
            }()
            return option.ascending ? ascending : !ascending
        }
    }
}
