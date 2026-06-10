import Foundation
import AVFoundation
import CoreMedia

extension CMTime {
    /// Formats the time as a human-readable string (MM:SS or HH:MM:SS).
    var formatted: String {
        let totalSeconds = CMTimeGetSeconds(self)
        guard !totalSeconds.isNaN, !totalSeconds.isInfinite else { return "00:00" }

        let hours = Int(totalSeconds / 3600)
        let minutes = Int((totalSeconds.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = Int(totalSeconds.truncatingRemainder(dividingBy: 60))

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// Rounded to the nearest whole second.
    var roundedToSeconds: CMTime {
        let seconds = CMTimeGetSeconds(self).rounded()
        return CMTime(seconds: seconds, preferredTimescale: 1)
    }
}

extension CMTimeRange {
    var formatted: String {
        "\(start.formatted) – \(end.formatted)"
    }
}

extension Double {
    /// Formats a duration in seconds to MM:SS or HH:MM:SS.
    var formattedDuration: String {
        guard !isNaN, !isInfinite else { return "00:00" }
        let hours = Int(self / 3600)
        let minutes = Int((self.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = Int(self.truncatingRemainder(dividingBy: 60))
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
