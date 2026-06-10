import Foundation
import AVFoundation
import SwiftUI
import SwiftData

/// Main ViewModel for the video editor screen.
/// Manages multi-track timeline, clips, playback, trimming, splitting, and joining.
@Observable
final class EditorViewModel {
    // MARK: - Project

    var project: Project
    var tracks: [Track] = []

    // MARK: - Playback

    var player: AVPlayer
    var isPlaying: Bool = false
    var currentTime: CMTime = .zero
    var totalDuration: CMTime = .zero
    private var timeObserver: Any?

    // MARK: - Selection

    var selectedClipID: UUID?
    var selectedTrackID: UUID?

    // MARK: - Multi-Camera

    var selectedCamera: Int = 0

    // MARK: - Timeline

    var timeScale: CGFloat = 100.0
    var playheadPosition: CGFloat = 0
    var isPlayheadDragging: Bool = false

    // MARK: - Trimming

    var trimmingClipID: UUID?
    var pendingTrimStart: Double?
    var pendingTrimEnd: Double?

    // MARK: - Undo

    private let undoManager = ProjectUndoManager()

    // MARK: - Engine

    private let composer = VideoComposer()

    // MARK: - Init

    init(project: Project) {
        self.project = project
        self.player = AVPlayer()

        let loadedTracks = project.tracks.filter { !$0.clips.isEmpty }
        self.tracks = loadedTracks.sorted { $0.orderIndex < $1.orderIndex }

        setupPlayer()
        setupTimeObserver()
    }

    deinit {
        removeTimeObserver()
    }

    // MARK: - Video Storage

    static var videosDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("ImportedVideos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func videoURL(for clip: Clip) -> URL {
        videosDirectory.appendingPathComponent(clip.assetLocalIdentifier)
    }

    // MARK: - Player Setup

    private func setupPlayer() {
        Task {
            guard let playerItem = await composer.buildPreviewItem(
                tracks: tracks,
                videoResolver: Self.videoURL(for:)
            ) else { return }
            player.replaceCurrentItem(with: playerItem)
            totalDuration = try await playerItem.asset.load(.duration)
        }
    }

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 1.0 / 60.0, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time
            if !self.isPlayheadDragging {
                self.playheadPosition = CGFloat(CMTimeGetSeconds(time)) * self.timeScale
            }
        }
    }

    private func removeTimeObserver() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    // MARK: - Playback Controls

    func togglePlay() {
        if isPlaying {
            player.pause()
        } else {
            if currentTime >= totalDuration && totalDuration.seconds > 0 {
                player.seek(to: .zero)
            }
            player.play()
        }
        isPlaying.toggle()
    }

    func seek(to time: CMTime) {
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
        playheadPosition = CGFloat(CMTimeGetSeconds(time)) * timeScale
    }

    func seekToPlayheadPosition(x: CGFloat) {
        let seconds = Double(x / timeScale)
        let clamped = max(0, min(seconds, totalDuration.seconds))
        let time = CMTime(seconds: clamped, preferredTimescale: 600)
        seek(to: time)
    }

    // MARK: - Track Management

    func addTrack(type: TrackType) {
        captureUndo()
        let videoCount = tracks.filter { $0.type == .video }.count
        let audioCount = tracks.filter { $0.type == .audio }.count
        let newIndex = type == .video ? videoCount : videoCount + audioCount
        let track = Track(type: type, orderIndex: newIndex)
        track.project = project
        project.tracks.append(track)
        refreshTracks()
    }

    func deleteTrack(_ trackID: UUID) {
        guard let track = tracks.first(where: { $0.id == trackID }) else { return }

        captureUndo()
        selectedClipID = nil
        project.tracks.removeAll { $0.id == trackID }
        refreshTracks()
    }

    func toggleMute(trackID: UUID) {
        captureUndo()
        guard let track = tracks.first(where: { $0.id == trackID }) else { return }
        track.isMuted.toggle()
        refreshPlayer()
    }

    // MARK: - Clip Selection

    func selectClip(_ id: UUID?) {
        selectedClipID = id
        trimmingClipID = nil
    }

    // MARK: - Undo / Redo

    @MainActor
    func captureUndo() {
        undoManager.captureState(tracks: tracks.map(TrackSnapshot.init))
    }

    @MainActor
    func undo() {
        guard let snapshot = undoManager.undo(current: tracks.map(TrackSnapshot.init)) else { return }
        restore(from: snapshot)
    }

    @MainActor
    func redo() {
        guard let snapshot = undoManager.redo(current: tracks.map(TrackSnapshot.init)) else { return }
        restore(from: snapshot)
    }

    var canUndo: Bool { undoManager.canUndo }
    var canRedo: Bool { undoManager.canRedo }

    private func restore(from snapshots: [TrackSnapshot]) {
        for trackSnapshot in snapshots {
            if let track = tracks.first(where: { $0.id == trackSnapshot.id }) {
                track.isMuted = trackSnapshot.isMuted

                // Restore clips in this track
                for clipSnapshot in trackSnapshot.clips {
                    if let clip = track.clips.first(where: { $0.id == clipSnapshot.id }) {
                        clip.startTime = clipSnapshot.startTime
                        clip.endTime = clipSnapshot.endTime
                        clip.sortIndex = clipSnapshot.sortIndex
                    }
                }

                // Remove clips that are no longer in the snapshot
                let snapshotIDs = Set(trackSnapshot.clips.map { $0.id })
                track.clips.removeAll { !snapshotIDs.contains($0.id) }

                // Add clips that are new in the snapshot
                for clipSnapshot in trackSnapshot.clips {
                    if !track.clips.contains(where: { $0.id == clipSnapshot.id }) {
                        let clip = Clip(
                            assetLocalIdentifier: clipSnapshot.assetLocalIdentifier,
                            startTime: clipSnapshot.startTime,
                            endTime: clipSnapshot.endTime,
                            sortIndex: clipSnapshot.sortIndex
                        )
                        clip.track = track
                        track.clips.append(clip)
                    }
                }
            }
        }
        refreshTracks()
    }

    // MARK: - Split

    func splitClip(at clipID: UUID, atTime time: CMTime) {
        guard let clip = allClips.first(where: { $0.id == clipID }),
              let track = clip.track
        else { return }

        let splitTimeSeconds = CMTimeGetSeconds(time)
        guard splitTimeSeconds > clip.startTime + 0.5,
              splitTimeSeconds < clip.endTime - 0.5 else { return }

        captureUndo()

        let originalEndTime = clip.endTime
        clip.endTime = splitTimeSeconds

        let newClip = Clip(
            assetLocalIdentifier: clip.assetLocalIdentifier,
            startTime: splitTimeSeconds,
            endTime: originalEndTime,
            sortIndex: clip.sortIndex + 1,
            assetDuration: clip.assetDuration
        )
        newClip.track = track

        // Increment sort indices for clips after the split point
        for c in track.clips where c.sortIndex > clip.sortIndex {
            c.sortIndex += 1
        }

        track.clips.append(newClip)
        refreshTracks()
    }

    // MARK: - Join (Merge adjacent clips from same asset)

    func joinClips(_ clipA: Clip, _ clipB: Clip) {
        guard let track = clipA.track,
              clipB.track?.id == track.id,
              clipA.assetLocalIdentifier == clipB.assetLocalIdentifier,
              abs(clipA.endTime - clipB.startTime) < 0.1
        else { return }

        captureUndo()

        clipA.endTime = clipB.endTime
        track.clips.removeAll { $0.id == clipB.id }

        // Reindex
        let sorted = track.clips.sorted { $0.sortIndex < $1.sortIndex }
        for (i, c) in sorted.enumerated() {
            c.sortIndex = i
        }
        refreshTracks()
    }

    /// Finds if two clips can be joined and returns the pair.
    func findJoinCandidate(for clipID: UUID) -> (Clip, Clip)? {
        guard let clip = allClips.first(where: { $0.id == clipID }),
              let track = clip.track
        else { return nil }

        let sorted = track.clips.sorted { $0.sortIndex < $1.sortIndex }
        guard let idx = sorted.firstIndex(where: { $0.id == clipID }) else { return nil }

        // Check previous clip
        if idx > 0 {
            let prev = sorted[idx - 1]
            if prev.assetLocalIdentifier == clip.assetLocalIdentifier,
               abs(prev.endTime - clip.startTime) < 0.1 {
                return (prev, clip)
            }
        }

        // Check next clip
        if idx < sorted.count - 1 {
            let next = sorted[idx + 1]
            if next.assetLocalIdentifier == clip.assetLocalIdentifier,
               abs(clip.endTime - next.startTime) < 0.1 {
                return (clip, next)
            }
        }

        return nil
    }

    // MARK: - Delete Clip

    func deleteClip(_ id: UUID) {
        guard let clip = allClips.first(where: { $0.id == id }),
              let track = clip.track
        else { return }

        captureUndo()

        let deletedSort = clip.sortIndex
        track.clips.removeAll { $0.id == id }
        for c in track.clips where c.sortIndex > deletedSort {
            c.sortIndex -= 1
        }

        if selectedClipID == id {
            selectedClipID = nil
        }
        refreshTracks()
    }

    // MARK: - Move Clip (Drag reorder within track or cross-track)

    func moveClip(_ clipID: UUID, toTrack targetTrackID: UUID, toIndex targetSortIndex: Int) {
        guard let clip = allClips.first(where: { $0.id == clipID }),
              let sourceTrack = clip.track,
              let targetTrack = tracks.first(where: { $0.id == targetTrackID })
        else { return }

        // Validate track types match
        guard sourceTrack.type == targetTrack.type else { return }

        captureUndo()

        if sourceTrack.id == targetTrack.id {
            // Same track reorder
            let oldSort = clip.sortIndex
            if oldSort < targetSortIndex {
                for c in sourceTrack.clips where c.sortIndex > oldSort && c.sortIndex <= targetSortIndex {
                    c.sortIndex -= 1
                }
            } else {
                for c in sourceTrack.clips where c.sortIndex >= targetSortIndex && c.sortIndex < oldSort {
                    c.sortIndex += 1
                }
            }
            clip.sortIndex = targetSortIndex
        } else {
            // Cross-track move
            let oldSort = clip.sortIndex
            sourceTrack.clips.removeAll { $0.id == clipID }
            for c in sourceTrack.clips where c.sortIndex > oldSort {
                c.sortIndex -= 1
            }

            clip.track = targetTrack
            for c in targetTrack.clips where c.sortIndex >= targetSortIndex {
                c.sortIndex += 1
            }
            clip.sortIndex = targetSortIndex
            targetTrack.clips.append(clip)
        }

        refreshTracks()

        // Check for join candidate after move
        if let (a, b) = findJoinCandidate(for: clipID) {
            withAnimation(.easeInOut(duration: 0.2)) {
                joinClips(a, b)
            }
        }
    }

    // MARK: - Trim

    func beginTrimming(clipID: UUID) {
        trimmingClipID = clipID
        guard let clip = allClips.first(where: { $0.id == clipID }) else { return }
        pendingTrimStart = clip.startTime
        pendingTrimEnd = clip.endTime
    }

    func updateTrimStart(_ newStart: Double) {
        guard let id = trimmingClipID, let clip = allClips.first(where: { $0.id == id }) else { return }
        let clamped = max(0, min(newStart, clip.endTime - 0.5))
        pendingTrimStart = clamped
        clip.startTime = clamped
        refreshPlayer()
    }

    func updateTrimEnd(_ newEnd: Double) {
        guard let id = trimmingClipID, let clip = allClips.first(where: { $0.id == id }) else { return }
        Task {
            let assetDuration: Double
            if let ad = clip.assetDuration {
                assetDuration = ad
            } else {
                assetDuration = await Self.durationForVideo(named: clip.assetLocalIdentifier)
            }
            let clamped = max(clip.startTime + 0.5, min(newEnd, assetDuration))
            await MainActor.run {
                pendingTrimEnd = clamped
                clip.endTime = clamped
                refreshPlayer()
            }
        }
    }

    func endTrimming() {
        if trimmingClipID != nil {
            captureUndo()
        }
        trimmingClipID = nil
        pendingTrimStart = nil
        pendingTrimEnd = nil
    }

    // MARK: - Add Clip

    func addClips(from urls: [URL]) {
        captureUndo()
        Task {
            for url in urls {
                await addClip(from: url)
            }
        }
    }

    private func addClip(from url: URL) async {
        let filename = "\(UUID().uuidString).mp4"
        let fileURL = Self.videosDirectory.appendingPathComponent(filename)

        do {
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }

            try FileManager.default.copyItem(at: url, to: fileURL)

            let asset = AVURLAsset(url: fileURL)
            let duration = try await asset.load(.duration).seconds
            guard duration > 0 else {
                try? FileManager.default.removeItem(at: fileURL)
                return
            }

            // Remove stale empty tracks, then auto-create if needed
            project.tracks.removeAll { $0.type == .video && $0.clips.isEmpty }
            let videoTrack: Track
            if let existing = project.tracks.first(where: { $0.type == .video }) {
                videoTrack = existing
            } else {
                videoTrack = Track(type: .video, orderIndex: 0)
                videoTrack.project = project
                project.tracks.append(videoTrack)
            }

            let nextSortIndex = (videoTrack.clips.max(by: { $0.sortIndex < $1.sortIndex })?.sortIndex ?? -1) + 1
            let clip = Clip(
                assetLocalIdentifier: filename,
                startTime: 0,
                endTime: duration,
                sortIndex: nextSortIndex,
                assetDuration: duration,
                filename: url.deletingPathExtension().lastPathComponent
            )
            clip.track = videoTrack

            await MainActor.run {
                videoTrack.clips.append(clip)
                refreshTracks()
            }
        } catch {
            print("[EditorVM] Failed to import video: \(error)")
        }
    }

    // MARK: - Internal

    /// All clips across all tracks, flattened.
    var allClips: [Clip] {
        tracks.flatMap { $0.clips }
    }

    private func refreshTracks() {
        let videoTracks = project.tracks.filter { $0.type == .video && !$0.clips.isEmpty }.sorted { $0.orderIndex < $1.orderIndex }
        let audioTracks = project.tracks.filter { $0.type == .audio && !$0.clips.isEmpty }.sorted { $0.orderIndex < $1.orderIndex }
        tracks = videoTracks + audioTracks
        for (i, track) in tracks.enumerated() {
            track.orderIndex = i
        }
        refreshPlayer()
    }

    private func refreshPlayer() {
        Task {
            guard let playerItem = await composer.buildPreviewItem(
                tracks: tracks,
                videoResolver: Self.videoURL(for:)
            ) else { return }

            let wasPlaying = isPlaying
            if wasPlaying { player.pause() }
            let currentSeconds = CMTimeGetSeconds(currentTime)
            player.replaceCurrentItem(with: playerItem)
            totalDuration = try await playerItem.asset.load(.duration)
            let newTime = CMTime(seconds: min(currentSeconds, totalDuration.seconds), preferredTimescale: 600)
            await player.seek(to: newTime)
            if wasPlaying { player.play() }
            isPlaying = wasPlaying
        }
    }

    private static func durationForVideo(named filename: String) async -> Double {
        let url = videosDirectory.appendingPathComponent(filename)
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return 0 }
        return duration.seconds
    }
}
