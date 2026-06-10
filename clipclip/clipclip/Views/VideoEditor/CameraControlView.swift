import SwiftUI

/// Right panel: Camera/multi-camera control for switching angles.
struct CameraControlView: View {
    @Binding var selectedCamera: Int

    private let cameras: [(name: String, subtitle: String, icon: String)] = [
        ("Camera 1", "主视角", "camera.fill"),
        ("Camera 2", "副视角", "camera"),
        ("Camera 3", "广角", "camera.viewfinder"),
        ("Camera 4", "特写", "magnifyingglass.camera"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("机位控制", systemImage: "video.badge.ellipsis")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider()

            // Camera list
            List {
                ForEach(Array(cameras.enumerated()), id: \.offset) { index, camera in
                    Button(action: { selectedCamera = index }) {
                        HStack(spacing: 12) {
                            // Radio indicator
                            Image(systemName: selectedCamera == index
                                ? "record.circle.fill"
                                : "circle")
                                .foregroundStyle(selectedCamera == index ? Color.accentColor : .secondary)
                                .font(.title3)

                            // Camera icon
                            Image(systemName: camera.icon)
                                .foregroundStyle(.secondary)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(camera.name)
                                    .font(.subheadline)
                                    .fontWeight(selectedCamera == index ? .semibold : .regular)
                                Text(camera.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedCamera == index {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
