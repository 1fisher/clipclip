import Foundation
import SwiftData

enum TrackType: String, Codable, CaseIterable {
    case video
    case audio
}

@Model
final class Track {
    var id: UUID
    var type: TrackType
    var orderIndex: Int
    var isMuted: Bool
    var name: String

    var project: Project?
    @Relationship(deleteRule: .cascade)
    var clips: [Clip]

    init(type: TrackType, orderIndex: Int, name: String? = nil) {
        self.id = UUID()
        self.type = type
        self.orderIndex = orderIndex
        self.isMuted = false
        self.name = name ?? (type == .video ? "视频轨道 \(orderIndex + 1)" : "音频轨道 \(orderIndex + 1)")
        self.clips = []
    }
}
