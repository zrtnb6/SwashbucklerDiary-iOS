import Foundation
import SwiftData

enum Persistence {
    static let schema = Schema([
        Diary.self,
        Tag.self,
        Resource.self,
        Location.self
    ])

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
