import Foundation
import SwiftData

@Model
final class Tag {
    @Attribute(.unique) var id: UUID = UUID()
    var createTime: Date = Date()
    var updateTime: Date = Date()

    var name: String = ""

    var diaries: [Diary] = []

    init(name: String = "") {
        self.name = name
        self.createTime = Date()
        self.updateTime = Date()
    }
}
