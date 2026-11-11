import Foundation

/// Usage data for ranking: how often and how recently a result was run, plus
/// pinning. Immutable value; the store hands a fresh snapshot per search.
public struct UsageSnapshot: Sendable, Equatable {
    /// One result's usage.
    public struct Entry: Sendable, Equatable {
        public let count: Int
        public let lastUsed: Date
        public let isFavorite: Bool
        public let pinOrder: Int?

        public init(
            count: Int,
            lastUsed: Date,
            isFavorite: Bool = false,
            pinOrder: Int? = nil
        ) {
            self.count = count
            self.lastUsed = lastUsed
            self.isFavorite = isFavorite
            self.pinOrder = pinOrder
        }
    }

    public static let empty = UsageSnapshot()

    public let entries: [SearchResult.ID: Entry]

    public init(entries: [SearchResult.ID: Entry] = [:]) {
        self.entries = entries
    }

    public func entry(for id: SearchResult.ID) -> Entry? {
        entries[id]
    }
}
