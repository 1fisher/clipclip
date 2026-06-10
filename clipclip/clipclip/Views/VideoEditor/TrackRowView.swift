import SwiftUI

/// A single track row in the timeline: track header on the left, clips container on the right.
struct TrackRowView: View {
    @Bindable var track: Track
    let timeScale: CGFloat
    let selectedClipID: UUID?
    let playheadPosition: CGFloat
    let totalDuration: Double

    let onSelectClip: (UUID?) -> Void
    let onMoveClip: (UUID, UUID, Int) -> Void  // (clipID, targetTrackID, targetSortIndex)
    let onMoveToNewTrack: (UUID, TrackType, Int) -> Void  // (clipID, trackType, targetSortIndex)
    let onTrimStart: (UUID, Double) -> Void
    let onTrimEnd: (UUID, Double) -> Void
    let onTrimBegin: (UUID) -> Void
    let onTrimEndAction: () -> Void

    @State private var draggingClipID: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var dragTargetTrackID: UUID?
    @State private var dragTargetIsNewTrack = false
    @State private var isDragActive = false

    private var sortedClips: [Clip] {
        track.clips.sorted { $0.sortIndex < $1.sortIndex }
    }

    private var totalWidth: CGFloat {
        max(CGFloat(totalDuration) * timeScale + 32, 200)
    }

    private var trackColor: Color {
        track.type == .video ? Color.accentColor : Color.green
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(track.isMuted
                        ? trackColor.opacity(0.03)
                        : trackColor.opacity(0.06))
                    .frame(height: trackHeight - 4)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)

                if track.isMuted {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.red.opacity(0.15), lineWidth: 1)
                        .frame(height: trackHeight - 4)
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                }
                ForEach(Array(sortedClips.enumerated()), id: \.element.id) { index, clip in
                    TimelineClipView(
                        clip: clip,
                        timeScale: timeScale,
                        isSelected: selectedClipID == clip.id,
                        trackType: track.type,
                        isMuted: track.isMuted,
                        onTap: { onSelectClip(clip.id) },
                        onTrimStart: { offsetX in
                            let newStart = clip.startTime + Double(-offsetX / timeScale)
                            onTrimStart(clip.id, newStart)
                        },
                        onTrimEnd: { offsetX in
                            let newEnd = clip.endTime + Double(offsetX / timeScale)
                            onTrimEnd(clip.id, newEnd)
                        },
                        onTrimBegin: { onTrimBegin(clip.id) },
                        onTrimEndAction: { onTrimEndAction() }
                    )
                    .offset(
                        x: clipXOffset(for: index) + (draggingClipID == clip.id ? dragOffset.width : 0),
                        y: 8
                    )
                    .zIndex(draggingClipID == clip.id ? 100 : 1)
                    .gesture(instantDragGesture(for: clip, at: index))
                }

                // Drop indicator when dragging over this track
                if isDragActive, let dragID = draggingClipID, dragTargetTrackID == track.id {
                    if let insertX = computeDropInsertX() {
                        Rectangle()
                            .fill(trackColor.opacity(0.5))
                            .frame(width: 3, height: trackHeight - 12)
                            .cornerRadius(1.5)
                            .offset(x: insertX, y: 10)
                    }
                }
            }
        .frame(height: trackHeight + trackSpacing)
    }

    // MARK: - Instant Drag Gesture (no long press)

    private func instantDragGesture(for clip: Clip, at index: Int) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if draggingClipID == nil {
                    draggingClipID = clip.id
                    dragOffset = .zero
                    isDragActive = true
                    onSelectClip(clip.id)
                }

                if draggingClipID == clip.id {
                    dragOffset = value.translation

                    let verticalOffset = value.translation.height
                    if abs(verticalOffset) > trackHeight * 0.6 {
                        let direction = verticalOffset > 0 ? 1 : -1
                        if let target = findRelativeTrack(offset: direction) {
                            dragTargetTrackID = target.id
                            dragTargetIsNewTrack = false
                        } else {
                            dragTargetTrackID = nil
                            dragTargetIsNewTrack = true
                        }
                    } else {
                        dragTargetTrackID = nil
                        dragTargetIsNewTrack = false
                    }
                }
            }
            .onEnded { value in
                defer {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        draggingClipID = nil
                        dragOffset = .zero
                        isDragActive = false
                        dragTargetTrackID = nil
                        dragTargetIsNewTrack = false
                    }
                }

                guard let dragID = draggingClipID else { return }
                let draggedClip = clip

                let dragX = clipXOffset(for: index) + value.translation.width
                let targetSortIndex = computeTargetSortIndex(at: dragX, excluding: dragID)
                let targetTrackID = dragTargetTrackID ?? track.id

                if dragTargetIsNewTrack {
                    onMoveToNewTrack(dragID, track.type, targetSortIndex)
                } else if targetTrackID != track.id || targetSortIndex != index {
                    onMoveClip(dragID, targetTrackID, targetSortIndex)
                }
            }
    }

    // MARK: - Position Helpers

    private func clipXOffset(for index: Int) -> CGFloat {
        let clips = sortedClips
        var x: CGFloat = 8
        for i in 0..<index {
            x += CGFloat(clips[i].duration) * timeScale + 4
        }
        return x
    }

    private func computeTargetSortIndex(at dragX: CGFloat, excluding clipID: UUID) -> Int {
        let clips = sortedClips
        var currentX: CGFloat = 8
        for (i, clip) in clips.enumerated() {
            if clip.id == clipID { continue }
            let clipCenter = currentX + CGFloat(clip.duration) * timeScale / 2
            if dragX < clipCenter {
                return i
            }
            currentX += CGFloat(clip.duration) * timeScale + 4
        }
        return max(0, clips.count - 1)
    }

    private func findRelativeTrack(offset: Int) -> Track? {
        guard let project = track.project else { return nil }
        let sortedTracks = project.tracks.sorted { $0.orderIndex < $1.orderIndex }
        guard let currentIndex = sortedTracks.firstIndex(where: { $0.id == track.id }) else { return nil }
        let targetIndex = currentIndex + offset
        guard targetIndex >= 0, targetIndex < sortedTracks.count else { return nil }
        return sortedTracks[targetIndex]
    }

    private func computeDropInsertX() -> CGFloat? {
        guard let dragID = draggingClipID, dragTargetTrackID == track.id else { return nil }
        let clips = sortedClips
        var x: CGFloat = 8
        for clip in clips {
            if clip.id == dragID { continue }
            let center = x + CGFloat(clip.duration) * timeScale / 2
            if dragOffset.width < center - x {
                return x
            }
            x += CGFloat(clip.duration) * timeScale + 4
        }
        return x
    }
}
