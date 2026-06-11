import SwiftUI

/// The red playhead line shown on the timeline.
struct PlayheadView: View {
    let position: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color.red)
                .frame(width: 2)
                .frame(maxHeight: .infinity)

            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
        }
        .frame(width: 12)
        .position(x: position, y: height / 2)
    }
}

/// Playhead overlay that handles drag with correct position tracking.
struct PlayheadDragOverlay: View {
    let playheadPosition: CGFloat
    let trackCount: Int
    let onSeek: (CGFloat) -> Void

    @State private var dragStartX: CGFloat = 0
    @State private var isDragging = false

    private var totalHeight: CGFloat {
        let trackArea = CGFloat(trackCount) * (trackHeight + trackSpacing) + trackSpacing
        let extraSpace = 2 * (trackHeight + trackSpacing)
        return max(trackArea + extraSpace, 3 * (trackHeight + trackSpacing))
    }

    var body: some View {
        PlayheadView(position: playheadPosition, height: totalHeight)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            dragStartX = playheadPosition
                        }
                        let newX = max(0, dragStartX + gesture.translation.width)
                        onSeek(newX)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
    }
}
