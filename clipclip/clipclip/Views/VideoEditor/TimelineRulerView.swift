import SwiftUI

/// A time scale ruler displayed above the timeline showing time markers.
struct TimelineRulerView: View {
    let totalDuration: Double
    let timeScale: CGFloat

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                // Tick marks
                Canvas { context, size in
                    _ = totalDuration * timeScale
                    let majorInterval = max(1, round(50 / timeScale)) // every ~50px
                    let minorInterval = majorInterval / 5

                    var second: Double = 0
                    while second <= totalDuration {
                        let x = second * timeScale
                        let isMajor = second.truncatingRemainder(dividingBy: majorInterval) == 0

                        if isMajor {
                            // Major tick
                            var path = Path()
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: 12))
                            context.stroke(path, with: .color(.primary.opacity(0.6)), lineWidth: 1)

                            // Time label
                            let timeStr = formatTime(second)
                            let text = Text(timeStr)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            let resolved = context.resolve(text)
                            context.draw(resolved, at: CGPoint(x: x + 4, y: 14))
                        } else {
                            // Minor tick
                            var path = Path()
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: 6))
                            context.stroke(path, with: .color(.primary.opacity(0.3)), lineWidth: 1)
                        }

                        second += minorInterval
                    }
                }
                .frame(width: max(CGFloat(totalDuration) * timeScale, 1), height: 28)
            }
        }
        .frame(height: 28)
        .padding(.horizontal, 8)
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        let m = s / 60
        let sec = s % 60
        return String(format: "%d:%02d", m, sec)
    }
}
