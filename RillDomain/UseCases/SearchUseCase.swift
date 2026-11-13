import Foundation

/// Fans out to the providers, filters by match quality, then ranks within each
/// section by match score and frecency.
public struct SearchUseCase: Sendable {
    private let commands: CommandProviding
    private let applications: ApplicationCataloguing
    private let files: FileSearching?
    private let usage: UsageStoring
    private let clock: Clock
    private let preferences: (@Sendable () async -> Preferences)?
    private let currencyRates: CurrencyRateFetching?
    private let locale: LocaleProviding?

    public init(
        commands: CommandProviding,
        applications: ApplicationCataloguing,
        files: FileSearching? = nil,
        usage: UsageStoring,
        clock: Clock,
        preferences: (@Sendable () async -> Preferences)? = nil,
        currencyRates: CurrencyRateFetching? = nil,
        locale: LocaleProviding? = nil
    ) {
        self.commands = commands
        self.applications = applications
        self.files = files
        self.usage = usage
        self.clock = clock
        self.preferences = preferences
        self.currencyRates = currencyRates
        self.locale = locale
    }

    public func callAsFunction(_ query: SearchQuery) async -> [RankedSection] {
        let allCommands = commands.commands
        let snapshot = await usage.snapshot()
        let currentPreferences = await preferences?() ?? .default
        let pins = await usage.pinned()

        let candidates: [SearchResult]
        if query.mode == .root {
            // Queryless field: favourites, suggested apps, the rest of the
            // catalogue, then commands — never an empty palette (design.md §5.2).
            let allApplications = await applications.applications()
            let favorites = favoriteResults(
                from: pins,
                applications: allApplications,
                commands: allCommands
            )
            let favoriteIDs = Set(favorites.map(\.id))
            let applicationsByID = Dictionary(
                uniqueKeysWithValues: allApplications.map { ($0.id, $0) }
            )
            let suggestedIDs = suggestedApplicationIDs(
                usage: snapshot,
                windowDays: currentPreferences.suggestionWindowDays,
                excluding: favoriteIDs,
                availableIDs: Set(applicationsByID.keys)
            )
            let suggestedIDSet = Set(suggestedIDs)
            let suggested = suggestedIDs.compactMap { id in
                applicationsByID[id]?.withSection(.suggestions)
            }
            let remaining = allApplications.filter {
                !favoriteIDs.contains($0.id) && !suggestedIDSet.contains($0.id)
            }
            candidates =
                favorites + suggested + remaining
                + allCommands.filter { !favoriteIDs.contains($0.id) }
        } else {
            let filesAllowed = currentPreferences.fileSearchEnabled && files != nil

            async let fetchedApps = applications.applications()
            async let fetchedFiles: [SearchResult] = {
                guard filesAllowed, let files else { return [] }
                return await files.search(query: query)
            }()
            async let conversion = currencyFallback(
                for: query,
                enabled: currentPreferences.currencyConversionEnabled
            )

            let (allApplications, fileResults, currencyResult) = await (
                fetchedApps, fetchedFiles, conversion
            )

            // Pinned results only join a typed query when they match it.
            let favorites = favoriteResults(
                from: pins,
                applications: allApplications,
                commands: allCommands
            ).filter { MatchScore.score(title: $0.title, query: query) > 0 }
            let favoriteIDs = Set(favorites.map(\.id))

            let matchingStatic = (allCommands + allApplications).filter { result in
                !favoriteIDs.contains(result.id)
                    && MatchScore.score(title: result.title, query: query) > 0
            }

            var fallbacks = fallbackResults(for: query)
            if let currencyResult {
                fallbacks.append(currencyResult)
            }

            candidates =
                favorites + matchingStatic
                + fileResults.filter { !favoriteIDs.contains($0.id) }
                + fallbacks
        }

        return Ranking.rank(candidates, query: query, usage: snapshot, now: clock.now)
    }

    /// Rebuilds pinned rows: live catalogue data for apps and commands, the
    /// stored path for files.
    private func favoriteResults(
        from pins: [PinnedResult],
        applications: [SearchResult],
        commands: [SearchResult]
    ) -> [SearchResult] {
        let applicationsByID = Dictionary(
            uniqueKeysWithValues: applications.map { ($0.id, $0) }
        )
        let commandsByID = Dictionary(uniqueKeysWithValues: commands.map { ($0.id, $0) })

        return pins.compactMap { pin in
            if let fileURL = pin.fileURL {
                return SearchResult(
                    id: pin.id,
                    title: pin.title,
                    subtitle: pin.subtitle,
                    icon: .fileURL(fileURL),
                    section: .favorites,
                    kind: .file,
                    primaryAction: .openFile(fileURL)
                )
            }
            let live = applicationsByID[pin.id] ?? commandsByID[pin.id]
            return live?.withSection(.favorites)
        }
    }

    /// Applications used inside the suggestion window, most used first, capped.
    private func suggestedApplicationIDs(
        usage: UsageSnapshot,
        windowDays: Int,
        excluding: Set<SearchResult.ID> = [],
        availableIDs: Set<SearchResult.ID>? = nil
    ) -> [SearchResult.ID] {
        let cutoff = clock.now.addingTimeInterval(-TimeInterval(windowDays) * 86_400)
        let recent = usage.entries.filter { id, entry in
            guard id.source == "application",
                  entry.lastUsed >= cutoff,
                  !excluding.contains(id) else {
                return false
            }
            if let availableIDs {
                return availableIDs.contains(id)
            }
            return true
        }
        let ranked = recent.sorted { lhs, rhs in
            let leftScore = Frecency.score(lhs.value, now: clock.now)
            let rightScore = Frecency.score(rhs.value, now: clock.now)
            if leftScore != rightScore {
                return leftScore > rightScore
            }
            if lhs.value.count != rhs.value.count {
                return lhs.value.count > rhs.value.count
            }
            if lhs.value.lastUsed != rhs.value.lastUsed {
                return lhs.value.lastUsed > rhs.value.lastUsed
            }
            if lhs.key.source != rhs.key.source {
                return lhs.key.source < rhs.key.source
            }
            return lhs.key.raw < rhs.key.raw
        }
        return Array(ranked.prefix(Self.suggestionLimit).map { $0.key })
    }

    private static let suggestionLimit = 5

    /// Converts a currency amount in the query to the user's local currency.
    ///
    /// Runs concurrently with the other providers. A missing rate or a
    /// non-currency query yields `nil`; the palette degrades rather than blocks.
    private func currencyFallback(
        for query: SearchQuery,
        enabled: Bool
    ) async -> SearchResult? {
        guard enabled, let currencyRates, let locale else { return nil }
        let raw = query.raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = CurrencyParser.parse(raw) else { return nil }

        let target = (parsed.targetCode ?? locale.currencyCode)?.uppercased()
        guard let target, !target.isEmpty else { return nil }

        let source = parsed.code
        let rate: Double
        if source == target {
            rate = 1
        } else {
            // Offline is expected, not exceptional: skip the row, keep the palette.
            guard let fetched = try? await currencyRates.rate(base: source, quote: target) else {
                return nil
            }
            rate = fetched
        }

        let converted = parsed.amount * Decimal(rate)
        let formatted = CurrencyFormatter.string(converted, code: target, locale: locale.locale)
        return SearchResult(
            id: .init(source: "currency", raw: raw),
            title: formatted,
            subtitle: "\(parsed.amount) \(source) → \(target)",
            icon: .systemSymbol("dollarsign.circle"),
            section: .currency,
            kind: .currency,
            primaryAction: .copyToPasteboard(formatted),
            baseScore: 1.0
        )
    }

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
