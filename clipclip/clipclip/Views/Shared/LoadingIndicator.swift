import SwiftUI

struct LoadingIndicator: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Export Progress View

struct ExportProgressView: View {
    let progress: Double
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Exporting...")
                .font(.headline)

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(width: 200)

            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Cancel", role: .destructive, action: onCancel)
                .buttonStyle(.bordered)
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Error View

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.subheadline)
            Spacer()
            Button("Dismiss", action: onDismiss)
                .font(.subheadline.bold())
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }
}
