import SwiftUI
import AVFoundation
import AppKit

/// A single clip displayed on the timeline with thumbnail strip (video) or waveform (audio),
/// trim handles, and instant drag visual feedback.
struct TimelineClipView: View {
    let clip: Clip
    let timeScale: CGFloat
    let isSelected: Bool
    let trackType: TrackType
    let isMuted: Bool

    let onTap: () -> Void
    let onTrimStart: (CGFloat) -> Void
    let onTrimEnd: (CGFloat) -> Void
    let onTrimBegin: () -> Void
    let onTrimEndAction: () -> Void

    @State private var waveformData: [Float] = []
    @State private var thumbnails: [NSImage] = []
    @State private var isHovering = false

    private var clipWidth: CGFloat {
        CGFloat(clip.duration) * timeScale
    }

    private var trackColor: Color {
        trackType == .video ? Color.accentColor : Color.green
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Background
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
                )

            // Content: video thumbnails or audio waveform
            if trackType == .video {
                videoThumbnailContent
            } else {
                audioWaveformContent
            }

            // Duration label
            durationLabel

            // Join hint when near a joinable clip
            if isSelected {
                joinHintBadge
            }
        }
        .frame(width: max(clipWidth, 24), height: trackHeight - 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .overlay(alignment: .leading) {
            if isSelected {
                TrimHandleView(side: .leading, onDrag: { offset in
                    onTrimBegin()
                }, onDragEnd: {
                    onTrimEndAction()
                })
                .offset(x: -8)
            }
        }
        .overlay(alignment: .trailing) {
            if isSelected {
                TrimHandleView(side: .trailing, onDrag: { offset in
                    onTrimBegin()
                }, onDragEnd: {
                    onTrimEndAction()
                })
                .offset(x: 8)
            }
        }
        .onAppear {
            loadWaveformIfNeeded()
            loadThumbnailsIfNeeded()
        }
    }

    // MARK: - Background Colors

    private var backgroundColor: Color {
        if isMuted {
            return Color.secondary.opacity(0.05)
        }
        if isSelected {
            return trackColor.opacity(0.25)
        }
        return Color.secondary.opacity(trackType == .video ? 0.15 : 0.1)
    }

    private var borderColor: Color {
        if isMuted { return Color.red.opacity(0.2) }
        if isSelected { return trackColor }
        return Color.secondary.opacity(0.3)
    }

    // MARK: - Video Thumbnail Strip

    private var videoThumbnailContent: some View {
        HStack(spacing: 0) {
            if thumbnails.isEmpty {
                ForEach(0..<max(1, Int(clipWidth / 50)), id: \.self) { _ in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.gray.opacity(0.2), .gray.opacity(0.05)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 50)
                }
            } else {
                let thumbWidth = clipWidth / CGFloat(thumbnails.count)
                ForEach(0..<thumbnails.count, id: \.self) { i in
                    Image(nsImage: thumbnails[i])
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: thumbWidth)
                        .clipped()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Audio Waveform

    private var audioWaveformContent: some View {
        WaveformView(
            waveformData: waveformData,
            trackColor: trackColor,
            isSelected: isSelected,
            isMuted: isMuted,
            clipWidth: clipWidth
        )
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadWaveformIfNeeded() {
        guard trackType == .audio, waveformData.isEmpty else { return }
        let url = EditorViewModel.videoURL(for: clip)
        WaveformCache.shared.generateAsync(from: url) { data in
            waveformData = data
        }
    }

    private func loadThumbnailsIfNeeded() {
        guard trackType == .video, thumbnails.isEmpty else { return }
        let count = max(1, Int(clipWidth / 50))
        ThumbnailCache.shared.generateAsync(for: clip, count: count) { images in
            thumbnails = images
        }
    }

    // MARK: - Join Hint Badge

    private var joinHintBadge: some View {
        VStack {
            HStack {
                Spacer()
                Text("\(clip.duration.formattedDuration)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    .padding(4)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Duration Label

    private var durationLabel: some View {
        VStack {
            Spacer()
            HStack {
                Text(clip.duration.formattedDuration)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    .padding(4)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
