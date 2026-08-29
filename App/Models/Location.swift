import Foundation
import SwiftData

@Model
final class Location {
    @Attribute(.unique) var id: UUID = UUID()
    var createTime: Date = Date()
    var updateTime: Date = Date()

    @Attribute(.unique) var name: String = ""

    init(name: String = "") {
        self.name = name
        self.createTime = Date()
        self.updateTime = Date()
    }
}
