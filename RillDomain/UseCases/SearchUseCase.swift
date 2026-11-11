/// Fans out to the providers, filters by match quality, then ranks within each
/// section by match score and frecency.
public struct SearchUseCase: Sendable {
    private let commands: CommandProviding
    private let applications: ApplicationCataloguing
    private let usage: UsageStoring
    private let clock: Clock

    public init(
        commands: CommandProviding,
        applications: ApplicationCataloguing,
        usage: UsageStoring,
        clock: Clock
    ) {
        self.commands = commands
        self.applications = applications
        self.usage = usage
        self.clock = clock
    }

    public func callAsFunction(_ query: SearchQuery) async -> [RankedSection] {
        let allCommands = commands.commands

        let candidates: [SearchResult]
        if query.mode == .root {
            candidates = allCommands
        } else {
            let allApplications = await applications.applications()
            candidates = (allCommands + allApplications).filter { result in
                MatchScore.score(title: result.title, query: query) > 0
            }
        }

        let snapshot = await usage.snapshot()
        return Ranking.rank(candidates, query: query, usage: snapshot, now: clock.now)
    }
}
