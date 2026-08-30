import Foundation

/// 列表的一个分组。
struct DiarySection: Identifiable {
    let title: String
    var diaries: [Diary]

    var id: String { title }

    /// 把一批**已排好序**的日记切成置顶 / 时间分组。
    ///
    /// 分组依据必须跟着排序字段走：按更新时间排就按更新时间分组，
    /// 按标题或字数排则整列是一组——否则组内的顺序会和组标题对不上，
    /// 出现「8 月组里躺着一篇 3 月的日记」这种穿帮。
    static func build(from diaries: [Diary], sort: SortOption) -> [DiarySection] {
        var sections: [DiarySection] = []

        let pinned = diaries.filter(\.isPinned)
        let rest = diaries.filter { !$0.isPinned }

        if !pinned.isEmpty {
            sections.append(DiarySection(title: "置顶", diaries: pinned))
        }

        guard sort.field == .createTime || sort.field == .updateTime else {
            // 按标题 / 字数排序时不做时间切分，保留排序本身的结果。
            if !rest.isEmpty {
                sections.append(DiarySection(title: "全部", diaries: rest))
            }
            return sections
        }

        let useCreateTime = sort.field == .createTime
        let calendar = Calendar.current
        let now = Date()
        var order: [String] = []
        var buckets: [String: [Diary]] = [:]

        for diary in rest {
            let date = useCreateTime ? diary.createTime : diary.updateTime
            let key = date.sectionTitle(calendar: calendar, now: now)
            if buckets[key] == nil {
                buckets[key] = []
                order.append(key)
            }
            buckets[key]?.append(diary)
        }

        for key in order {
            if let items = buckets[key] {
                sections.append(DiarySection(title: key, diaries: items))
            }
        }

        return sections
    }
}
