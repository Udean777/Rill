import Foundation
import Testing

@testable import RillDomain

@Suite("Ranking")
struct RankingTests {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    @Test func `prefix match outranks substring`() {
        let prefix = SearchResult.fixture(title: "Safari")
        let substring = SearchResult.fixture(title: "Unsafely")

        let ranked = Ranking.rank(
            [substring, prefix],
            query: SearchQuery(raw: "saf"),
            usage: .empty,
            now: now
        )

        #expect(ranked.first?.results.map(\.title) == ["Safari", "Unsafely"])
    }

    @Test func `frecency promotes a used result over an unused one`() {
        let used = SearchResult.fixture(title: "Safari")
        let unused = SearchResult.fixture(title: "Safe")
        let usage = UsageSnapshot(entries: [used.id: .init(count: 3, lastUsed: now)])

        let ranked = Ranking.rank(
            [unused, used],
            query: SearchQuery(raw: "sa"),
            usage: usage,
            now: now
        )

        #expect(ranked.first?.results.first?.title == "Safari")
    }

    @Test func `shorter title breaks a score tie`() {
        let longer = SearchResult.fixture(title: "Alpha")
        let shorter = SearchResult.fixture(title: "Also")

        let ranked = Ranking.rank(
            [longer, shorter],
            query: SearchQuery(raw: "al"),
            usage: .empty,
            now: now
        )

        #expect(ranked.first?.results.map(\.title) == ["Also", "Alpha"])
    }

    @Test func `alphabetical order is the final tie-break`() {
        let beta = SearchResult.fixture(title: "Alb")
        let alpha = SearchResult.fixture(title: "Ala")

        let ranked = Ranking.rank(
            [beta, alpha],
            query: SearchQuery(raw: "al"),
            usage: .empty,
            now: now
        )

        #expect(ranked.first?.results.map(\.title) == ["Ala", "Alb"])
    }

    @Test func `sections keep their fixed order`() {
        let command = SearchResult.fixture(title: "Open Opera")
        let application = SearchResult.fixture(title: "Opera", section: .applications)

        let ranked = Ranking.rank(
            [application, command],
            query: SearchQuery(raw: "op"),
            usage: .empty,
            now: now
        )

        #expect(ranked.map(\.section) == [.applications, .commands])
    }

    @Test func `favorites pin above higher-scoring results`() {
        let pinned = SearchResult.fixture(title: "Zebra")
        let popular = SearchResult.fixture(title: "Safari")
        let usage = UsageSnapshot(
            entries: [
                pinned.id: .init(count: 0, lastUsed: now, isFavorite: true, pinOrder: 0),
                popular.id: .init(count: 100, lastUsed: now),
            ]
        )

        let ranked = Ranking.rank(
            [popular, pinned],
            query: SearchQuery(raw: ""),
            usage: usage,
            now: now
        )

        #expect(ranked.first?.results.first?.title == "Zebra")
    }

    @Test func `identical inputs produce identical order`() {
        let results = [
            SearchResult.fixture(title: "Safari"),
            SearchResult.fixture(title: "Safe"),
            SearchResult.fixture(title: "Safely"),
        ]
        let query = SearchQuery(raw: "sa")

        let first = Ranking.rank(results, query: query, usage: .empty, now: now)
        let second = Ranking.rank(results.reversed(), query: query, usage: .empty, now: now)

        #expect(first == second)
    }
}
