import Foundation
import Testing

@testable import RillDomain

@Suite("SystemSettings")
struct SystemSettingsTests {
    @Test func `a system settings query yields its own section`() async throws {
        let useCase = makeUseCase()

        let sections = await useCase(SearchQuery(raw: "wallpaper"))

        let section = try #require(sections.first { $0.section == .systemSettings })
        let row = try #require(section.results.first)
        #expect(row.kind == .systemSettings)
        guard case .openURL(let url) = row.primaryAction else {
            Issue.record("expected an URL action")
            return
        }
        #expect(url.scheme == "x-apple.systempreferences")
    }

    @Test func `the root layout stays free of system settings`() async {
        let sections = await makeUseCase()(SearchQuery(raw: ""))

        #expect(!sections.contains { $0.section == .systemSettings })
    }

    @Test func `an unrelated query hides system settings`() async {
        let sections = await makeUseCase()(SearchQuery(raw: "safari"))

        #expect(!sections.contains { $0.section == .systemSettings })
    }

    private func makeUseCase() -> SearchUseCase {
        SearchUseCase(
            commands: EmptyCommands(),
            applications: EmptyApplications(),
            usage: EmptyUsage(),
            clock: FixedClock(now: Date(timeIntervalSince1970: 0)),
            systemSettings: FakeSystemSettings()
        )
    }
}

private struct FakeSystemSettings: SystemSettingsProviding {
    var settings: [SearchResult] {
        ["wallpaper", "privacy"].compactMap { raw in
            guard let url = URL(string: "x-apple.systempreferences:\(raw)") else {
                return nil
            }
            return SearchResult(
                id: .init(source: "system-settings", raw: raw),
                title: raw.capitalized,
                icon: .systemSymbol("gearshape"),
                section: .systemSettings,
                kind: .systemSettings,
                primaryAction: .openURL(url)
            )
        }
    }
}

private struct EmptyCommands: CommandProviding {
    var commands: [SearchResult] { [] }
}

private struct EmptyApplications: ApplicationCataloguing {
    func applications() async -> [SearchResult] { [] }
}

private struct EmptyUsage: UsageStoring {
    func snapshot() async -> UsageSnapshot { .empty }
    func record(_ id: SearchResult.ID, at date: Date) async {}
    func pinned() async -> [PinnedResult] { [] }
    func setPinned(_ result: SearchResult, isPinned: Bool, at date: Date) async {}
    func clearPins() async {}
    func reset() async {}
}

private struct FixedClock: RillDomain.Clock {
    let now: Date
}
