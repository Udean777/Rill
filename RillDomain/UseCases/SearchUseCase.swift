import Foundation

/// Fans out to the providers, filters by match quality, then ranks within each
/// section by match score and frecency.
public struct SearchUseCase: Sendable {
    private static let systemSettingsLimit = 15

    private let commands: CommandProviding
    private let applications: ApplicationCataloguing
    private let files: FileSearching?
    private let usage: UsageStoring
    private let clock: Clock
    private let preferences: (@Sendable () async -> Preferences)?
    private let systemSettings: SystemSettingsProviding?

    private let rootLayout: RootLayoutBuilder
    private let fallbacks = FallbackResultsProvider()
    private let currencyFallback: CurrencyFallbackProvider?

    public init(
        commands: CommandProviding,
        applications: ApplicationCataloguing,
        files: FileSearching? = nil,
        usage: UsageStoring,
        clock: Clock,
        preferences: (@Sendable () async -> Preferences)? = nil,
        currencyRates: CurrencyRateFetching? = nil,
        locale: LocaleProviding? = nil,
        systemSettings: SystemSettingsProviding? = nil
    ) {
        self.commands = commands
        self.applications = applications
        self.files = files
        self.usage = usage
        self.clock = clock
        self.preferences = preferences
        self.systemSettings = systemSettings
        self.rootLayout = RootLayoutBuilder(clock: clock)
        if let currencyRates, let locale {
            self.currencyFallback = CurrencyFallbackProvider(
                rates: currencyRates,
                locale: locale
            )
        } else {
            self.currencyFallback = nil
        }
    }

    public func callAsFunction(_ query: SearchQuery) async -> [RankedSection] {
        let allCommands = commands.commands
        let snapshot = await usage.snapshot()
        let currentPreferences = await preferences?() ?? .default
        let pins = await usage.pinned()

        let candidates: [SearchResult]
        switch query.mode {
        case .root:
            let allApplications = await applications.applications()
            candidates = rootLayout.build(
                commands: allCommands,
                applications: allApplications,
                pins: pins,
                usage: snapshot,
                windowDays: currentPreferences.suggestionWindowDays
            )
        case .text:
            candidates = await typedCandidates(
                query: query,
                commands: allCommands,
                pins: pins,
                preferences: currentPreferences
            )
        }

        // Sections the user switched off never reach the layout, for a typed
        // query and for the root one alike.
        let visible = candidates.filter {
            !currentPreferences.hiddenSections.contains($0.section)
        }
        return Ranking.rank(visible, query: query, usage: snapshot, now: clock.now)
    }

    private func typedCandidates(
        query: SearchQuery,
        commands allCommands: [SearchResult],
        pins: [PinnedResult],
        preferences currentPreferences: Preferences
    ) async -> [SearchResult] {
        let filesAllowed = currentPreferences.fileSearchEnabled
            && (currentPreferences.fileSearchIncludeFiles || currentPreferences.fileSearchIncludeFolders)
            && files != nil
        let fileOptions = FileSearchOptions(preferences: currentPreferences)

        async let fetchedApps = applications.applications()
        async let fetchedSystemSettings = systemSettings?.settings() ?? []
        async let fetchedFiles: [SearchResult] = {
            guard filesAllowed, let files else { return [] }
            return await files.search(query: query, options: fileOptions)
        }()
        async let conversion = currencyResult(
            for: query,
            enabled: currentPreferences.currencyConversionEnabled
        )

        let (allApplications, allSystemSettings, fileResults, currencyRow) = await (
            fetchedApps, fetchedSystemSettings, fetchedFiles, conversion
        )

        // Pinned results only join a typed query when they match it.
        let favorites = PinnedResults.rebuild(
            from: pins,
            applications: allApplications,
            commands: allCommands
        ).filter { MatchScore.bestScore(for: $0, query: query) > 0 }
        let favoriteIDs = Set(favorites.map(\.id))

        let matchingStatic = (allCommands + allApplications).filter { result in
            !favoriteIDs.contains(result.id)
                && MatchScore.bestScore(for: result, query: query) > 0
        }

        var fallbackRows = fallbacks.results(
            for: query,
            calculatorEnabled: currentPreferences.calculatorEnabled,
            webSearchEnabled: currentPreferences.webSearchEnabled,
            defaultBrowserBundleID: currentPreferences.defaultBrowserBundleID
        )
        if let currencyRow {
            fallbackRows.append(currencyRow)
        }

        return favorites
            + matchingStatic
            + topSystemSettings(allSystemSettings, query: query)
            + fileResults.filter { !favoriteIDs.contains($0.id) }
            + fallbackRows
    }

    private func currencyResult(for query: SearchQuery, enabled: Bool) async -> SearchResult? {
        guard let currencyFallback else { return nil }
        return await currencyFallback.result(for: query, enabled: enabled)
    }

    /// System Settings panes join a typed query only; capped to the top matches
    /// so short queries never flood the palette with hundreds of rows.
    private func topSystemSettings(
        _ allSystemSettings: [SearchResult],
        query: SearchQuery
    ) -> [SearchResult] {
        allSystemSettings
            .compactMap { result -> (result: SearchResult, score: Double)? in
                let score = MatchScore.bestScore(for: result, query: query)
                return score > 0 ? (result, score) : nil
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.result.title.count < rhs.result.title.count
            }
            .prefix(Self.systemSettingsLimit)
            .map(\.result)
    }
}
