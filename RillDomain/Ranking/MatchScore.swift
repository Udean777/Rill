import Foundation

/// How well a title answers a query, in `0…1`. Pure and deterministic.
public enum MatchScore {
    /// - Returns: `0` when the title does not match at all.
    public static func score(
        title: String,
        query: SearchQuery,
        tuning: RankingTuning = .standard
    ) -> Double {
        score(foldedTitle: fold(title), foldedQuery: query.folded, tuning: tuning)
    }

    /// Like `score`, but a fuzzy-only subsequence scores `0`: the title must
    /// contain the query's words.
    public static func containingScore(
        title: String,
        query: SearchQuery,
        tuning: RankingTuning = .standard
    ) -> Double {
        relevantScore(
            foldedTitle: fold(title),
            foldedQuery: query.folded,
            query: query,
            tuning: tuning
        )
    }

    /// Returns the best match score for `result`, checking `title` first and
    /// falling back to the parent breadcrumb `subtitle` (with constant
    /// `"System Settings › "` prefix stripped) + `title`. A fuzzy-only
    /// subsequence scores `0`: the result must contain the query's words.
    public static func bestScore(
        for result: SearchResult,
        query: SearchQuery,
        tuning: RankingTuning = .standard
    ) -> Double {
        let foldedQuery = query.folded
        let foldedTitle = fold(result.title)
        let titleScore = relevantScore(
            foldedTitle: foldedTitle,
            foldedQuery: foldedQuery,
            query: query,
            tuning: tuning
        )
        if titleScore > 0 {
            return titleScore
        }
        guard result.kind == .systemSettings,
              let subtitle = result.subtitle,
              !subtitle.isEmpty else {
            return 0
        }
        let prefix = "System Settings › "
        let breadcrumb = subtitle.hasPrefix(prefix)
            ? String(subtitle.dropFirst(prefix.count))
            : subtitle
        guard !breadcrumb.isEmpty else { return 0 }
        let folded = fold("\(breadcrumb) \(result.title)")
        return 0.85 * relevantScore(
            foldedTitle: folded,
            foldedQuery: foldedQuery,
            query: query,
            tuning: tuning
        )
    }

    private static func relevantScore(
        foldedTitle: String,
        foldedQuery: String,
        query: SearchQuery,
        tuning: RankingTuning
    ) -> Double {
        let score = score(foldedTitle: foldedTitle, foldedQuery: foldedQuery, tuning: tuning)
        guard score > 0 else { return 0 }
        return relates(foldedTitle, to: query) ? score : 0
    }

    private static func score(
        foldedTitle: String,
        foldedQuery: String,
        tuning: RankingTuning
    ) -> Double {
        guard !foldedQuery.isEmpty else { return 1 }

        if foldedTitle == foldedQuery { return 1 }
        if foldedTitle.hasPrefix(foldedQuery) { return 0.9 }
        if foldedTitle.contains(foldedQuery) {
            if hasWordBoundaryPrefix(foldedTitle, foldedQuery) { return 0.8 }
            return 0.6
        }

        guard let gap = subsequenceGap(foldedTitle, foldedQuery) else { return 0 }
        return max(tuning.fuzzyFloor, tuning.fuzzyCeiling - tuning.gapPenalty * Double(gap))
    }

    /// `true` when every token of `query` appears in the folded text once
    /// punctuation is ignored.
    private static func relates(_ foldedText: String, to query: SearchQuery) -> Bool {
        var compacted: String?
        for token in query.tokens {
            let foldedToken = fold(token)
            if foldedToken.isEmpty || foldedText.contains(foldedToken) {
                continue
            }
            // Only pay for punctuation stripping when the plain text misses,
            // so "wifi" still finds "Wi-Fi" without touching the hot path.
            let haystack = compacted ?? compact(foldedText)
            compacted = haystack
            guard haystack.contains(compact(foldedToken)) else { return false }
        }
        return true
    }

    private static func compact(_ value: String) -> String {
        value.filter { $0.isLetter || $0.isNumber }
    }

    private static func fold(_ value: String) -> String {
        if value.utf8.allSatisfy({ $0 < 128 }) {
            return value.lowercased()
        }
        return value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    /// `true` when any word in `title` starts with `query`.
    private static func hasWordBoundaryPrefix(_ title: String, _ query: String) -> Bool {
        var atWordStart = true
        var index = title.startIndex
        while index < title.endIndex {
            let character = title[index]
            let isWordCharacter = character.isLetter || character.isNumber
            if isWordCharacter {
                if atWordStart && title[index...].hasPrefix(query) {
                    return true
                }
                atWordStart = false
            } else {
                atWordStart = true
            }
            index = title.index(after: index)
        }
        return false
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
