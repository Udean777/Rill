import Foundation

/// Supplies the current time. Injected so ranking and use cases never read the
/// clock themselves, which keeps their tests deterministic.
public protocol Clock: Sendable {
    /// The time at the moment of the call.
    var now: Date { get }
}
