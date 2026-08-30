import Foundation
import SwiftData

/// 运行日志。原项目 `LogModel{Timestamp, Message}`，对应日志页。
@Model
final class AppLog {
    var timestamp: Date = Date()
    var message: String = ""

    init(message: String, timestamp: Date = Date()) {
        self.message = message
        self.timestamp = timestamp
    }
}

enum LogStore {
    static func write(_ message: String, to context: ModelContext) {
        context.insert(AppLog(message: message))
        try? context.save()
    }

    static func clear(in context: ModelContext) throws {
        try context.delete(model: AppLog.self)
        try context.save()
    }
}
