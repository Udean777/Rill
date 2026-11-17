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
        var pinTitle: String? = nil
        var pinSubtitle: String? = nil
        var pinPath: String? = nil
    }

    private static let keySeparator: Character = "\u{1F}"

    private let store: JSONFileStore<[String: Entry]>
    private var stored: [String: Entry]?
    private var cachedSnapshot: UsageSnapshot?

    public init(fileURL: URL = JSONUsageStore.defaultFileURL()) {
        self.store = JSONFileStore(
            fileURL: fileURL,
            dateEncodingStrategy: .iso8601,
            dateDecodingStrategy: .iso8601,
            log: Logger(subsystem: "com.ssajudn.Rill", category: "store"),
            name: "usage"
        )
    }

    public static func defaultFileURL() -> URL {
        AppSupportDirectory.file("usage.json")
    }

    public func snapshot() async -> UsageSnapshot {
        if let cachedSnapshot {
            return cachedSnapshot
        }

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

        let snapshot = UsageSnapshot(entries: entries)
        cachedSnapshot = snapshot
        return snapshot
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
        cachedSnapshot = nil
        persist(current)
    }

    /// Pinned rows in pin order. Files whose path no longer exists are dropped,
    /// but their entries stay on disk so a restored file reappears.
    ///
    /// shortcut: one `fileExists` per pin on every search, cache existence if
    /// pin counts reach the hundreds.
    public func pinned() async -> [PinnedResult] {
        var results: [PinnedResult] = []

        for (key, entry) in loaded() {
            guard entry.isFavorite, let id = Self.identifier(from: key) else { continue }

            var fileURL: URL?
            if let path = entry.pinPath {
                guard FileManager.default.fileExists(atPath: path) else { continue }
                fileURL = URL(fileURLWithPath: path)
            }

            results.append(
                PinnedResult(
                    id: id,
                    title: entry.pinTitle ?? id.raw,
                    subtitle: entry.pinSubtitle,
                    fileURL: fileURL,
                    pinOrder: entry.pinOrder ?? Int.max
                )
            )
        }

        return results.sorted { $0.pinOrder < $1.pinOrder }
    }

    public func setPinned(_ result: SearchResult, isPinned: Bool, at date: Date) async {
        let key = Self.key(for: result.id)
        var current = loaded()
        var entry =
            current[key]
            ?? Entry(count: 0, lastUsed: date, isFavorite: false, pinOrder: nil)

        if isPinned {
            entry.isFavorite = true
            entry.pinOrder = entry.pinOrder ?? Self.nextPinOrder(in: current)
            entry.pinTitle = result.title
            entry.pinSubtitle = result.subtitle
            if case .fileURL(let url) = result.icon {
                entry.pinPath = url.path
            }
        } else {
            entry.isFavorite = false
            entry.pinOrder = nil
            entry.pinTitle = nil
            entry.pinSubtitle = nil
            entry.pinPath = nil
        }

        current[key] = entry
        stored = current
        cachedSnapshot = nil
        persist(current)
    }

    private static func nextPinOrder(in entries: [String: Entry]) -> Int {
        (entries.values.compactMap(\.pinOrder).max() ?? -1) + 1
    }

    public func clearPins() async {
        var current = loaded()
        guard current.values.contains(where: \.isFavorite) else { return }

        current = current.mapValues { entry in
            var entry = entry
            entry.isFavorite = false
            entry.pinOrder = nil
            entry.pinTitle = nil
            entry.pinSubtitle = nil
            entry.pinPath = nil
            return entry
        }

        stored = current
        cachedSnapshot = nil
        persist(current)
    }

    /// Deletes the snapshot and drops every in-memory copy. The next `record`
    /// writes a fresh file.
    public func reset() async {
        stored = [:]
        cachedSnapshot = .empty
        store.removeFile()
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
        store.read() ?? [:]
    }

    private func persist(_ entries: [String: Entry]) {
        store.write(entries)
    }

    private static func key(for id: SearchResult.ID) -> String {
        "\(id.source.rawValue)\(keySeparator)\(id.raw)"
    }

    private static func identifier(from key: String) -> SearchResult.ID? {
        guard let separatorIndex = key.firstIndex(of: keySeparator) else { return nil }

        return SearchResult.ID(
            source: SearchResult.Source(rawValue: String(key[..<separatorIndex])),
            raw: String(key[key.index(after: separatorIndex)...])
        )
    }
}
