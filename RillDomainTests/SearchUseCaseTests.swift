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

    @Test func `includes file results in section order below applications`() async {
        let command = SearchResult.fixture(title: "Save File", section: .commands)
        let app = SearchResult.fixture(title: "Safari", section: .applications)
        let file = SearchResult.fixture(title: "Safety.pdf", section: .files, kind: .file)

        let useCase = makeUseCase(
            commands: [command],
            applications: [app],
            files: [file]
        )

        let sections = await useCase(SearchQuery(raw: "saf"))

        #expect(sections.map(\.section) == [.commands, .applications, .files])
        #expect(sections[2].results.map(\.title) == ["Safety.pdf"])
    }

    @Test func `empty query does not invoke file search`() async {
        let file = SearchResult.fixture(title: "Safety.pdf", section: .files, kind: .file)
        let useCase = makeUseCase(
            commands: [.fixture(title: "Open Settings")],
            applications: [],
            files: [file]
        )

        let sections = await useCase(SearchQuery(raw: ""))

        #expect(sections.map(\.section) == [.commands])
    }

    private func makeUseCase(
        commands: [SearchResult],
        applications: [SearchResult],
        files: [SearchResult] = [],
        usage: UsageSnapshot = .empty
    ) -> SearchUseCase {
        SearchUseCase(
            commands: StubCommandProvider(commands: commands),
            applications: StubApplicationCatalog(apps: applications),
            files: StubFileSearch(files: files),
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

private struct StubFileSearch: FileSearching {
    let files: [SearchResult]

    func search(query: SearchQuery) async -> [SearchResult] {
        files.filter { MatchScore.score(title: $0.title, query: query) > 0 }
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
