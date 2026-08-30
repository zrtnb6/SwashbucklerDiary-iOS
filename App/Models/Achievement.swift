import Foundation
import SwiftData

/// 成就类型。照搬原项目 `achievements.json` 的 10 种 Kind。
/// 注意 `tag` 在原项目里**没有对应成就**（steps 为空），保留枚举只为对齐数据。
enum AchievementType: String, Codable, CaseIterable {
    case diary
    case word
    case sourceCode
    case log
    case share
    case export
    case avatar
    case nickName
    case sign
    case tag

    /// 每个类型下的阶梯阈值，与原项目 14 个成就一一对应。
    var steps: [Int] {
        switch self {
        case .diary:      return [1, 30, 100, 1000]
        case .word:       return [3000, 10000, 100000]
        case .sourceCode: return [1]
        case .log:        return [1]
        case .share:      return [1]
        case .export:     return [1]
        case .avatar:     return [1]
        case .nickName:   return [1]
        case .sign:       return [1]
        case .tag:        return []
        }
    }

    var displayName: String {
        switch self {
        case .diary:      return "日记"
        case .word:       return "字数"
        case .sourceCode: return "源码"
        case .log:        return "日志"
        case .share:      return "分享"
        case .export:     return "导出"
        case .avatar:     return "头像"
        case .nickName:   return "昵称"
        case .sign:       return "签名"
        case .tag:        return "标签"
        }
    }
}

/// 单个成就（类型 + 阈值 = 一个成就）。原项目共 14 个。
struct Achievement: Identifiable, Hashable {
    let type: AchievementType
    let threshold: Int

    var id: String { "\(type.rawValue)_\(threshold)" }

    var title: String {
        switch type {
        case .diary:      return "写下 \(threshold) 篇日记"
        case .word:       return "累计 \(threshold) 字"
        case .sourceCode: return "查看源码"
        case .log:        return "查看日志"
        case .share:      return "分享一次"
        case .export:     return "导出一次"
        case .avatar:     return "设置头像"
        case .nickName:   return "设置昵称"
        case .sign:       return "设置签名"
        case .tag:        return "标签"
        }
    }

    static var all: [Achievement] {
        AchievementType.allCases.flatMap { type in
            type.steps.map { Achievement(type: type, threshold: $0) }
        }
    }
}

/// 成就进度计数器。原项目 `UserStateModel{Type, Count}`，按类型累加。
@Model
final class UserState {
    @Attribute(.unique) var typeRaw: String = AchievementType.diary.rawValue
    var count: Int = 0

    var type: AchievementType {
        get { AchievementType(rawValue: typeRaw) ?? .diary }
        set { typeRaw = newValue.rawValue }
    }

    init(type: AchievementType, count: Int = 0) {
        self.typeRaw = type.rawValue
        self.count = count
    }
}

/// 已解锁的成就。原项目 `UserAchievementModel{CompleteRate, IsCompleted, CompletedTime}`。
@Model
final class UserAchievement {
    @Attribute(.unique) var id: String = ""
    var typeRaw: String = AchievementType.diary.rawValue
    var threshold: Int = 0
    var isCompleted: Bool = false
    var completedTime: Date?

    var type: AchievementType {
        get { AchievementType(rawValue: typeRaw) ?? .diary }
        set { typeRaw = newValue.rawValue }
    }

    init(id: String, type: AchievementType, threshold: Int) {
        self.id = id
        self.typeRaw = type.rawValue
        self.threshold = threshold
    }
}
