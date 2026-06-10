import Foundation
import AVFoundation

/// Builds AVMutableComposition from an ordered list of Tracks.
/// Each track contains clips placed sequentially within that track.
/// Multiple video tracks are composed onto a single video composition track
/// if they don't overlap, or layered if they do (lower-order track wins).
final class VideoComposer {

    typealias VideoResolver = (Clip) -> URL

    /// Builds an AVPlayerItem to preview the current edit.
    /// - Parameters:
    ///   - tracks: Tracks (sorted by orderIndex) to compose.
    ///   - videoResolver: Closure that returns the file URL for a given clip.
    /// - Returns: AVPlayerItem ready for playback, or nil if no clips exist.
    func buildPreviewItem(tracks: [Track], videoResolver: @escaping VideoResolver) async -> AVPlayerItem? {
        guard let asset = await buildComposition(tracks: tracks, videoResolver: videoResolver) else { return nil }
        return AVPlayerItem(asset: asset)
    }

    /// Builds an AVAsset (composition) for playback or export.
    /// - Parameters:
    ///   - tracks: Tracks to compose, sorted by orderIndex.
    ///   - videoResolver: Closure that returns the file URL for a given clip.
    /// - Returns: An AVMutableComposition.
    func buildComposition(tracks: [Track], videoResolver: @escaping VideoResolver) async -> AVMutableComposition? {
        let sortedTracks = tracks.sorted { $0.orderIndex < $1.orderIndex }
        let allClips = sortedTracks.flatMap { $0.clips }
        guard !allClips.isEmpty else { return nil }

        let composition = AVMutableComposition()

        guard let compVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { return nil }

        let compAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var hasSetTransform = false

        for track in sortedTracks {
            let sortedClips = track.clips.sorted { $0.sortIndex < $1.sortIndex }
            var currentTime = CMTime.zero

            for clip in sortedClips {
                let url = videoResolver(clip)
                let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
                let timeRange = CMTimeRange(start: clip.startCMTime, duration: clip.durationCMTime)

                do {
                    // Insert video
                    if track.type == .video {
                        if let assetVideoTrack = try await asset.loadTracks(withMediaType: .video).first {
                            try compVideoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: currentTime)
                            if !hasSetTransform {
                                let transform = try await assetVideoTrack.load(.preferredTransform)
                                compVideoTrack.preferredTransform = transform
                                hasSetTransform = true
                            }
                        }
                    }

                    // Insert audio (if track is not muted)
                    if !track.isMuted,
                       let compAudioTrack = compAudioTrack,
                       let assetAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                        try compAudioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: currentTime)
                    }
                } catch {
                    print("[VideoComposer] Insert failed at \(currentTime.seconds): \(error)")
                    continue
                }

                currentTime = CMTimeAdd(currentTime, clip.durationCMTime)
            }
        }

        return composition
    }

    /// Legacy support: build from flat clips list (single virtual track).
    func buildPreviewItem(clips: [Clip], videoResolver: @escaping VideoResolver) async -> AVPlayerItem? {
        guard let asset = await buildComposition(clips: clips, videoResolver: videoResolver) else { return nil }
        return AVPlayerItem(asset: asset)
    }

    func buildComposition(clips: [Clip], videoResolver: @escaping VideoResolver) async -> AVMutableComposition? {
        let sortedClips = clips.sorted { $0.sortIndex < $1.sortIndex }
        guard !sortedClips.isEmpty else { return nil }

        let composition = AVMutableComposition()

        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { return nil }

        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var currentTime = CMTime.zero
        var hasSetTransform = false

        for clip in sortedClips {
            let url = videoResolver(clip)
            let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
            let timeRange = CMTimeRange(start: clip.startCMTime, duration: clip.durationCMTime)

            do {
                if let assetVideoTrack = try await asset.loadTracks(withMediaType: .video).first {
                    try videoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: currentTime)
                    if !hasSetTransform {
                        let transform = try await assetVideoTrack.load(.preferredTransform)
                        videoTrack.preferredTransform = transform
                        hasSetTransform = true
                    }
                }
                if let assetAudioTrack = try await asset.loadTracks(withMediaType: .audio).first,
                   let audioTrack = audioTrack {
                    try audioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: currentTime)
                }
            } catch {
                print("[VideoComposer] Insert failed at \(currentTime.seconds): \(error)")
                continue
            }

            currentTime = CMTimeAdd(currentTime, clip.durationCMTime)
        }

        return composition
    }
}
