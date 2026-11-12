import Foundation

/// How well a title answers a query, in `0…1`. Pure and deterministic.
public enum MatchScore {
    /// - Returns: `0` when the title does not match at all.
    public static func score(
        title: String,
        query: SearchQuery,
        tuning: RankingTuning = .standard
    ) -> Double {
        let foldedQuery = query.folded
        guard !foldedQuery.isEmpty else { return 1 }

        let foldedTitle = fold(title)
        if foldedTitle == foldedQuery { return 1 }
        if foldedTitle.hasPrefix(foldedQuery) { return 0.9 }
        if hasWordBoundaryPrefix(foldedTitle, foldedQuery) { return 0.8 }
        if foldedTitle.contains(foldedQuery) { return 0.6 }

        guard let gap = subsequenceGap(foldedTitle, foldedQuery) else { return 0 }
        return max(tuning.fuzzyFloor, tuning.fuzzyCeiling - tuning.gapPenalty * Double(gap))
    }

    private static func fold(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    /// `true` when any word in `title` starts with `query`.
    private static func hasWordBoundaryPrefix(_ title: String, _ query: String) -> Bool {
        title
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .contains { $0.hasPrefix(query) }
    }

    /// Characters skipped between the first and last subsequence match, or
    /// `nil` when `query` is not a subsequence of `title`.
    private static func subsequenceGap(_ title: String, _ query: String) -> Int? {
        guard !query.isEmpty else { return 0 }
        var firstMatch: Int?
        var lastMatch = 0
        var queryIndex = query.startIndex

        for (index, character) in title.enumerated() {
            guard character == query[queryIndex] else { continue }
            firstMatch = firstMatch ?? index
            lastMatch = index
            queryIndex = query.index(after: queryIndex)
            if queryIndex == query.endIndex { break }
        }

        guard queryIndex == query.endIndex, let firstMatch else { return nil }
        return (lastMatch - firstMatch + 1) - query.count
    }
}
