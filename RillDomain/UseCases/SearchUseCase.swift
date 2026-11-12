import Foundation

/// Fans out to the providers, filters by match quality, then ranks within each
/// section by match score and frecency.
public struct SearchUseCase: Sendable {
    private let commands: CommandProviding
    private let applications: ApplicationCataloguing
    private let files: FileSearching?
    private let usage: UsageStoring
    private let clock: Clock
    private let isFilesEnabled: (@Sendable () async -> Bool)?

    public init(
        commands: CommandProviding,
        applications: ApplicationCataloguing,
        files: FileSearching? = nil,
        usage: UsageStoring,
        clock: Clock,
        isFilesEnabled: (@Sendable () async -> Bool)? = nil
    ) {
        self.commands = commands
        self.applications = applications
        self.files = files
        self.usage = usage
        self.clock = clock
        self.isFilesEnabled = isFilesEnabled
    }

    public func callAsFunction(_ query: SearchQuery) async -> [RankedSection] {
        let allCommands = commands.commands
        let snapshot = await usage.snapshot()

        let candidates: [SearchResult]
        if query.mode == .root {
            // Queryless field: suggested apps first, then the rest of the
            // catalogue, then commands — never an empty palette (design.md §5.2).
            let allApplications = await applications.applications()
            let suggestedIDs = suggestedApplicationIDs(usage: snapshot)
            let suggested = allApplications
                .filter { suggestedIDs.contains($0.id) }
                .map { $0.withSection(.suggestions) }
            let remaining = allApplications.filter { !suggestedIDs.contains($0.id) }
            candidates = suggested + remaining + allCommands
        } else {
            let filesAllowed: Bool
            if let isFilesEnabled {
                filesAllowed = await isFilesEnabled()
            } else {
                filesAllowed = files != nil
            }

            async let fetchedApps = applications.applications()
            async let fetchedFiles: [SearchResult] = {
                guard filesAllowed, let files else { return [] }
                return await files.search(query: query)
            }()

            let (allApplications, fileResults) = await (fetchedApps, fetchedFiles)

            let matchingStatic = (allCommands + allApplications).filter { result in
                MatchScore.score(title: result.title, query: query) > 0
            }

            candidates = matchingStatic + fileResults + fallbackResults(for: query)
        }

        return Ranking.rank(candidates, query: query, usage: snapshot, now: clock.now)
    }

    /// Applications used inside the suggestion window, most used first, capped.
    private func suggestedApplicationIDs(usage: UsageSnapshot) -> Set<SearchResult.ID> {
        let cutoff = clock.now.addingTimeInterval(-Self.suggestionWindow)
        let recent = usage.entries.filter { id, entry in
            id.source == "application" && entry.lastUsed >= cutoff
        }
        let ranked = recent.sorted { lhs, rhs in
            if lhs.value.count != rhs.value.count {
                return lhs.value.count > rhs.value.count
            }
            return lhs.value.lastUsed > rhs.value.lastUsed
        }
        return Set(ranked.prefix(Self.suggestionLimit).map(\.key))
    }

    private static let suggestionWindow: TimeInterval = 7 * 24 * 60 * 60
    private static let suggestionLimit = 5

    private func fallbackResults(for query: SearchQuery) -> [SearchResult] {
        var fallbacks: [SearchResult] = []
        let raw = query.raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return [] }

        // Calculator fallback
        if let value = ExpressionEvaluator.evaluate(raw) {
            let formatted = ExpressionEvaluator.formatResult(value)
            fallbacks.append(
                SearchResult(
                    id: .init(source: "calculation", raw: raw),
                    title: formatted,
                    subtitle: "= \(raw)",
                    icon: .systemSymbol("equal.circle"),
                    section: .fallback,
                    kind: .calculation,
                    primaryAction: .copyToPasteboard(formatted),
                    baseScore: 1.0
                )
            )
        }

        // Web search fallback
        if let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
            fallbacks.append(
                SearchResult(
                    id: .init(source: "web", raw: raw),
                    title: "Search Google for \"\(raw)\"",
                    subtitle: "Open in default browser",
                    icon: .systemSymbol("globe"),
                    section: .fallback,
                    kind: .web,
                    primaryAction: .openURL(url),
                    baseScore: 0.1
                )
            )
        }

        return fallbacks
    }
}
