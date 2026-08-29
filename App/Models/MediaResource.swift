import Foundation

enum MediaResource: String, Codable, CaseIterable, Identifiable {
    case image
    case audio
    case video

    var id: String { rawValue }

    var directoryName: String {
        switch self {
        case .image: "images"
        case .audio: "audios"
        case .video: "videos"
        }
    }

    var systemImage: String {
        switch self {
        case .image: "photo"
        case .audio: "waveform"
        case .video: "film"
        }
    }
}
