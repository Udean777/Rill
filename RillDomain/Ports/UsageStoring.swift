import Foundation

/// Loads and records usage data for frecency ranking.
///
/// `record` never throws: usage is an enhancement, so a failed write must not
/// fail the action the user actually asked for. Adapters log the failure.
public protocol UsageStoring: Sendable {
    /// The usage known as of now, or `.empty` when nothing has been stored.
    func snapshot() async -> UsageSnapshot

    /// Records one execution of `id`.
    func record(_ id: SearchResult.ID, at date: Date) async
}
