import Foundation
import AVFoundation
import AppKit

/// Generates thumbnail images for timeline clip representation using file-based video URLs.
final class ThumbnailGenerator {

    typealias VideoResolver = VideoComposer.VideoResolver

    /// Generates an array of thumbnail images evenly spaced across a clip's time range.
    /// - Parameters:
    ///   - clip: The clip to generate thumbnails for.
    ///   - videoResolver: Closure to resolve the video file URL for the clip.
    ///   - count: Number of thumbnails to generate.
    ///   - size: Target size for each thumbnail.
    /// - Returns: Array of thumbnail images, or empty if generation fails.
    func generateThumbnails(
        for clip: Clip,
        videoResolver: VideoResolver,
        count: Int = 8,
        size: CGSize = CGSize(width: 60, height: 45)
    ) async -> [NSImage] {
        let url = videoResolver(clip)
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = size

        let clipDuration = clip.duration
        guard clipDuration > 0, count > 0 else { return [] }

        let interval = clipDuration / Double(count)
        let times: [NSValue] = (0..<count).map { i in
            let time = CMTime(seconds: clip.startTime + interval * Double(i), preferredTimescale: 600)
            return NSValue(time: time)
        }

        var images: [NSImage] = []

        for timeValue in times {
            let cmTime = timeValue.timeValue
            do {
                let (cgImage, _) = try await generator.image(at: cmTime)
                images.append(NSImage(cgImage: cgImage, size: size))
            } catch {
                print("[ThumbnailGenerator] Failed at \(cmTime.seconds): \(error)")
            }
        }

        return images
    }

    /// Generates a single thumbnail at a specific time in the clip.
    func generateThumbnail(
        at time: Double,
        for clip: Clip,
        videoResolver: VideoResolver,
        size: CGSize = CGSize(width: 120, height: 90)
    ) async -> NSImage? {
        let url = videoResolver(clip)
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = size

        let absoluteTime = clip.startTime + time
        let cmTime = CMTime(seconds: absoluteTime, preferredTimescale: 600)

        do {
            let (cgImage, _) = try await generator.image(at: cmTime)
            return NSImage(cgImage: cgImage, size: size)
        } catch {
            print("[ThumbnailGenerator] Failed: \(error)")
            return nil
        }
    }
}
