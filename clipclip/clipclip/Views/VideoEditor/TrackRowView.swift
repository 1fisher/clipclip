import SwiftUI

struct TrackRowView: View {
    @Bindable var track: Track
    let timeScale: CGFloat
    let selectedClipID: UUID?
    let playheadPosition: CGFloat
    let totalDuration: Double

    let onSelectClip: (UUID?) -> Void
    let onMoveClip: (UUID, UUID, Int) -> Void
    let onMoveToNewTrack: (UUID, TrackType, Int) -> Void
    let onTrimStart: (UUID, Double) -> Void
    let onTrimEnd: (UUID, Double) -> Void
    let onTrimBegin: (UUID) -> Void
    let onTrimEndAction: () -> Void
    let onUpdateClipOffset: (UUID, CGFloat) -> Void

    @State private var draggingClipID: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var dragTargetTrackID: UUID?
    @State private var dragTargetIsNewTrack = false
    @State private var isDragActive = false

    private var sortedClips: [Clip] {
        track.clips.sorted { $0.timelineOffset < $1.timelineOffset }
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
                    x: CGFloat(clip.timelineOffset) + (draggingClipID == clip.id ? dragOffset.width : 0),
                    y: 8 + (draggingClipID == clip.id ? dragOffset.height : 0)
                )
                .zIndex(draggingClipID == clip.id ? 100 : 1)
                .gesture(instantDragGesture(for: clip))
            }

            if isDragActive, let dragID = draggingClipID, dragTargetTrackID == track.id {
                if let insertX = computeSnapX() {
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

    // MARK: - Drag Gesture

    private func instantDragGesture(for clip: Clip) -> some Gesture {
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
                    let trackStep = trackHeight + trackSpacing

                    if abs(verticalOffset) > trackStep / 2 {
                        let direction = verticalOffset > 0 ? 1 : -1
                        if let target = findRelativeTrack(offset: direction) {
                            dragTargetTrackID = target.id
                            dragTargetIsNewTrack = false
                        } else {
                            dragTargetTrackID = nil
                            dragTargetIsNewTrack = true
                        }
                    } else {
                        dragTargetTrackID = track.id
                        dragTargetIsNewTrack = false
                    }
                }
            }
            .onEnded { value in
                guard let dragID = draggingClipID else {
                    resetDragState()
                    return
                }

                let finalX = CGFloat(currentOffset(for: dragID)) + value.translation.width

                if dragTargetIsNewTrack {
                    onMoveToNewTrack(dragID, track.type, 0)
                } else if let snapX = computeSnapTargetX(for: dragID, dragX: finalX) {
                    let targetTrackID = dragTargetTrackID ?? track.id
                    if targetTrackID != track.id {
                        let sortIdx = sortIndexAtX(snapX, excluding: dragID)
                        onMoveClip(dragID, targetTrackID, sortIdx)
                    } else {
                        onUpdateClipOffset(dragID, snapX)
                    }
                } else {
                    let clampedX = max(8, finalX)
                    if dragTargetTrackID == track.id || dragTargetTrackID == nil {
                        onUpdateClipOffset(dragID, clampedX)
                    } else {
                        let targetTrackID = dragTargetTrackID ?? track.id
                        let sortIdx = sortIndexAtX(clampedX, excluding: dragID)
                        onMoveClip(dragID, targetTrackID, sortIdx)
                    }
                }

                resetDragState()
            }
    }

    private func resetDragState() {
        draggingClipID = nil
        dragOffset = .zero
        isDragActive = false
        dragTargetTrackID = nil
        dragTargetIsNewTrack = false
    }

    // MARK: - Position Helpers

    private func currentOffset(for clipID: UUID) -> CGFloat {
        guard let clip = sortedClips.first(where: { $0.id == clipID }) else { return 8 }
        return CGFloat(clip.timelineOffset)
    }

    private func computeSnapTargetX(for clipID: UUID, dragX: CGFloat) -> CGFloat? {
        let snapThreshold: CGFloat = 10
        for clip in sortedClips {
            if clip.id == clipID { continue }
            let leftEdge = CGFloat(clip.timelineOffset)
            let clipWidth = CGFloat(clip.duration) * timeScale
            let rightEdge = leftEdge + clipWidth

            if abs(dragX - leftEdge) < snapThreshold {
                return leftEdge
            }
            if abs(dragX - rightEdge) < snapThreshold {
                return rightEdge
            }
        }
        return nil
    }

    private func sortIndexAtX(_ x: CGFloat, excluding clipID: UUID) -> Int {
        var idx = 0
        for clip in sortedClips {
            if clip.id == clipID { continue }
            if x < CGFloat(clip.timelineOffset) { return idx }
            idx += 1
        }
        return idx
    }

    private func computeSnapX() -> CGFloat? {
        guard let dragID = draggingClipID else { return nil }
        let dragX = currentOffset(for: dragID) + dragOffset.width
        return computeSnapTargetX(for: dragID, dragX: dragX)
    }

    private func findRelativeTrack(offset: Int) -> Track? {
        guard let project = track.project else { return nil }
        let sortedTracks = project.tracks.sorted { $0.orderIndex < $1.orderIndex }
        guard let currentIndex = sortedTracks.firstIndex(where: { $0.id == track.id }) else { return nil }
        let targetIndex = currentIndex + offset
        guard targetIndex >= 0, targetIndex < sortedTracks.count else { return nil }
        return sortedTracks[targetIndex]
    }
}
