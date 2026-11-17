import Foundation

/// Pure edits to the persisted Applications grid layout. Each method returns a
/// new layout; persisting and reloading stay with the caller.
public struct EditApplicationsLayoutUseCase: Sendable {
    public init() {}

    /// Materialises the currently resolved grid into a layout, so a first edit
    /// starts from what the user sees.
    public func materialized(
        _ layout: ApplicationsLayout,
        from nodes: [ApplicationsGridNode]
    ) -> ApplicationsLayout {
        ApplicationsLayout(
            entries: nodes.map(ApplicationsLayoutMapper.entry(for:)),
            hiddenAppIDs: layout.hiddenAppIDs
        )
    }

    public func moving(
        _ draggedID: String,
        to targetID: String,
        in layout: ApplicationsLayout
    ) -> ApplicationsLayout {
        var layout = layout
        guard let fromIndex = layout.entries.firstIndex(where: { $0.id == draggedID }),
              let toIndex = layout.entries.firstIndex(where: { $0.id == targetID }) else {
            return layout
        }
        let moved = layout.entries.remove(at: fromIndex)
        layout.entries.insert(moved, at: toIndex)
        return layout
    }

    public func creatingFolder(
        combining sourceID: String,
        with targetID: String,
        name: String,
        in layout: ApplicationsLayout
    ) -> ApplicationsLayout {
        var layout = layout
        guard let sourceEntry = layout.entries.first(where: { $0.id == sourceID }),
              let targetEntry = layout.entries.first(where: { $0.id == targetID }),
              let sourceRef = reference(for: sourceEntry),
              let targetIndex = layout.entries.firstIndex(where: { $0.id == targetID }) else {
            return layout
        }

        if case .folder(var existingFolder) = targetEntry {
            existingFolder.items.append(sourceRef)
            layout.entries[targetIndex] = .folder(existingFolder)
        } else if let targetRef = reference(for: targetEntry) {
            let folder = ApplicationFolder(
                name: name,
                items: [targetRef, sourceRef]
            )
            layout.entries[targetIndex] = .folder(folder)
        } else {
            return layout
        }
        layout.entries.removeAll { $0.id == sourceID }
        return layout
    }

    public func renamingFolder(
        _ folderID: UUID,
        to newName: String,
        in layout: ApplicationsLayout
    ) -> ApplicationsLayout {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return layout }

        var layout = layout
        guard let index = folderIndex(folderID, in: layout),
              case .folder(var folder) = layout.entries[index] else {
            return layout
        }
        folder.name = trimmed
        layout.entries[index] = .folder(folder)
        return layout
    }

    public func removingItem(
        _ itemID: String,
        fromFolder folderID: UUID,
        in layout: ApplicationsLayout
    ) -> ApplicationsLayout {
        var layout = layout
        guard let index = folderIndex(folderID, in: layout),
              case .folder(var folder) = layout.entries[index],
              let itemIndex = folder.items.firstIndex(where: { $0.stableID == itemID }) else {
            return layout
        }

        let removed = folder.items.remove(at: itemIndex)
        let restoredEntry: ApplicationGridEntry = switch removed {
        case .app(let appID): .app(id: appID)
        case .custom(let custom): .custom(custom)
        }
        if folder.items.isEmpty {
            layout.entries[index] = restoredEntry
        } else {
            layout.entries[index] = .folder(folder)
            layout.entries.insert(restoredEntry, at: min(index + 1, layout.entries.count))
        }
        return layout
    }

    public func settingHidden(
        _ appID: String,
        isHidden: Bool,
        in layout: ApplicationsLayout
    ) -> ApplicationsLayout {
        var layout = layout
        if isHidden {
            layout.hiddenAppIDs.insert(appID)
        } else {
            layout.hiddenAppIDs.remove(appID)
        }
        return layout
    }

    public func addingCustomItem(
        title: String,
        target: String,
        isWebURL: Bool,
        in layout: ApplicationsLayout
    ) -> ApplicationsLayout {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedTarget.isEmpty else { return layout }

        let normalizedTarget: String
        if isWebURL, let parsed = WebURLParser.parse(trimmedTarget) {
            normalizedTarget = parsed.absoluteString
        } else {
            normalizedTarget = trimmedTarget
        }

        var layout = layout
        let entry = CustomApplicationEntry(
            title: trimmedTitle,
            target: normalizedTarget,
            isWebURL: isWebURL,
            symbol: isWebURL ? "globe" : nil
        )
        layout.entries.insert(.custom(entry), at: 0)
        return layout
    }

    public func removingCustomItem(
        id: UUID,
        in layout: ApplicationsLayout
    ) -> ApplicationsLayout {
        var layout = layout
        layout.entries.removeAll {
            if case .custom(let custom) = $0 { return custom.id == id }
            return false
        }
        return layout
    }

    private func reference(
        for entry: ApplicationGridEntry
    ) -> ApplicationGridItemReference? {
        switch entry {
        case .app(let appID): .app(id: appID)
        case .custom(let custom): .custom(custom)
        case .folder: nil
        }
    }

    private func folderIndex(
        _ folderID: UUID,
        in layout: ApplicationsLayout
    ) -> Int? {
        layout.entries.firstIndex {
            if case .folder(let folder) = $0 { return folder.id == folderID }
            return false
        }
    }
}
