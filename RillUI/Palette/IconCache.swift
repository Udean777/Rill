import AppKit
import RillDomain

/// Caches file icons so row rendering never asks IconServices twice.
///
/// Cold `NSWorkspace.icon(forFile:)` calls measured ~1.6 ms each; a cache hit
/// is ~0.14 ms. Bounded so the cache stays a few megabytes.
final class IconCache {
    static let shared = IconCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 300
    }

    func image(for url: URL) -> NSImage {
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        cache.setObject(image, forKey: key)
        return image
    }

    /// Loads icons for results that render first, so the show path never pays
    /// the cold cost. Call only when the palette is not visible yet.
    func prewarm(_ results: [SearchResult], limit: Int = 20) {
        var loaded = 0
        for result in results {
            guard case .fileURL(let url) = result.icon else { continue }
            _ = image(for: url)
            loaded += 1
            if loaded >= limit { break }
        }
    }
}
