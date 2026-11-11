/// Tunable constants for ranking, in one place so behaviour is testable and
/// adjusts without touching the algorithm.
public struct RankingTuning: Sendable, Equatable {
    /// Weight of match quality in the blended score.
    public let matchWeight: Double

    /// Weight of frecency in the blended score.
    public let frecencyWeight: Double

    /// Days after which frecency decays to 1/e.
    public let decayDays: Double

    /// Lowest score for a subsequence (fuzzy) match.
    public let fuzzyFloor: Double

    /// Highest score for a subsequence (fuzzy) match.
    public let fuzzyCeiling: Double

    /// Score lost per skipped character in a subsequence match.
    public let gapPenalty: Double

    public static let standard = RankingTuning(
        matchWeight: 0.6,
        frecencyWeight: 0.4,
        decayDays: 30,
        fuzzyFloor: 0.3,
        fuzzyCeiling: 0.5,
        gapPenalty: 0.02
    )

    public init(
        matchWeight: Double,
        frecencyWeight: Double,
        decayDays: Double,
        fuzzyFloor: Double,
        fuzzyCeiling: Double,
        gapPenalty: Double
    ) {
        self.matchWeight = matchWeight
        self.frecencyWeight = frecencyWeight
        self.decayDays = decayDays
        self.fuzzyFloor = fuzzyFloor
        self.fuzzyCeiling = fuzzyCeiling
        self.gapPenalty = gapPenalty
    }
}
