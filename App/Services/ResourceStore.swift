import Foundation
import UIKit

/// 日记资源（图片 / 音频 / 视频）的沙盒存储。
///
/// 数据库里只存**相对路径**（`images/xxx.jpg`），不存绝对路径——
/// iOS 每次重装 App 的容器路径都会变，存绝对路径等于存了个定时炸弹。
enum ResourceStore {
    static func save(_ data: Data, type: MediaResource, fileExtension: String) throws -> String {
        let directory = rootDirectory.appendingPathComponent(type.directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileName = "\(UUID().uuidString).\(fileExtension)"
        let fileURL = directory.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return "\(type.directoryName)/\(fileName)"
    }

    /// 相对路径 -> 可访问的 file URL。
    static func url(forRelativePath path: String) -> URL {
        rootDirectory.appendingPathComponent(path)
    }

    static func delete(relativePath: String) {
        try? FileManager.default.removeItem(at: url(forRelativePath: relativePath))
    }

    /// 图片压缩后再入库。原图动辄 5-10MB，日记存原图会迅速撑爆备份包。
    /// 上限 1920px + JPEG 0.82 是清晰度与体积的平衡点。
    static func normalizedImageData(_ data: Data) throws -> Data {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return data }
        let maxDimension: CGFloat = 1920
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        guard scale < 1 else {
            return image.jpegData(compressionQuality: 0.82) ?? data
        }
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.82) ?? data
        #else
        return data
        #endif
    }

    private static var rootDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask)[0]
        return documents.appendingPathComponent("Resources", isDirectory: true)
    }
}
