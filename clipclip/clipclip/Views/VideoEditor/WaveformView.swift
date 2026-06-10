import SwiftUI

/// Renders a real audio waveform from amplitude data.
/// Supports smooth curves, gradient fills, and selection highlighting.
struct WaveformView: View {
    let waveformData: [Float]
    let trackColor: Color
    let isSelected: Bool
    let isMuted: Bool
    let clipWidth: CGFloat

    @State private var animating: Bool = false

    private var waveformColor: Color {
        if isMuted { return trackColor.opacity(0.2) }
        return isSelected ? trackColor : trackColor.opacity(0.6)
    }

    var body: some View {
        if waveformData.isEmpty {
            // Placeholder while loading
            waveformPlaceholder
        } else {
            waveformCanvas
        }
    }

    private var waveformPlaceholder: some View {
        HStack(spacing: 2) {
            ForEach(0..<min(Int(clipWidth / 12), 30), id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1)
                    .fill(waveformColor.opacity(0.3))
                    .frame(width: 2, height: 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var waveformCanvas: some View {
        Canvas { context, size in
            let barCount = max(2, min(waveformData.count, Int(size.width / 3)))
            let step = max(1, waveformData.count / barCount)
            let barWidth = size.width / CGFloat(barCount)
            let midY = size.height / 2
            let maxHeight = size.height * 0.8

            for i in 0..<barCount {
                let dataIndex = min(i * step, waveformData.count - 1)
                let amplitude = CGFloat(waveformData[dataIndex])
                let barHeight = amplitude * maxHeight

                let x = CGFloat(i) * barWidth + barWidth * 0.1
                let w = barWidth * 0.8

                let rect = CGRect(
                    x: x,
                    y: midY - barHeight / 2,
                    width: w,
                    height: barHeight
                )

                let path = Path(roundedRect: rect, cornerRadius: w / 2)
                context.fill(path, with: .color(waveformColor))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .drawingGroup()
    }
}
