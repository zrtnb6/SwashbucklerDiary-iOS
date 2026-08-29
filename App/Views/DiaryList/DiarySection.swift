import Foundation

/// 列表的一个分组。
struct DiarySection: Identifiable {
    let title: String
    var diaries: [Diary]

    var id: String { title }

    /// 把一批日记切成「置顶 / 今天 / 昨天 / N月 / N年」这样的时间分组。
    static func build(from diaries: [Diary]) -> [DiarySection] {
        var sections: [DiarySection] = []

        let pinned = diaries.filter(\.isPinned)
        if !pinned.isEmpty {
            sections.append(DiarySection(title: "置顶", diaries: pinned))
        }

        let calendar = Calendar.current
        var order: [String] = []
        var buckets: [String: [Diary]] = [:]

        for diary in diaries where !diary.isPinned {
            let key = Self.sectionTitle(for: diary.updateTime, calendar: calendar)
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

    private static func sectionTitle(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }

        let now = Date()
        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return "\(calendar.component(.month, from: date)) 月"
        }
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return "\(year) 年 \(month) 月"
    }
}
