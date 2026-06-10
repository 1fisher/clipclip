import SwiftUI
import AVKit

/// Preview player panel with playback controls.
struct PreviewPlayerView: View {
    let editorVM: EditorViewModel

    var body: some View {
        VStack(spacing: 8) {
            // Player
            ZStack {
                SilentPlayerView(player: editorVM.player)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )

                // Tap to play/pause overlay
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editorVM.togglePlay()
                    }

                // Centered play button when paused
                if !editorVM.isPlaying {
                    Image(systemName: "play.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                        .shadow(radius: 4)
                }
            }

            // Playback Controls
            HStack(spacing: 12) {
                // Current time
                Text(editorVM.currentTime.formatted)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .leading)

                // Seek bar
                SeekBar(
                    value: Binding(
                        get: { CGFloat(CMTimeGetSeconds(editorVM.currentTime)) },
                        set: { editorVM.seekToPlayheadPosition(x: $0) }
                    ),
                    range: 0...CGFloat(max(editorVM.totalDuration.seconds, 1)),
                    onEditingChanged: { editing in
                        if editing {
                            if editorVM.isPlaying { editorVM.togglePlay() }
                        }
                    }
                )

                // Total duration
                Text(editorVM.totalDuration.formatted)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }
        }
    }
}

// MARK: - Custom Seek Bar

struct SeekBar: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let onEditingChanged: (Bool) -> Void

    var body: some View {
        GeometryReader { geometry in
            let trackHeight: CGFloat = 4
            let thumbSize: CGFloat = 14
            let progress = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let thumbX = progress * (geometry.size.width - thumbSize)

            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: trackHeight)

                // Progress fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: max(0, thumbX + thumbSize / 2), height: trackHeight)

                // Thumb
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: thumbX)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                onEditingChanged(true)
                                let newX = min(max(0, gesture.location.x), geometry.size.width - thumbSize)
                                let ratio = newX / (geometry.size.width - thumbSize)
                                value = range.lowerBound + ratio * (range.upperBound - range.lowerBound)
                            }
                            .onEnded { _ in
                                onEditingChanged(false)
                            }
                    )
            }
            .frame(height: thumbSize)
        }
        .frame(height: 20)
    }
}
