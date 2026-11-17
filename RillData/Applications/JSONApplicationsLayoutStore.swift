import Foundation
import os
import RillDomain

/// Persists custom Applications grid layout, folders, hidden apps, and
/// custom links as a JSON snapshot under Application Support.
public actor JSONApplicationsLayoutStore: ApplicationsLayoutStoring {
    private let store: JSONFileStore<ApplicationsLayout>
    private var cached: ApplicationsLayout?

    public init(fileURL: URL = JSONApplicationsLayoutStore.defaultFileURL()) {
        self.store = JSONFileStore(
            fileURL: fileURL,
            outputFormatting: [.prettyPrinted, .sortedKeys],
            log: Logger(subsystem: "com.ssajudn.Rill", category: "store"),
            name: "applications layout"
        )
    }

    public static func defaultFileURL() -> URL {
        AppSupportDirectory.file("applications-layout.json")
    }

    public func load() async -> ApplicationsLayout {
        if let cached {
            return cached
        }
        let decoded = store.read() ?? .empty
        cached = decoded
        return decoded
    }

    public func save(_ layout: ApplicationsLayout) async {
        cached = layout
        store.write(layout)
    }

    public func reset() async {
        cached = .empty
        store.removeFile()
    }
}
