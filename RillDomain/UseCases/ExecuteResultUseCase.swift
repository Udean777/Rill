/// Runs a result's primary action, then records the use for frecency.
///
/// Recording happens only after a successful action, and never throws: usage
/// is an enhancement, not part of the action the user asked for.
public struct ExecuteResultUseCase: Sendable {
    private let performer: ActionPerforming
    private let usage: UsageStoring
    private let clock: Clock

    public init(performer: ActionPerforming, usage: UsageStoring, clock: Clock) {
        self.performer = performer
        self.usage = usage
        self.clock = clock
    }

    public func callAsFunction(_ result: SearchResult) async throws {
        try await performer.perform(result.primaryAction)
        await usage.record(result.id, at: clock.now)
    }
}
