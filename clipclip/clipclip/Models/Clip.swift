import Foundation
import SwiftData
import AVFoundation

@Model
final class Clip {
    var id: UUID
    var assetLocalIdentifier: String
    var startTime: Double
    var endTime: Double
    var sortIndex: Int
    var speed: Double
    var volume: Float
    var assetDuration: Double?
    var filename: String
    var timelineOffset: Double = 0

    var track: Track?

    var duration: Double {
        endTime - startTime
    }

    var startCMTime: CMTime {
        CMTime(seconds: startTime, preferredTimescale: 600)
    }

    var endCMTime: CMTime {
        CMTime(seconds: endTime, preferredTimescale: 600)
    }

    var durationCMTime: CMTime {
        CMTime(seconds: duration, preferredTimescale: 600)
    }

    init(
        assetLocalIdentifier: String,
        startTime: Double,
        endTime: Double,
        sortIndex: Int,
        speed: Double = 1.0,
        volume: Float = 1.0,
        assetDuration: Double? = nil,
        filename: String = ""
    ) {
        self.id = UUID()
        self.assetLocalIdentifier = assetLocalIdentifier
        self.startTime = startTime
        self.endTime = endTime
        self.sortIndex = sortIndex
        self.speed = speed
        self.volume = volume
        self.assetDuration = assetDuration
        self.filename = filename
    }
}
