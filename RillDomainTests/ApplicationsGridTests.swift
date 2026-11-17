import Foundation
import RillDomain
import Testing

@Suite("LoadApplicationsGridUseCase")
struct ApplicationsGridTests {
    @Test func `preserves custom order folders hidden apps and appends new apps`() async {
        let safari = appResult(id: "com.apple.Safari", title: "Safari")
        let notes = appResult(id: "com.apple.Notes", title: "Notes")
        let xcode = appResult(id: "com.apple.dt.Xcode", title: "Xcode")
        let hidden = appResult(id: "com.apple.Chess", title: "Chess")
        let newlyInstalled = appResult(id: "com.apple.Terminal", title: "Terminal")

        let folderID = UUID()
        let customID = UUID()
        let layout = ApplicationsLayout(
            entries: [
                .custom(CustomApplicationEntry(id: customID, title: "GitHub", target: "https://github.com", isWebURL: true)),
                .folder(ApplicationFolder(id: folderID, name: "Work", items: [.app(id: "com.apple.dt.Xcode"), .app(id: "com.apple.Notes")])),
                .app(id: "com.apple.Safari"),
                .app(id: "com.apple.DeletedApp"),
            ],
            hiddenAppIDs: ["com.apple.Chess"]
        )

        let useCase = LoadApplicationsGridUseCase(
            applications: StubApps(apps: [safari, notes, xcode, hidden, newlyInstalled]),
            layoutStore: InMemoryLayoutStore(layout: layout),
            preferences: { Preferences(defaultBrowserBundleID: "com.google.Chrome") }
        )

        let output = await useCase()

        #expect(output.hiddenApplications.map(\.title) == ["Chess"])
        #expect(output.nodes.count == 4)
        #expect(output.nodes[0].title == "GitHub")
        #expect(output.nodes[1].title == "Work")
        #expect(output.nodes[2].title == "Safari")
        #expect(output.nodes[3].title == "Terminal")

        if case .folder(_, let name, let items) = output.nodes[1] {
            #expect(name == "Work")
            #expect(items.map(\.title) == ["Xcode", "Notes"])
        } else {
            Issue.record("Expected Work folder at index 1")
        }
    }

    private func appResult(id: String, title: String) -> SearchResult {
        SearchResult(
            id: .init(source: .application, raw: id),
            title: title,
            subtitle: "/Applications",
            icon: .systemSymbol("app"),
            section: .applications,
            kind: .application,
            primaryAction: .openApplication(bundleID: id)
        )
    }
}

private struct StubApps: ApplicationCataloguing {
    let apps: [SearchResult]
    func applications() async -> [SearchResult] { apps }
}

private actor InMemoryLayoutStore: ApplicationsLayoutStoring {
    private var layout: ApplicationsLayout
    init(layout: ApplicationsLayout) { self.layout = layout }
    func load() async -> ApplicationsLayout { layout }
    func save(_ layout: ApplicationsLayout) async { self.layout = layout }
    func reset() async { layout = .empty }
}
