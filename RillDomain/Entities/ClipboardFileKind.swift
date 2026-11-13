import Foundation

/// Classifies clipboard file paths by extension so UI and domain callers
/// can identify image files across standard, modern, and RAW formats.
public enum ClipboardFileKind {
    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "avif", "jxl",
        "tiff", "tif", "bmp", "ico", "icns", "svg", "svgz", "raw", "dng",
        "cr2", "cr3", "nef", "arw", "orf", "rw2", "pef", "srw", "raf", "tga",
        "exr", "hdr", "psd", "xbm", "wbmp", "jp2", "j2k", "jpf", "jpx", "jpm",
        "eps", "pct", "pict", "pcx", "ppm", "pgm", "pbm", "pnm",
    ]

    /// Returns `true` when the given file extension (with or without leading dot)
    /// matches a known image format.
    public static func isImageExtension(_ fileExtension: String) -> Bool {
        let normalized = fileExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .drop(while: { $0 == "." })
            .lowercased()
        guard !normalized.isEmpty else { return false }
        return imageExtensions.contains(normalized)
    }

    /// Returns `true` when the file at `path` has a known image extension.
    public static func isImageFile(atPath path: String) -> Bool {
        let fileExtension = URL(fileURLWithPath: path).pathExtension
        return isImageExtension(fileExtension)
    }
}
