import Foundation
import SwiftUI

/// 主题：原项目 `Setting.Theme`，0 跟随系统 / 1 浅色 / 2 深色。
enum AppTheme: Int, Codable, CaseIterable, Identifiable {
    case system = 0
    case light = 1
    case dark = 2

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light:  return "浅色"
        case .dark:   return "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// 排序字段，对应原项目 `DiarySort` / `TagSort` / `LocationSort`。
enum SortField: String, Codable, CaseIterable, Identifiable {
    case createTime
    case updateTime
    case count
    case name

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .createTime: return "创建时间"
        case .updateTime: return "更新时间"
        case .count:      return "数量"
        case .name:       return "名称"
        }
    }
}

struct SortOption: Codable, Equatable, Hashable {
    var field: SortField
    var ascending: Bool

    static let diaryDefault = SortOption(field: .updateTime, ascending: false)
    static let tagDefault = SortOption(field: .count, ascending: false)

    var displayName: String { "\(field.displayName)·\(ascending ? "升" : "降")" }
}

/// 模板套用方式，原项目 `UseTemplateKind`。
enum UseTemplateMethod: Int, Codable, CaseIterable, Identifiable {
    case cover = 0
    case insert = 1

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .cover:  return "覆盖"
        case .insert: return "插入"
        }
    }
}

/// 设置项数据体。
///
/// 对照原项目 `Setting.cs` 的 64 项。**密码类字段一律不在这里**——
/// 隐私模式入口密码、应用锁密码、WebDAV 密码全部走 Keychain（见 `Keychain.swift`）。
///
/// 之所以拆成 Codable 结构体而不是满屏 `@AppStorage`：`@AppStorage` 在
/// `@Observable` 类里写入不会触发视图刷新，是个静默的坑。
struct SettingsData: Codable {
    // MARK: 用户资料
    var language: String = "zh-CN"
    var theme: AppTheme = .system
    var firstSetLanguage: Bool = false
    var firstAgree: Bool = false
    var nickName: String = ""
    var signature: String = ""
    var avatarFileName: String = "logo.jpg"

    // MARK: 日记
    var enableTitle: Bool = false
    var enableMarkdown: Bool = true
    var enableOtherInfo: Bool = true
    var diaryIconText: Bool = false
    var editAutoSaveSeconds: Int = 5
    var diaryTimeFormat: String = "yyyy/MM/dd dddd"
    var diaryInsertTimeFormat: String = "yyyy/MM/dd HH:mm:ss"
    var diarySort: SortOption = .diaryDefault
    var tagSort: SortOption = .tagDefault
    var locationSort: SortOption = .tagDefault

    // MARK: 排版
    var firstLineIndent: Bool = false
    var codeLineNumber: Bool = false
    var taskListLineThrough: Bool = false
    var imageLazy: Bool = true
    var autoPlay: Bool = false
    var linkCard: Bool = true
    var keepOriginalFileName: Bool = false

    // MARK: 首页
    var showIndexDate: Bool = false
    var showWelcomeText: Bool = false
    var showStatisticsCard: Bool = true

    // MARK: 日记卡片
    var cardShowIcon: Bool = true
    var cardShowTags: Bool = false
    var cardShowLocation: Bool = false
    var cardRenderMarkdown: Bool = false
    var cardDefaultTitle: Bool = true
    var cardTimeFormat: String = "MM/dd"

    // MARK: 交互
    var alertTimeoutMs: Int = 2000
    var achievementsAlert: Bool = true
    var quickRecord: Bool = false
    var showOutline: Bool = false
    var outlineOnRight: Bool = true
    var firstDayOfWeek: Int = 0

    // MARK: 模板
    var useTemplateMethod: UseTemplateMethod = .cover
    var selectTemplateWhenCreate: Bool = false
    var defaultTemplateId: String = ""
    var urlSchemePrefix: String = "swashbucklerdiary"

    // MARK: 更新提示
    var updatePrompt: Bool = true
    var updatePromptIntervalDay: Int = 1
    var updateMethod: Int = 0
    var lastUpdatePromptTime: TimeInterval = 0

    // MARK: 隐私模式（只存开关，密码在 Keychain）
    var hidePrivacyModeEntrance: Bool = false
    var privacyModeDark: Bool = true
    var setPrivacyDiary: Bool = true
    var privacyModeFunctionSearchKey: String = ""

    // MARK: WebDAV（只存地址与账号，密码在 Keychain）
    var webDAVServerAddress: String = ""
    var webDAVAccount: String = ""
    var webDAVCopyResources: Bool = false
}

/// 设置容器。视图里通过 `settings.data.xxx` 读写，改动自动落盘。
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private static let storageKey = "SwashbucklerDiary.Settings"

    var data: SettingsData {
        didSet { persist() }
    }

    init() {
        if let raw = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(SettingsData.self, from: raw) {
            data = decoded
        } else {
            data = SettingsData()
        }
    }

    private func persist() {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        UserDefaults.standard.set(encoded, forKey: Self.storageKey)
    }

    func reset() {
        data = SettingsData()
    }
}
