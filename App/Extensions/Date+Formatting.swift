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
}
