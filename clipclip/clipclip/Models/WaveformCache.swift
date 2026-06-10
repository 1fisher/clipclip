import Foundation
import AVFoundation

/// Caches waveform data per asset identifier.
final class WaveformCache {
    static let shared = WaveformCache()

    private let cache = NSCache<NSString, NSArray>()
    private let queue = DispatchQueue(label: "com.clipclip.waveform", qos: .utility)

    private init() {
        cache.countLimit = 50
    }

    func waveform(for assetIdentifier: String) -> [Float]? {
        cache.object(forKey: assetIdentifier as NSString) as? [Float]
    }

    func set(_ data: [Float], for assetIdentifier: String) {
        cache.setObject(data as NSArray, forKey: assetIdentifier as NSString)
    }

    /// Asynchronously generates waveform data from an audio file URL.
    /// - Parameters:
    ///   - url: The audio file URL.
    ///   - samplesPerSecond: Target sample density for display.
    ///   - completion: Called on the main thread with the waveform data.
    func generateAsync(from url: URL, samplesPerSecond: Int = 20, completion: @escaping ([Float]) -> Void) {
        let key = url.lastPathComponent
        if let cached = waveform(for: key) {
            DispatchQueue.main.async { completion(cached) }
            return
        }

        queue.async { [weak self] in
            guard let data = Self.extractWaveform(from: url, samplesPerSecond: samplesPerSecond) else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            self?.set(data, for: key)
            DispatchQueue.main.async { completion(data) }
        }
    }

    /// Extracts amplitude data from an audio file.
    static func extractWaveform(from url: URL, samplesPerSecond: Int = 20) -> [Float]? {
        guard let audioFile = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat,
                                            frameCapacity: AVAudioFrameCount(audioFile.length))
        else { return nil }

        guard let _ = try? audioFile.read(into: buffer),
              let channelData = buffer.floatChannelData
        else { return nil }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        let samplesPerFrame = samplesPerSecond
        let totalSamples = max(1, frameLength / samplesPerFrame)

        var waveform: [Float] = []
        waveform.reserveCapacity(totalSamples)

        for i in 0..<totalSamples {
            let startFrame = i * samplesPerFrame
            let endFrame = min(startFrame + samplesPerFrame, frameLength)
            var maxAmplitude: Float = 0

            for frame in startFrame..<endFrame {
                for ch in 0..<channelCount {
                    let amplitude = abs(channelData[ch][frame])
                    maxAmplitude = max(maxAmplitude, amplitude)
                }
            }
            waveform.append(maxAmplitude)
        }

        // Normalize
        if let peak = waveform.max(), peak > 0 {
            waveform = waveform.map { min($0 / peak, 1.0) }
        }

        return waveform
    }
}
