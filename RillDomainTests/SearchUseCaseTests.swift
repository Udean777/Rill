import Foundation
import Testing

@testable import RillDomain

@Suite("SearchUseCase")
struct SearchUseCaseTests {
    @Test func `empty query shows applications and commands`() async {
        let useCase = makeUseCase(
            commands: [.fixture(title: "Open Settings")],
            applications: [.fixture(title: "Safari", section: .applications, kind: .application, source: "application")]
        )

        let sections = await useCase(SearchQuery(raw: ""))

        #expect(sections.map(\.section) == [.applications, .commands])
        #expect(sections[0].results.map(\.title) == ["Safari"])
        #expect(sections[1].results.map(\.title) == ["Open Settings"])
    }

    @Test func `apps used in the last seven days are suggested`() async {
        let safari = SearchResult.fixture(
            title: "Safari", section: .applications, kind: .application, source: "application"
        )
        let notes = SearchResult.fixture(
            title: "Notes", section: .applications, kind: .application, source: "application"
        )
        let mail = SearchResult.fixture(
            title: "Mail", section: .applications, kind: .application, source: "application"
        )
        let now = Date(timeIntervalSince1970: 0)
        let usage = UsageSnapshot(
            entries: [
                safari.id: .init(count: 3, lastUsed: now.addingTimeInterval(-86_400)),
                notes.id: .init(count: 1, lastUsed: now.addingTimeInterval(-2 * 86_400)),
            ]
        )
        let useCase = makeUseCase(
            commands: [],
            applications: [safari, notes, mail],
            usage: usage
        )

        let sections = await useCase(SearchQuery(raw: ""))

        #expect(sections.map(\.section) == [.suggestions, .applications])
        #expect(sections[0].results.map(\.title) == ["Safari", "Notes"])
        #expect(sections[1].results.map(\.title) == ["Mail"])
    }

    @Test func `apps unused for over a week stay in applications`() async {
        let old = SearchResult.fixture(
            title: "Old", section: .applications, kind: .application, source: "application"
        )
        let now = Date(timeIntervalSince1970: 0)
        let usage = UsageSnapshot(
            entries: [old.id: .init(count: 9, lastUsed: now.addingTimeInterval(-10 * 86_400))]
        )
        let useCase = makeUseCase(commands: [], applications: [old], usage: usage)

        let sections = await useCase(SearchQuery(raw: ""))

        #expect(sections.map(\.section) == [.applications])
    }

    @Test func `suggestions are capped at five`() async {
        let now = Date(timeIntervalSince1970: 0)
        let apps = (0..<7).map { index in
            SearchResult.fixture(
                title: "App \(index)", section: .applications, kind: .application, source: "application"
            )
        }
        let usage = UsageSnapshot(
            entries: Dictionary(
                uniqueKeysWithValues: apps.map { app in
                    (app.id, UsageSnapshot.Entry(count: 1, lastUsed: now.addingTimeInterval(-86_400)))
                }
            )
        )
        let useCase = makeUseCase(commands: [], applications: apps, usage: usage)

        let sections = await useCase(SearchQuery(raw: ""))

        #expect(sections[0].section == .suggestions)
        #expect(sections[0].results.count == 5)
        #expect(sections[1].results.count == 2)
    }

    @Test func `matches commands and applications in section order`() async {
        let useCase = makeUseCase(
            commands: [.fixture(title: "Open Safari Tab")],
            applications: [.fixture(title: "Safari", section: .applications, kind: .application, source: "application")]
        )

        let sections = await useCase(SearchQuery(raw: "saf"))

        #expect(sections.map(\.section) == [.applications, .commands, .fallback])
        #expect(sections[0].results.map(\.title) == ["Safari"])
        #expect(sections[1].results.map(\.title) == ["Open Safari Tab"])
    }

    @Test func `empty sections are dropped`() async {
        let useCase = makeUseCase(
            commands: [.fixture(title: "Open Settings")],
            applications: []
        )

        let sections = await useCase(SearchQuery(raw: ""))

        #expect(sections.map(\.section) == [.commands])
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

        #expect(sections.map(\.section) == [.applications, .commands, .files, .fallback])
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

    @Test func `disabling file search suppresses file results`() async {
        let command = SearchResult.fixture(title: "Save File", section: .commands)
        let file = SearchResult.fixture(title: "Safety.pdf", section: .files, kind: .file)

        let useCase = makeUseCase(
            commands: [command],
            applications: [],
            files: [file],
            isFilesEnabled: { false }
        )

        let sections = await useCase(SearchQuery(raw: "saf"))

        #expect(sections.map(\.section) == [.commands, .fallback])
        #expect(!sections.contains(where: { $0.section == .files }))
    }

    @Test func `fallback contains calculation and web search when applicable`() async {
        let useCase = makeUseCase(
            commands: [],
            applications: []
        )

        let sections = await useCase(SearchQuery(raw: "12 * 4"))

        #expect(sections.map(\.section) == [.fallback])
        let fallbackResults = sections.first?.results ?? []
        #expect(fallbackResults.count == 2)
        #expect(fallbackResults[0].kind == .calculation)
        #expect(fallbackResults[0].title == "48")
        #expect(fallbackResults[1].kind == .web)
    }

    private func makeUseCase(
        commands: [SearchResult],
        applications: [SearchResult],
        files: [SearchResult] = [],
        usage: UsageSnapshot = .empty,
        isFilesEnabled: (@Sendable () async -> Bool)? = nil
    ) -> SearchUseCase {
        SearchUseCase(
            commands: StubCommandProvider(commands: commands),
            applications: StubApplicationCatalog(apps: applications),
            files: StubFileSearch(files: files),
            usage: StubUsageStore(snapshotValue: usage),
            clock: FixedClock(now: Date(timeIntervalSince1970: 0)),
            isFilesEnabled: isFilesEnabled
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
