import Foundation

/// Orders candidates within their sections by pinning, then blended match and
/// frecency. Pure; callers pass the snapshot and the time.
public enum Ranking {
    /// Ranks candidates into non-empty sections, in `Section.allCases` order.
    ///
    /// Ordering never crosses a section boundary: a file result cannot outrank
    /// a command result regardless of score.
    ///
    /// - Parameters:
    ///   - candidates: Unranked results from all providers.
    ///   - query: The user's input, used for match scoring.
    ///   - usage: Frecency and favourites as of the most recent snapshot.
    ///   - now: The reference time for decay.
    ///   - tuning: Weights and decay constants.
    /// - Returns: Non-empty sections only, in `Section.allCases` order.
    public static func rank(
        _ candidates: [SearchResult],
        query: SearchQuery,
        usage: UsageSnapshot,
        now: Date,
        tuning: RankingTuning = .standard
    ) -> [RankedSection] {
        let grouped = Dictionary(grouping: candidates, by: \.section)

        return Section.allCases.compactMap { section in
            guard let sectionResults = grouped[section], !sectionResults.isEmpty else {
                return nil
            }

            let scored = sectionResults
                .map { result in
                    Scored(
                        result: result,
                        score: blendedScore(
                            result,
                            query: query,
                            usage: usage,
                            now: now,
                            tuning: tuning
                        ),
                        isFavorite: usage.entry(for: result.id)?.isFavorite ?? false,
                        pinOrder: usage.entry(for: result.id)?.pinOrder
                    )
                }
                .sorted(by: precedes)

            return RankedSection(section: section, results: scored.map(\.result))
        }
    }

    private struct Scored {
        let result: SearchResult
        let score: Double
        let isFavorite: Bool
        let pinOrder: Int?
    }

    private static func blendedScore(
        _ result: SearchResult,
        query: SearchQuery,
        usage: UsageSnapshot,
        now: Date,
        tuning: RankingTuning
    ) -> Double {
        let match = MatchScore.score(title: result.title, query: query, tuning: tuning)
        let frecency = Frecency.score(usage.entry(for: result.id), now: now, tuning: tuning)
        return tuning.matchWeight * match + tuning.frecencyWeight * frecency
    }

    private static func precedes(_ lhs: Scored, _ rhs: Scored) -> Bool {
        if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }

        if lhs.isFavorite {
            switch (lhs.pinOrder, rhs.pinOrder) {
            case let (left?, right?) where left != right:
                return left < right
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                break
            }
        }

        if lhs.score != rhs.score { return lhs.score > rhs.score }

        // Stable tie-breaks: shorter title, then alphabetically, then identity.
        if lhs.result.title.count != rhs.result.title.count {
            return lhs.result.title.count < rhs.result.title.count
        }

        let titleOrder = lhs.result.title.localizedCaseInsensitiveCompare(rhs.result.title)
        if titleOrder != .orderedSame { return titleOrder == .orderedAscending }

        if lhs.result.id.source != rhs.result.id.source {
            return lhs.result.id.source < rhs.result.id.source
        }
        return lhs.result.id.raw < rhs.result.id.raw
    }
}
