import Foundation

/// Recency-weighted use frequency, in `0…1`.
public enum Frecency {
    /// - Returns: `0` when the result has never been used.
    public static func score(
        _ entry: UsageSnapshot.Entry?,
        now: Date,
        tuning: RankingTuning = .standard
    ) -> Double {
        guard let entry, entry.count > 0 else { return 0 }

        // A last use in the future means clock skew, not extra freshness.
        let elapsedDays = max(0, now.timeIntervalSince(entry.lastUsed) / 86_400)
        let decay = exp(-elapsedDays / tuning.decayDays)

        // log1p compresses long histories; dividing by 1 + the same value
        // maps any count into 0..<1 without a magic maximum.
        let uses = log1p(Double(entry.count))
        return decay * (uses / (1 + uses))
    }
}
