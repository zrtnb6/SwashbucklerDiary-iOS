import Foundation

extension Date {
    var diaryDayText: String {
        formatted(.dateTime.year().month(.abbreviated).day())
    }

    var diaryTimeText: String {
        formatted(.dateTime.hour().minute())
    }

    /// Long form used on the editor header, e.g. "2026年8月30日 星期日"
    var diaryLongText: String {
        formatted(.dateTime.year().month(.wide).day().weekday(.wide))
    }

    /// 自定义格式串，给设置项里的 `diaryTimeFormat` / `cardTimeFormat` 用。
    /// 用户可能填进非法格式，解析失败就退回一个稳妥的默认样式。
    func formatted(with pattern: String, fallback: String = "yyyy/MM/dd") -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = pattern
        let result = formatter.string(from: self)
        return result.isEmpty ? formatted(with: fallback) : result
    }

    /// 列表分组标题：今天 / 昨天 / N 月 / N 年 N 月。
    func sectionTitle(calendar: Calendar = .current, now: Date = Date()) -> String {
        if calendar.isDateInToday(self) { return "今天" }
        if calendar.isDateInYesterday(self) { return "昨天" }
        if calendar.isDate(self, equalTo: now, toGranularity: .year) {
            return "\(calendar.component(.month, from: self)) 月"
        }
        return "\(calendar.component(.year, from: self)) 年 \(calendar.component(.month, from: self)) 月"
    }
}
