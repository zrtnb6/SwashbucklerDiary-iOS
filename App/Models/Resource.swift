import Foundation
import SwiftData

@Model
final class Resource {
    @Attribute(.unique) var id: UUID = UUID()
    var createTime: Date = Date()
    var updateTime: Date = Date()

    /// Relative path inside the app sandbox, e.g. "images/abcd.jpg".
    @Attribute(.unique) var resourceUri: String = ""
    var rawType: String = MediaResource.image.rawValue

    var diaries: [Diary] = []

    init(resourceUri: String = "", type: MediaResource = .image) {
        self.resourceUri = resourceUri
        self.rawType = type.rawValue
        self.createTime = Date()
        self.updateTime = Date()
    }

    var type: MediaResource {
        get { MediaResource(rawValue: rawType) ?? .image }
        set { rawType = newValue.rawValue }
    }
}
