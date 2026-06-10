import Foundation
import AVFoundation
import SwiftUI

/// Manages video export from a composition.
@Observable
final class VideoExporter {
    enum ExportState: Equatable {
        case idle
        case exporting(progress: Double)
        case completed(url: URL)
        case failed(error: String)
    }

    private(set) var state: ExportState = .idle

    private let composer = VideoComposer()

    /// Exports the composed video from multi-track to the given output URL.
    func export(tracks: [Track], to outputURL: URL, videoResolver: @escaping VideoComposer.VideoResolver) async {
        guard let composition = await composer.buildComposition(tracks: tracks, videoResolver: videoResolver) else {
            state = .failed(error: "No video clips to export")
            return
        }

        state = .exporting(progress: 0)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)")
            .appendingPathExtension("mp4")

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            state = .failed(error: "Failed to create export session")
            return
        }

        let progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await MainActor.run {
                    self?.state = .exporting(progress: Double(exportSession.progress))
                }
            }
        }

        do {
            try await exportSession.export(to: tempURL, as: .mp4)
            progressTask.cancel()

            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }
            try FileManager.default.copyItem(at: tempURL, to: outputURL)
            try? FileManager.default.removeItem(at: tempURL)

            await MainActor.run {
                self.state = .completed(url: outputURL)
            }
        } catch {
            progressTask.cancel()
            await MainActor.run {
                self.state = .failed(error: error.localizedDescription)
            }
        }
    }

    func reset() {
        state = .idle
    }
}
