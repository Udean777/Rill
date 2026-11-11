import Foundation

/// The user's input, normalized for matching. Matching is case- and
/// diacritic-insensitive (see design.md §4.5).
public struct SearchQuery: Sendable, Hashable {
    public enum Mode: Sendable, Hashable {
        /// Empty field: suggestions.
        case root
        /// Ordinary text.
        case text(String)
    }

    public let raw: String

    public init(raw: String) {
        self.raw = raw
    }

    public var trimmed: String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var mode: Mode {
        trimmed.isEmpty ? .root : .text(trimmed)
    }

    public var tokens: [String] {
        trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// `true` when `title` contains the query, ignoring case and diacritics.
    public func matches(title: String) -> Bool {
        let foldedQuery = Self.fold(trimmed)
        guard !foldedQuery.isEmpty else { return true }
        return Self.fold(title).contains(foldedQuery)
    }

    private static func fold(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
