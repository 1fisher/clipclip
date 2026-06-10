import SwiftUI

/// The red playhead line shown on the timeline.
struct PlayheadView: View {
    let position: CGFloat
    let height: CGFloat
    let onDrag: (CGFloat) -> Void
    let onDragEnd: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            // Vertical line
            Rectangle()
                .fill(Color.red)
                .frame(width: 2)
                .frame(maxHeight: .infinity)

            // Drag handle at the top
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
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    onDrag(gesture.translation.width)
                }
                .onEnded { _ in
                    onDragEnd()
                }
        )
    }
}
