import SwiftUI

/// Left panel: Material import showing the list of imported video clips.
struct MaterialImportView: View {
    let clips: [Clip]
    let onAddMaterial: () -> Void
    let onSelectClip: (UUID?) -> Void
    @Binding var selectedClipID: UUID?
    @Binding var selectedCamera: Int

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("素材导入", systemImage: "tray.full")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            // Add button
            Button(action: onAddMaterial) {
                Label("添加素材", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            // Clip list
            if clips.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "暂无素材",
                    systemImage: "video.badge.plus",
                    description: Text("点击「添加素材」导入视频文件")
                )
                Spacer()
            } else {
                List {
                    ForEach(clips) { clip in
                        MaterialRow(clip: clip, isSelected: selectedClipID == clip.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelectClip(clip.id)
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

/// A single row in the material import list.
struct MaterialRow: View {
    let clip: Clip
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "video.fill")
                        .font(.caption)
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("\(clip.filename)")
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text(clip.duration.formattedDuration)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.06) : .clear)
        .cornerRadius(8)
    }
}
