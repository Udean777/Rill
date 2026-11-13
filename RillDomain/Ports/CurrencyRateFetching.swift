import Foundation

/// Fetches the mid-market rate for a currency pair.
///
/// This is the app's only outbound network port. Implementations cache rates in
/// memory and fail without blocking: a missing rate must never empty the palette
/// (see architecture.md ADR-009).
public protocol CurrencyRateFetching: Sendable {
    /// The rate of `base` in units of `quote` (1 `base` = rate `quote`).
    ///
    /// - Throws: framework errors from the network layer. The error set is open
    ///   (URL loading errors), so `throws` is untyped.
    func rate(base: String, quote: String) async throws -> Double
}
