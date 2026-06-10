import SwiftUI

/// Multi-track timeline view showing all tracks (video + audio) with clips.
/// Supports instant drag, cross-track movement, and smooth animations.
struct TimelineView: View {
    let tracks: [Track]
    @Binding var selectedClipID: UUID?
    let timeScale: CGFloat
    let playheadPosition: CGFloat
    let totalDuration: Double

    let onSelect: (UUID?) -> Void
    let onMoveClip: (UUID, UUID, Int) -> Void  // (clipID, targetTrackID, targetSortIndex)
    let onTrimStart: (UUID, Double) -> Void
    let onTrimEnd: (UUID, Double) -> Void
    let onTrimBegin: (UUID) -> Void
    let onTrimEndAction: () -> Void
    let onAddTrack: (TrackType) -> Void
    let onDeleteTrack: (UUID) -> Void
    let onToggleMute: (UUID) -> Void
    let onSeek: (CGFloat) -> Void
    let onPlayheadDragBegin: () -> Void
    let onPlayheadDragEnd: () -> Void

    @State private var isShowingAddTrackMenu = false
    @State private var playheadDragStartX: CGFloat = 0
    @State private var isDraggingPlayhead = false

    private var totalWidth: CGFloat {
        max(CGFloat(totalDuration) * timeScale + 32, 200)
    }

    private var timelineHeight: CGFloat {
        CGFloat(tracks.count) * (trackHeight + trackSpacing) + trackSpacing
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 0) {
                // Fixed track headers column
                VStack(spacing: trackSpacing) {
                    ForEach(tracks, id: \.id) { track in
                        TrackHeaderView(
                            track: track,
                            onDelete: { onDeleteTrack(track.id) },
                            onAddClip: {}
                        )
                    }

                    // Add track button
                    addTrackButton
                }
                .frame(width: 130)

                Divider()

                // Scrollable track content
                VStack(spacing: trackSpacing) {
                    ForEach(tracks, id: \.id) { track in
                        TrackRowView(
                            track: track,
                            timeScale: timeScale,
                            selectedClipID: selectedClipID,
                            playheadPosition: playheadPosition,
                            totalDuration: totalDuration,
                            onSelectClip: onSelect,
                            onMoveClip: { clipID, targetTrackID, targetIndex in
                                onMoveClip(clipID, targetTrackID, targetIndex)
                            },
                            onTrimStart: onTrimStart,
                            onTrimEnd: onTrimEnd,
                            onTrimBegin: onTrimBegin,
                            onTrimEndAction: onTrimEndAction,
                            onDeleteTrack: { self.onDeleteTrack(track.id) },
                            onAddClip: {}
                        )
                        .frame(width: totalWidth, alignment: .topLeading)
                    }

                    // Empty space for add track button alignment
                    Color.clear
                        .frame(height: 36)
                }
                .simultaneousGesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            onSeek(value.location.x)
                        }
                )
            }
            .overlay(alignment: .top) {
                sharedPlayhead
                    .allowsHitTesting(true)
            }
        }
        .frame(maxHeight: timelineHeight + 40)
    }

    // MARK: - Shared Playhead

    private var sharedPlayhead: some View {
        PlayheadView(
            position: playheadPosition,
            height: timelineHeight + 40,
            onDrag: { deltaX in
                if !isDraggingPlayhead {
                    isDraggingPlayhead = true
                    playheadDragStartX = playheadPosition
                    onPlayheadDragBegin()
                }
                let newX = max(0, playheadDragStartX + deltaX)
                onSeek(newX)
            },
            onDragEnd: {
                isDraggingPlayhead = false
                onPlayheadDragEnd()
            }
        )
    }

    // MARK: - Add Track Button

    private var addTrackButton: some View {
        Menu {
            Button(action: { onAddTrack(.video) }) {
                Label("添加视频轨道", systemImage: "video.fill")
            }
            Button(action: { onAddTrack(.audio) }) {
                Label("添加音频轨道", systemImage: "music.note")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle")
                    .font(.caption)
                Text("新轨道")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .menuStyle(.borderlessButton)
        .padding(.horizontal, 8)
    }
}
