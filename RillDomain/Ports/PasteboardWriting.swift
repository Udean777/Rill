import Foundation

/// Port for writing content back onto the system pasteboard.
public protocol PasteboardWriting: Sendable {
    func writeText(_ text: String, richText: String?) async throws
    func writeImage(at fileURL: URL) async throws
    func writeFiles(at urls: [URL]) async throws
}
