import Foundation
import RillDomain
import Testing

@Suite("EditApplicationsLayoutUseCase")
struct EditApplicationsLayoutUseCaseTests {
    private let editor = EditApplicationsLayoutUseCase()

    @Test func `moving an entry reorders the layout`() {
        let layout = ApplicationsLayout(entries: [
            .app(id: "Safari"), .app(id: "Notes"), .app(id: "Xcode"),
        ])

        let moved = editor.moving("app:Xcode", to: "app:Safari", in: layout)

        #expect(moved.entries.map(\.id) == ["app:Xcode", "app:Safari", "app:Notes"])
    }

    @Test func `combining two apps creates a folder and drops the source entry`() {
        let layout = ApplicationsLayout(entries: [.app(id: "Safari"), .app(id: "Notes")])

        let result = editor.creatingFolder(
            combining: "app:Notes", with: "app:Safari", name: "Work", in: layout
        )

        #expect(result.entries.count == 1)
        guard case .folder(let folder) = result.entries.first else {
            Issue.record("Expected a folder")
            return
        }
        #expect(folder.name == "Work")
        #expect(folder.items.map(\.stableID) == ["app:Safari", "app:Notes"])
    }

    @Test func `removing the only item from a folder restores it in place`() {
        let folderID = UUID()
        let layout = ApplicationsLayout(entries: [
            .app(id: "Safari"),
            .folder(ApplicationFolder(id: folderID, name: "Work", items: [.app(id: "Notes")])),
        ])

        let result = editor.removingItem("app:Notes", fromFolder: folderID, in: layout)

        #expect(result.entries.map(\.id) == ["app:Safari", "app:Notes"])
    }

    @Test func `materialising a grid round-trips custom items and keeps hidden apps`() throws {
        let customID = UUID()
        let url = try #require(URL(string: "https://github.com"))
        let nodes: [ApplicationsGridNode] = [
            .item(
                ApplicationGridItem(
                    id: "custom:\(customID.uuidString)",
                    customID: customID,
                    title: "GitHub",
                    subtitle: "github.com",
                    icon: .systemSymbol("globe"),
                    action: .openWebURL(url, browserBundleID: nil)
                )
            ),
            .item(
                ApplicationGridItem(
                    id: "app:Safari",
                    appID: "Safari",
                    title: "Safari",
                    icon: .systemSymbol("app"),
                    action: .openApplication(bundleID: "Safari")
                )
            ),
        ]
        let layout = ApplicationsLayout(hiddenAppIDs: ["Chess"])

        let materialised = editor.materialized(layout, from: nodes)

        #expect(materialised.hiddenAppIDs == ["Chess"])
        guard case .custom(let entry) = materialised.entries.first else {
            Issue.record("Expected a custom entry first")
            return
        }
        #expect(entry.id == customID)
        #expect(entry.title == "GitHub")
        #expect(entry.target == "https://github.com")
        #expect(entry.isWebURL)
    }

    @Test func `moving between folders keeps the entry order stable`() {
        let folderID = UUID()
        let layout = ApplicationsLayout(entries: [
            .folder(ApplicationFolder(id: folderID, name: "Work", items: [.app(id: "Xcode")])),
        ])

        let result = editor.moving("folder:\(folderID.uuidString)", to: "folder:\(folderID.uuidString)", in: layout)

        #expect(result.entries.map(\.id) == layout.entries.map(\.id))
    }
}

@Suite("ApplicationGridFilter")
struct ApplicationGridFilterTests {
    @Test func `prefix match outranks substring and non-matches drop out`() {
        let items = [
            makeItem(id: "app:Photoshop", title: "Photoshop"),
            makeItem(id: "app:Photos", title: "Photos"),
            makeItem(id: "app:Calendar", title: "Calendar"),
        ]

        let filtered = ApplicationGridFilter.filter(items, query: SearchQuery(raw: "photo"))

        #expect(filtered.map(\.title) == ["Photos", "Photoshop"])
    }

    private func makeItem(id: String, title: String) -> ApplicationGridItem {
        ApplicationGridItem(
            id: id,
            appID: String(id.dropFirst(4)),
            title: title,
            icon: .systemSymbol("app"),
            action: .openApplication(bundleID: id)
        )
    }
}
