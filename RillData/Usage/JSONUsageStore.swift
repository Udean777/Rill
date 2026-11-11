import Foundation
import os
import RillDomain

/// Persists usage as one JSON snapshot under Application Support.
///
/// Writes are atomic and happen on every record: executions are human-paced,
/// so there is nothing to batch.
///
/// shortcut: write-through on every record with no quit hook, add coalescing
/// if executions ever become automated or batched.
public actor JSONUsageStore: UsageStoring {
    private struct Entry: Codable {
        var count: Int
        var lastUsed: Date
        var isFavorite: Bool
        var pinOrder: Int?
    }

    private static let keySeparator: Character = "\u{1F}"

    private let fileURL: URL
    private let log = Logger(subsystem: "com.ssajudn.Rill", category: "store")
    private var stored: [String: Entry]?

    public init(fileURL: URL = JSONUsageStore.defaultFileURL()) {
        self.fileURL = fileURL
    }

    public static func defaultFileURL() -> URL {
        let base =
            FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)

        return base
            .appendingPathComponent("Rill", isDirectory: true)
            .appendingPathComponent("usage.json", isDirectory: false)
    }

    public func snapshot() async -> UsageSnapshot {
        var entries: [SearchResult.ID: UsageSnapshot.Entry] = [:]

        for (key, entry) in loaded() {
            guard let id = Self.identifier(from: key) else { continue }
            entries[id] = UsageSnapshot.Entry(
                count: entry.count,
                lastUsed: entry.lastUsed,
                isFavorite: entry.isFavorite,
                pinOrder: entry.pinOrder
            )
        }

        return UsageSnapshot(entries: entries)
    }

    public func record(_ id: SearchResult.ID, at date: Date) async {
        let key = Self.key(for: id)
        var current = loaded()

        var entry =
            current[key]
            ?? Entry(count: 0, lastUsed: date, isFavorite: false, pinOrder: nil)
        entry.count += 1
        entry.lastUsed = date
        current[key] = entry

        stored = current
        persist(current)
    }

    private func loaded() -> [String: Entry] {
        if let stored {
            return stored
        }
        let read = read()
        stored = read
        return read
    }

    private func read() -> [String: Entry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [:] }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([String: Entry].self, from: data)
        } catch {
            log.error("usage read failed: \(String(describing: error), privacy: .public)")
            return [:]
        }
    }

    private func persist(_ entries: [String: Entry]) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            log.error("usage write failed: \(String(describing: error), privacy: .public)")
        }
    }

    private static func key(for id: SearchResult.ID) -> String {
        "\(id.source)\(keySeparator)\(id.raw)"
    }

    private static func identifier(from key: String) -> SearchResult.ID? {
        guard let separatorIndex = key.firstIndex(of: keySeparator) else { return nil }

        return SearchResult.ID(
            source: String(key[..<separatorIndex]),
            raw: String(key[key.index(after: separatorIndex)...])
        )
    }
}
