import Foundation

/// Filters resolved grid items by match score, best match first.
public enum ApplicationGridFilter {
    /// - Returns: Items whose title matches `query`, ordered by score then title.
    public static func filter(
        _ items: [ApplicationGridItem],
        query: SearchQuery
    ) -> [ApplicationGridItem] {
        items
            .compactMap { item -> (item: ApplicationGridItem, score: Double)? in
                let score = MatchScore.containingScore(title: item.title, query: query)
                return score > 0 ? (item, score) : nil
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.item.title.localizedCaseInsensitiveCompare(rhs.item.title) == .orderedAscending
            }
            .map(\.item)
    }
}
