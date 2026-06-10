import SwiftUI

/// Header bar displayed on the left side of each track row.
/// Shows track type icon, name, mute toggle, and delete button.
struct TrackHeaderView: View {
    @Bindable var track: Track
    let onDelete: () -> Void
    let onAddClip: () -> Void

    @State private var isHovering = false
    @State private var isEditingName = false
    @State private var editedName = ""

    private var trackColor: Color {
        track.type == .video ? Color.accentColor : Color.green
    }

    var body: some View {
        HStack(spacing: 6) {
            // Track type icon
            Image(systemName: track.type == .video ? "video.fill" : "music.note")
                .font(.caption)
                .foregroundStyle(trackColor)
                .frame(width: 18)

            // Track name
            if isEditingName {
                TextField("", text: $editedName)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .frame(width: 70)
                    .onSubmit {
                        track.name = editedName
                        isEditingName = false
                    }
            } else {
                Text(track.name)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(width: 70, alignment: .leading)
                    .onTapGesture {
                        editedName = track.name
                        isEditingName = true
                    }
            }

            Spacer(minLength: 4)

            // Mute button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    track.isMuted.toggle()
                }
            }) {
                Image(systemName: track.isMuted
                    ? "speaker.slash.fill"
                    : "speaker.fill")
                    .font(.caption2)
                    .foregroundStyle(track.isMuted ? .red : .secondary)
            }
            .buttonStyle(.plain)
            .help(track.isMuted ? "取消静音" : "静音")

            // Delete button (shown on hover)
            if isHovering {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("删除轨道")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(width: 130, height: trackHeight)
        .background(trackColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Track Height Constant

let trackHeight: CGFloat = 48
let trackSpacing: CGFloat = 4
