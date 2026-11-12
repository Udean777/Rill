import Foundation

/// A stored pin, detached from the search result that created it.
///
/// Applications and commands are re-resolved against the live catalogue when
/// shown, so a renamed or uninstalled app never produces a stale row. Files
/// carry their path so they can be rebuilt without the file index.
public struct PinnedResult: Sendable, Equatable {
    public let id: SearchResult.ID
    public let title: String
    public let subtitle: String?
    public let fileURL: URL?
    public let pinOrder: Int

    public init(
        id: SearchResult.ID,
        title: String,
        subtitle: String? = nil,
        fileURL: URL? = nil,
        pinOrder: Int
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.fileURL = fileURL
        self.pinOrder = pinOrder
    }
}
