import Foundation
import Testing

@testable import RillDomain

@Suite("SearchUseCase")
struct SearchUseCaseTests {
    @Test func `empty query returns the command catalogue`() async {
        let useCase = makeUseCase(
            commands: [.fixture(title: "Open Settings")],
            applications: [.fixture(title: "Safari", section: .applications)]
        )

        let sections = await useCase(SearchQuery(raw: ""))

        #expect(sections.map(\.section) == [.commands])
        #expect(sections.first?.results.map(\.title) == ["Open Settings"])
    }

    @Test func `matches commands and applications in section order`() async {
        let useCase = makeUseCase(
            commands: [.fixture(title: "Open Safari Tab")],
            applications: [.fixture(title: "Safari", section: .applications)]
        )

        let sections = await useCase(SearchQuery(raw: "saf"))

        #expect(sections.map(\.section) == [.commands, .applications])
        #expect(sections[0].results.map(\.title) == ["Open Safari Tab"])
        #expect(sections[1].results.map(\.title) == ["Safari"])
    }

    @Test func `empty sections are dropped`() async {
        let useCase = makeUseCase(
            commands: [.fixture(title: "Open Settings")],
            applications: [.fixture(title: "Safari", section: .applications)]
        )

        let sections = await useCase(SearchQuery(raw: "zzz"))

        #expect(sections.isEmpty)
    }

    @Test func `a recently used result is promoted`() async {
        let used = SearchResult.fixture(title: "Safari", section: .applications)
        let unused = SearchResult.fixture(title: "Safe", section: .applications)
        let usage = UsageSnapshot(
            entries: [used.id: .init(count: 3, lastUsed: Date(timeIntervalSince1970: 0))]
        )
        let useCase = makeUseCase(
            commands: [],
            applications: [unused, used],
            usage: usage
        )

        let sections = await useCase(SearchQuery(raw: "sa"))

        #expect(sections.first?.results.first?.title == "Safari")
    }

    private func makeUseCase(
        commands: [SearchResult],
        applications: [SearchResult],
        usage: UsageSnapshot = .empty
    ) -> SearchUseCase {
        SearchUseCase(
            commands: StubCommandProvider(commands: commands),
            applications: StubApplicationCatalog(apps: applications),
            usage: StubUsageStore(snapshotValue: usage),
            clock: FixedClock(now: Date(timeIntervalSince1970: 0))
        )
    }
}

private struct StubCommandProvider: CommandProviding {
    let commands: [SearchResult]
}

private struct StubApplicationCatalog: ApplicationCataloguing {
    let apps: [SearchResult]

    func applications() async -> [SearchResult] {
        apps
    }
}

private struct StubUsageStore: UsageStoring {
    let snapshotValue: UsageSnapshot

    func snapshot() async -> UsageSnapshot {
        snapshotValue
    }

    func record(_ id: SearchResult.ID, at date: Date) async {}
}

private struct FixedClock: RillDomain.Clock {
    let now: Date
}
