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
    public let trimmed: String
    public let folded: String

    public init(raw: String) {
        self.raw = raw
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        self.trimmed = trimmed
        self.folded = Self.fold(trimmed)
    }

    public var mode: Mode {
        trimmed.isEmpty ? .root : .text(trimmed)
    }

    public var tokens: [String] {
        trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// `true` when `title` contains the query, ignoring case and diacritics.
    public func matches(title: String) -> Bool {
        guard !folded.isEmpty else { return true }
        return Self.fold(title).contains(folded)
    }

    public static func fold(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
