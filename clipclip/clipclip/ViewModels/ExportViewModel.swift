import Foundation
import AVFoundation
import SwiftUI

/// Manages the export process state.
@Observable
final class ExportViewModel {
    var exportState: VideoExporter.ExportState = .idle

    private let exporter = VideoExporter()

    var progress: Double {
        if case .exporting(let progress) = exportState {
            return progress
        }
        return 0
    }

    var isExporting: Bool {
        if case .exporting = exportState { return true }
        return false
    }

    var errorMessage: String? {
        if case .failed(let error) = exportState { return error }
        return nil
    }

    var isCompleted: Bool {
        if case .completed = exportState { return true }
        return false
    }

    /// Export using multi-track timeline.
    func export(tracks: [Track], to outputURL: URL, videoResolver: @escaping VideoComposer.VideoResolver) async {
        await exporter.export(tracks: tracks, to: outputURL, videoResolver: videoResolver)

        await MainActor.run {
            self.exportState = self.exporter.state
        }
    }

    func markComplete() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            reset()
        }
    }

    func reset() {
        exportState = .idle
        exporter.reset()
    }
}
