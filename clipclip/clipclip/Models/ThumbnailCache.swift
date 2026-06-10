import AppKit
import AVFoundation

final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, NSArray>()
    private let generator = ThumbnailGenerator()

    private init() {}

    func thumbnails(
        for clip: Clip,
        count: Int,
        size: CGSize = CGSize(width: 80, height: 60)
    ) -> [NSImage]? {
        let key = "\(clip.assetLocalIdentifier)_\(clip.startTime)_\(clip.endTime)_\(count)" as NSString
        return cache.object(forKey: key) as? [NSImage]
    }

    func generateAsync(
        for clip: Clip,
        count: Int,
        size: CGSize = CGSize(width: 80, height: 60),
        completion: @escaping ([NSImage]) -> Void
    ) {
        let key = "\(clip.assetLocalIdentifier)_\(clip.startTime)_\(clip.endTime)_\(count)" as NSString
        if let cached = cache.object(forKey: key) as? [NSImage] {
            completion(cached)
            return
        }

        Task {
            let images = await generator.generateThumbnails(
                for: clip,
                videoResolver: EditorViewModel.videoURL(for:),
                count: count,
                size: size
            )
            guard !images.isEmpty else { return }
            cache.setObject(images as NSArray, forKey: key)
            DispatchQueue.main.async { completion(images) }
        }
    }
}
