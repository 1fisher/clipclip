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
    let onMoveToNewTrack: (UUID, TrackType, Int) -> Void  // (clipID, trackType, targetSortIndex)
    let onUpdateClipOffset: (UUID, CGFloat) -> Void
    let onTrimStart: (UUID, Double) -> Void
    let onTrimEnd: (UUID, Double) -> Void
    let onTrimBegin: (UUID) -> Void
    let onTrimEndAction: () -> Void

    private var totalWidth: CGFloat {
        max(CGFloat(totalDuration) * timeScale + 32, 200)
    }

    private var timelineHeight: CGFloat {
        CGFloat(tracks.count) * (trackHeight + trackSpacing) + trackSpacing
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 0) {
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
                            onMoveToNewTrack: { clipID, trackType, targetIndex in
                                onMoveToNewTrack(clipID, trackType, targetIndex)
                            },
                            onTrimStart: onTrimStart,
                            onTrimEnd: onTrimEnd,
                            onTrimBegin: onTrimBegin,
                            onTrimEndAction: onTrimEndAction,
                            onUpdateClipOffset: { clipID, offsetX in
                                onUpdateClipOffset(clipID, offsetX)
                            }
                        )
                        .frame(width: totalWidth, alignment: .topLeading)
                    }

                    // Bottom padding
                    Color.clear
                        .frame(height: 8)
                }
            }
        }
        .frame(maxHeight: timelineHeight + 40)
    }

}
