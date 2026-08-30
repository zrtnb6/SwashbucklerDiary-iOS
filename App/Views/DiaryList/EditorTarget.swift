import Foundation

/// 编辑器的打开目标：新建，或者编辑某一篇。
///
/// 列表、标签详情、模板页都要唤起同一个编辑器，抽出来共用。
enum EditorTarget: Identifiable {
    case new(asTemplate: Bool = false)
    case existing(Diary)

    var id: String {
        switch self {
        case .new(let asTemplate):
            return asTemplate ? "new-template" : "new"
        case .existing(let diary):
            return diary.id.uuidString
        }
    }

    var diary: Diary? {
        switch self {
        case .new: return nil
        case .existing(let diary): return diary
        }
    }

    /// 从模板页新建时，新日记直接就是模板。
    var asTemplate: Bool {
        if case .new(let asTemplate) = self { return asTemplate }
        return false
    }
}
