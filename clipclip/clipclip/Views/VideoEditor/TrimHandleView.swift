import SwiftUI

/// A drag handle for trimming the start or end of a clip on the timeline.
struct TrimHandleView: View {
    let side: Edge  // .leading for start trim, .trailing for end trim
    let onDrag: (CGFloat) -> Void
    let onDragEnd: () -> Void

    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.9))
            .frame(width: 16)
            .overlay(
                ZStack {
                    // Vertical grip lines
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.black.opacity(0.4))
                            .frame(width: 2, height: 16)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.black.opacity(0.4))
                            .frame(width: 2, height: 16)
                    }
                }
            )
            .clipShape(
                RoundedCorners(
                    topLeft: side == .leading ? 4 : 0,
                    bottomLeft: side == .leading ? 4 : 0,
                    topRight: side == .trailing ? 4 : 0,
                    bottomRight: side == .trailing ? 4 : 0
                )
            )
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        onDrag(gesture.location.x)
                    }
                    .onEnded { _ in
                        onDragEnd()
                    }
            )
    }
}

/// Shape for selective corner rounding.
struct RoundedCorners: Shape {
    var topLeft: CGFloat = 0
    var bottomLeft: CGFloat = 0
    var topRight: CGFloat = 0
    var bottomRight: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w - topRight, y: 0))
        path.addLine(to: CGPoint(x: topLeft, y: 0))
        path.addQuadCurve(to: CGPoint(x: 0, y: topLeft), control: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: h - bottomLeft))
        path.addQuadCurve(to: CGPoint(x: bottomLeft, y: h), control: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: w - bottomRight, y: h))
        path.addQuadCurve(to: CGPoint(x: w, y: h - bottomRight), control: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: w, y: topRight))
        path.addQuadCurve(to: CGPoint(x: w - topRight, y: 0), control: CGPoint(x: w, y: 0))

        return path
    }
}
