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

    @Test func `sub menu matches by title and by parent breadcrumb`() async throws {
        let useCase = makeUseCase()

        let byTitle = await useCase(SearchQuery(raw: "camera"))
        let titleSection = try #require(byTitle.first { $0.section == .systemSettings })
        #expect(titleSection.results.first?.title == "Camera")

        let byBreadcrumb = await useCase(SearchQuery(raw: "privacy camera"))
        let breadcrumbSection = try #require(byBreadcrumb.first { $0.section == .systemSettings })
        #expect(breadcrumbSection.results.contains { $0.title == "Camera" })
    }

    @Test func `constant system settings breadcrumb prefix does not match unrelated items`() async {
        let useCase = makeUseCase()

        let sections = await useCase(SearchQuery(raw: "system"))
        let settingsResults = sections.first { $0.section == .systemSettings }?.results ?? []
        #expect(!settingsResults.contains { $0.title == "Camera" })
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
    func settings() async -> [SearchResult] {
        var items: [SearchResult] = ["wallpaper", "privacy"].compactMap { raw in
            guard let url = URL(string: "x-apple.systempreferences:\(raw)") else {
                return nil
            }
            return SearchResult(
                id: .init(source: .systemSettings, raw: raw),
                title: raw.capitalized,
                icon: .systemSymbol("gearshape"),
                section: .systemSettings,
                kind: .systemSettings,
                primaryAction: .openURL(url)
            )
        }
        if let cameraURL = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Camera") {
            items.append(
                SearchResult(
                    id: .init(source: .systemSettings, raw: "privacy-camera"),
                    title: "Camera",
                    subtitle: "System Settings › Privacy & Security",
                    icon: .systemSymbol("camera"),
                    section: .systemSettings,
                    kind: .systemSettings,
                    primaryAction: .openURL(cameraURL)
                )
            )
        }
        return items
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
