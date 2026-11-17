import Foundation
import RillData
import RillDomain
import Testing

@Suite("JSONApplicationsLayoutStore")
struct JSONApplicationsLayoutStoreTests {
    @Test func `saves loads and resets layout atomically`() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RillLayoutTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("applications-layout.json")
        let store = JSONApplicationsLayoutStore(fileURL: fileURL)

        let initial = await store.load()
        #expect(initial == .empty)

        let folderID = UUID()
        let layout = ApplicationsLayout(
            entries: [
                .app(id: "com.apple.Safari"),
                .folder(ApplicationFolder(id: folderID, name: "Dev", items: [.app(id: "com.apple.dt.Xcode")])),
            ],
            hiddenAppIDs: ["com.apple.Chess"]
        )
        await store.save(layout)

        let reloaded = await JSONApplicationsLayoutStore(fileURL: fileURL).load()
        #expect(reloaded == layout)

        await store.reset()
        let afterReset = await JSONApplicationsLayoutStore(fileURL: fileURL).load()
        #expect(afterReset == .empty)
    }
}
