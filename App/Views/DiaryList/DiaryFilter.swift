import Foundation

/// 列表筛选条件。
enum DiaryFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case pinned = "置顶"
    case withMedia = "含媒体"
    case recentWeek = "最近七天"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .all: return "tray"
        case .pinned: return "pin"
        case .withMedia: return "photo"
        case .recentWeek: return "calendar"
        }
    }

    func matches(_ diary: Diary) -> Bool {
        switch self {
        case .all:
            return true
        case .pinned:
            return diary.isPinned
        case .withMedia:
            return !diary.resources.isEmpty
        case .recentWeek:
            guard let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else {
                return false
            }
            return diary.updateTime >= cutoff
        }
    }
}

/// 列表的排序方式。
///
/// 这里用内存排序而不是 `SortDescriptor`：`@Query` 的排序参数在初始化时就固定了，
/// 运行时改不了。个人日记的量级（几百到几千篇）内存排序完全够用，换来的是
/// 切换排序时不用重建 Query。
enum DiarySort: String, CaseIterable, Identifiable {
    case updated = "按更新时间"
    case created = "按创建时间"
    case title = "按标题"

    var id: String { rawValue }

    func sort(_ list: [Diary]) -> [Diary] {
        switch self {
        case .updated:
            return list.sorted { $0.updateTime > $1.updateTime }
        case .created:
            return list.sorted { $0.createTime > $1.createTime }
        case .title:
            return list.sorted {
                $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
            }
        }
    }
}
