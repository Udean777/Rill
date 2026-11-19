import Foundation
import Testing

@testable import RillData

@Suite("ApplicationCatalog")
struct ApplicationCatalogTests {
    @Test func `a newly installed app appears on the next search`() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("RillCatalog-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try makeApp(named: "Alpha", in: root)
        let catalog = ApplicationCatalog(roots: [root])
        let initial = await catalog.applications()
        #expect(initial.map(\.title) == ["Alpha"])

        try makeApp(named: "Beta", in: root)
        let installed = await catalog.applications()
        #expect(installed.map(\.title) == ["Alpha", "Beta"])

        try FileManager.default.removeItem(at: root.appendingPathComponent("Alpha.app"))
        let removed = await catalog.applications()
        #expect(removed.map(\.title) == ["Beta"])
    }

    @Test func `two copies of one bundle collapse to a single row`() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("RillCatalog-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try makeApp(named: "Alpha", identifier: "com.example.rill", in: root)
        try makeApp(named: "Beta", identifier: "com.example.rill", in: root)

        let apps = await ApplicationCatalog(roots: [root]).applications()

        #expect(apps.count == 1)
    }

    @Test func `the palette shows the install folder with a tilde for home`() {
        let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)

        #expect(
            ApplicationCatalog.displayPath(
                for: URL(fileURLWithPath: "/Users/tester/Applications/Rill.app"),
                home: home
            ) == "~/Applications"
        )
        #expect(
            ApplicationCatalog.displayPath(
                for: URL(fileURLWithPath: "/Applications/Rill.app"),
                home: home
            ) == "/Applications"
        )
    }

    @Test func `the system Applications folder wins a release duplicate`() {
        #expect(
            ApplicationCatalog.isPreferredLocation(
                "/Applications/Rill.app",
                over: "/Users/tester/Applications/Rill.app"
            )
        )
        #expect(
            !ApplicationCatalog.isPreferredLocation(
                "/Users/tester/Applications/Rill.app",
                over: "/Applications/Rill.app"
            )
        )
        #expect(
            !ApplicationCatalog.isPreferredLocation(
                "/Applications/Rill.app",
                over: "/Applications/Utilities/Rill.app"
            )
        )
    }

    private func makeApp(named name: String, identifier: String? = nil, in root: URL) throws {
        let bundle = root.appendingPathComponent("\(name).app", isDirectory: true)
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        guard let identifier else { return }
        let info: [String: Any] = [
            "CFBundleIdentifier": identifier,
            "CFBundleName": name,
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try data.write(to: bundle.appendingPathComponent("Info.plist"))
    }
}
