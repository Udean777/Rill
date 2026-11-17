import Foundation

/// Builds the queryless palette: favourites, suggested apps, the rest of the
/// catalogue, then commands — never an empty palette (design.md §5.2).
struct RootLayoutBuilder: Sendable {
    private static let suggestionLimit = 5

    private let clock: Clock

    init(clock: Clock) {
        self.clock = clock
    }

    func build(
        commands: [SearchResult],
        applications: [SearchResult],
        pins: [PinnedResult],
        usage: UsageSnapshot,
        windowDays: Int
    ) -> [SearchResult] {
        let favorites = PinnedResults.rebuild(
            from: pins,
            applications: applications,
            commands: commands
        )
        let favoriteIDs = Set(favorites.map(\.id))
        let applicationsByID = Dictionary(
            uniqueKeysWithValues: applications.map { ($0.id, $0) }
        )
        let suggestedIDs = suggestedApplicationIDs(
            usage: usage,
            windowDays: windowDays,
            excluding: favoriteIDs,
            availableIDs: Set(applicationsByID.keys)
        )
        let suggestedIDSet = Set(suggestedIDs)
        let suggested = suggestedIDs.compactMap { id in
            applicationsByID[id]?.withSection(.suggestions)
        }
        let remaining = applications.filter {
            !favoriteIDs.contains($0.id) && !suggestedIDSet.contains($0.id)
        }
        return favorites + suggested + remaining
            + commands.filter { !favoriteIDs.contains($0.id) }
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
            guard id.source == .application,
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
}
