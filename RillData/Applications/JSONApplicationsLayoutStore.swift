import Foundation
import os
import RillDomain

/// Persists custom Applications grid layout, folders, hidden apps, and
/// custom links as a JSON snapshot under Application Support.
public actor JSONApplicationsLayoutStore: ApplicationsLayoutStoring {
    private let fileURL: URL
    private let log = Logger(subsystem: "com.ssajudn.Rill", category: "store")
    private var cached: ApplicationsLayout?

    public init(fileURL: URL = JSONApplicationsLayoutStore.defaultFileURL()) {
        self.fileURL = fileURL
    }

    public static func defaultFileURL() -> URL {
        AppSupportDirectory.file("applications-layout.json")
    }

    public func load() async -> ApplicationsLayout {
        if let cached {
            return cached
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            cached = .empty
            return .empty
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(ApplicationsLayout.self, from: data)
            cached = decoded
            return decoded
        } catch {
            log.error("failed to read applications layout: \(error.localizedDescription, privacy: .public)")
            cached = .empty
            return .empty
        }
    }

    public func save(_ layout: ApplicationsLayout) async {
        cached = layout
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(layout)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            log.error("failed to save applications layout: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func reset() async {
        cached = .empty
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            log.error("failed to reset applications layout: \(error.localizedDescription, privacy: .public)")
        }
    }
}
