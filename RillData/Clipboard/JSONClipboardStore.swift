import Foundation
import os
import RillDomain

/// Persists clipboard history to a JSON index file and stores image payloads
/// as individual files under Application Support.
public actor JSONClipboardStore: ClipboardStoring {
    private let fileURL: URL
    private let imagesDirectoryURL: URL
    private let maxLimit: Int
    private let log = Logger(subsystem: "com.ssajudn.Rill", category: "clipboardStore")

    private var itemsCache: [ClipboardItem]?

    public init(
        fileURL: URL = JSONClipboardStore.defaultFileURL(),
        imagesDirectoryURL: URL = JSONClipboardStore.defaultImagesDirectoryURL(),
        maxLimit: Int = 500
    ) {
        self.fileURL = fileURL
        self.imagesDirectoryURL = imagesDirectoryURL
        self.maxLimit = maxLimit
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
            .appendingPathComponent("clipboard.json", isDirectory: false)
    }

    public static func defaultImagesDirectoryURL() -> URL {
        let base =
            FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)

        return base
            .appendingPathComponent("Rill", isDirectory: true)
            .appendingPathComponent("ClipboardImages", isDirectory: true)
    }

    public func items(matching query: String, filter: ClipboardFilter, limit: Int) async -> [ClipboardItem] {
        let all = loaded()
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return all
            .filter { item in
                let matchesFilter: Bool
                switch filter {
                case .all: matchesFilter = true
                case .text: matchesFilter = item.contentType == .text
                case .code: matchesFilter = item.contentType == .code
                case .images: matchesFilter = item.contentType == .image
                case .links: matchesFilter = item.contentType == .link
                case .colors: matchesFilter = item.contentType == .color
                case .files: matchesFilter = item.contentType == .files
                case .pinned: matchesFilter = item.isPinned
                }

                guard matchesFilter else { return false }
                guard !normalizedQuery.isEmpty else { return true }

                if let text = item.textContent?.lowercased(), text.contains(normalizedQuery) {
                    return true
                }
                if let appName = item.sourceApp?.name.lowercased(), appName.contains(normalizedQuery) {
                    return true
                }
                if let hex = item.metadata.colorHex?.lowercased(), hex.contains(normalizedQuery) {
                    return true
                }
                if let lang = item.metadata.codeLanguage?.lowercased(), lang.contains(normalizedQuery) {
                    return true
                }
                return false
            }
            .prefix(limit)
            .map { $0 }
    }

    public func save(_ item: ClipboardItem) async {
        var current = loaded()

        // Deduplication: if the exact same content exists at the very top, update timestamp
        if let first = current.first,
           first.textContent == item.textContent,
           first.contentType == item.contentType,
           first.metadata.imageFileName == item.metadata.imageFileName {
            var updated = first
            updated.isPinned = first.isPinned || item.isPinned
            current[0] = updated
            itemsCache = current
            persist(current)
            return
        }

        // If duplicate exists elsewhere in history, remove old instance so newest is on top
        if let existingIndex = current.firstIndex(where: {
            $0.textContent == item.textContent &&
            $0.contentType == item.contentType &&
            $0.metadata.imageFileName == item.metadata.imageFileName
        }) {
            let wasPinned = current[existingIndex].isPinned
            var newItem = item
            newItem.isPinned = wasPinned || item.isPinned
            current.remove(at: existingIndex)
            current.insert(newItem, at: 0)
        } else {
            current.insert(item, at: 0)
        }

        // Enforce max history limit, protecting pinned items
        current = prune(current)

        itemsCache = current
        persist(current)
    }

    public func delete(id: ClipboardItem.ID) async {
        var current = loaded()
        if let idx = current.firstIndex(where: { $0.id == id }) {
            let removed = current.remove(at: idx)
            // If it had an image file, clean it up
            if let imageFileName = removed.metadata.imageFileName {
                deleteImageFile(named: imageFileName)
            }
            itemsCache = current
            persist(current)
        }
    }

    public func togglePin(id: ClipboardItem.ID) async {
        var current = loaded()
        if let idx = current.firstIndex(where: { $0.id == id }) {
            current[idx].isPinned.toggle()
            itemsCache = current
            persist(current)
        }
    }

    public func clearHistory(keepingPinned: Bool) async {
        var current = loaded()
        if keepingPinned {
            let removed = current.filter { !$0.isPinned }
            for item in removed {
                if let imageFileName = item.metadata.imageFileName {
                    deleteImageFile(named: imageFileName)
                }
            }
            current = current.filter { $0.isPinned }
        } else {
            for item in current {
                if let imageFileName = item.metadata.imageFileName {
                    deleteImageFile(named: imageFileName)
                }
            }
            current.removeAll()
        }
        itemsCache = current
        persist(current)
    }

    public func itemCount() async -> Int {
        loaded().count
    }

    // MARK: - Internals

    private func prune(_ items: [ClipboardItem]) -> [ClipboardItem] {
        guard items.count > maxLimit else { return items }

        var result: [ClipboardItem] = []
        var unpinnedCount = 0

        for item in items {
            if item.isPinned {
                result.append(item)
            } else if unpinnedCount < maxLimit {
                result.append(item)
                unpinnedCount += 1
            } else {
                // Pruned item: clean up image file if present
                if let imageFileName = item.metadata.imageFileName {
                    deleteImageFile(named: imageFileName)
                }
            }
        }
        return result
    }

    private func loaded() -> [ClipboardItem] {
        if let itemsCache {
            return itemsCache
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            itemsCache = []
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let items = try JSONDecoder().decode([ClipboardItem].self, from: data)
            itemsCache = items
            return items
        } catch {
            log.error("failed to decode clipboard store: \(String(describing: error), privacy: .public)")
            itemsCache = []
            return []
        }
    }

    private func persist(_ items: [ClipboardItem]) {
        do {
            let directory = fileURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            log.error("failed to persist clipboard store: \(String(describing: error), privacy: .public)")
        }
    }

    private func deleteImageFile(named fileName: String) {
        let imageFileURL = imagesDirectoryURL.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: imageFileURL)
    }
}
