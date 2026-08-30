import Foundation
import SwiftData

enum Persistence {
    /// 原项目 8 张表（DiaryTag / DiaryResource 由 SwiftData 自动生成关联表）。
    static let schema = Schema([
        Diary.self,
        Tag.self,
        Resource.self,
        Location.self,
        UserState.self,
        UserAchievement.self,
        AppLog.self
    ])

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
