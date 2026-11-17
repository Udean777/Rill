import Foundation
import Observation
import RillDomain

/// Presentation state and customisation actions for the floating Applications
/// grid launcher.
@MainActor
@Observable
public final class ApplicationsGridViewModel {
    public private(set) var nodes: [ApplicationsGridNode] = []
    public private(set) var hiddenApplications: [ApplicationGridItem] = []
    public private(set) var filteredItems: [ApplicationGridItem] = []
    public var query: String = "" {
        didSet {
            currentPage = 0
            rebuildFilteredItems()
            clampSelection()
        }
    }
    public var currentPage: Int = 0
    public var selectedID: String?
    public var openFolderID: UUID?
    public var isVisible: Bool = false

    public var columns: Int = Preferences.default.applicationsGridColumns
    public var rows: Int = Preferences.default.applicationsGridRows

    @ObservationIgnored public var onRequestHide: (() -> Void)?
    @ObservationIgnored public var onExecute: ((SearchResult) -> Void)?

    @ObservationIgnored private let loadUseCase: LoadApplicationsGridUseCase
    @ObservationIgnored private let layoutStore: ApplicationsLayoutStoring

    public init(
        loadUseCase: LoadApplicationsGridUseCase,
        layoutStore: ApplicationsLayoutStoring
    ) {
        self.loadUseCase = loadUseCase
        self.layoutStore = layoutStore
    }

    public var pageSize: Int {
        max(1, columns * rows)
    }

    public var isFiltering: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func rebuildFilteredItems() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            filteredItems = []
            return
        }
        let searchQuery = SearchQuery(raw: trimmed)
        let allItems: [ApplicationGridItem] = nodes.flatMap { node in
            switch node {
            case .item(let item): [item]
            case .folder(_, _, let items): items
            }
        }
        filteredItems = allItems
            .compactMap { item -> (item: ApplicationGridItem, score: Double)? in
                let score = MatchScore.score(title: item.title, query: searchQuery)
                return score > 0 ? (item, score) : nil
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.item.title.localizedCaseInsensitiveCompare(rhs.item.title) == .orderedAscending
            }
            .map(\.item)
    }

    public var pageCount: Int {
        max(1, Int(ceil(Double(nodes.count) / Double(pageSize))))
    }

    public var pagedNodes: [ApplicationsGridNode] {
        guard !nodes.isEmpty else { return [] }
        let safePage = min(max(0, currentPage), pageCount - 1)
        let start = safePage * pageSize
        let end = min(start + pageSize, nodes.count)
        guard start < end else { return [] }
        return Array(nodes[start..<end])
    }

    public var openFolder: (id: UUID, name: String, items: [ApplicationGridItem])? {
        guard let openFolderID else { return nil }
        for node in nodes {
            if case .folder(let id, let name, let items) = node, id == openFolderID {
                return (id, name, items)
            }
        }
        return nil
    }

    public func show() {
        isVisible = true
        query = ""
        openFolderID = nil
        Task {
            await reload()
        }
    }

    public func reload() async {
        let output = await loadUseCase()
        if nodes != output.nodes {
            nodes = output.nodes
            rebuildFilteredItems()
            let firstPageResults = nodes.prefix(pageSize).flatMap { node -> [SearchResult] in
                switch node {
                case .item(let item): [item.asSearchResult]
                case .folder(_, _, let items): items.prefix(4).map(\.asSearchResult)
                }
            }
            IconCache.shared.prewarm(firstPageResults)
        }
        if hiddenApplications != output.hiddenApplications {
            hiddenApplications = output.hiddenApplications
        }
        let clampedPage = min(max(0, currentPage), pageCount - 1)
        if clampedPage != currentPage {
            currentPage = clampedPage
        }
        clampSelection()
    }

    public func resetTransientState() {
        query = ""
        openFolderID = nil
        selectedID = nil
    }

    public func apply(preferences: Preferences) {
        columns = preferences.applicationsGridColumns
        rows = preferences.applicationsGridRows
        currentPage = min(max(0, currentPage), pageCount - 1)
    }

    // MARK: - Navigation & Execution

    public func changePage(by delta: Int) {
        let next = min(max(0, currentPage + delta), pageCount - 1)
        guard next != currentPage else { return }
        currentPage = next
        clampSelection()
    }

    public func moveSelection(dx: Int, dy: Int) {
        let visibleIDs = currentVisibleIDs()
        guard !visibleIDs.isEmpty else { return }

        let currentIndex = selectedID.flatMap { visibleIDs.firstIndex(of: $0) } ?? 0
        let step = dx + (dy * columns)
        let targetIndex = currentIndex + step

        if targetIndex < 0 {
            if !isFiltering && openFolderID == nil && currentPage > 0 {
                changePage(by: -1)
                selectedID = currentVisibleIDs().last
            }
            return
        }
        if targetIndex >= visibleIDs.count {
            if !isFiltering && openFolderID == nil && currentPage < pageCount - 1 {
                changePage(by: 1)
                selectedID = currentVisibleIDs().first
            }
            return
        }
        selectedID = visibleIDs[targetIndex]
    }

    /// - Returns: `true` when Escape should dismiss the panel.
    @discardableResult
    public func handleEscape() -> Bool {
        if openFolderID != nil {
            openFolderID = nil
            clampSelection()
            return false
        }
        if !query.isEmpty {
            query = ""
            return false
        }
        return true
    }

    public func activateSelected() {
        if isFiltering {
            let items = filteredItems
            let target = items.first { $0.id == selectedID } ?? items.first
            if let target {
                execute(item: target)
            }
            return
        }
        if let folder = openFolder {
            let target = folder.items.first { $0.id == selectedID } ?? folder.items.first
            if let target {
                execute(item: target)
            }
            return
        }
        let pageNodes = pagedNodes
        let targetNode = pageNodes.first { $0.id == selectedID } ?? pageNodes.first
        guard let targetNode else { return }
        switch targetNode {
        case .item(let item):
            execute(item: item)
        case .folder(let id, _, _):
            openFolderID = id
            selectedID = openFolder?.items.first?.id
        }
    }

    public func execute(item: ApplicationGridItem) {
        onExecute?(item.asSearchResult)
    }

    private func currentVisibleIDs() -> [String] {
        if isFiltering {
            return filteredItems.map(\.id)
        }
        if let folder = openFolder {
            return folder.items.map(\.id)
        }
        return pagedNodes.map(\.id)
    }

    private func clampSelection() {
        let visibleIDs = currentVisibleIDs()
        if let selectedID, visibleIDs.contains(selectedID) {
            return
        }
        selectedID = visibleIDs.first
    }

    // MARK: - Customisation Persistence

    public func moveNode(draggedID: String, to targetID: String) {
        guard draggedID != targetID, !isFiltering else { return }
        Task {
            var layout = await syncedLayout()
            guard let fromIndex = layout.entries.firstIndex(where: { $0.id == draggedID }),
                  let toIndex = layout.entries.firstIndex(where: { $0.id == targetID }) else {
                return
            }
            let moved = layout.entries.remove(at: fromIndex)
            layout.entries.insert(moved, at: toIndex)
            await layoutStore.save(layout)
            await reload()
        }
    }

    public func createFolder(combining sourceID: String, with targetID: String, name: String) {
        guard sourceID != targetID else { return }
        Task {
            var layout = await syncedLayout()
            guard let sourceEntry = layout.entries.first(where: { $0.id == sourceID }),
                  let targetEntry = layout.entries.first(where: { $0.id == targetID }),
                  let sourceRef = itemReference(from: sourceEntry) else {
                return
            }

            if case .folder(var existingFolder) = targetEntry,
               let targetIndex = layout.entries.firstIndex(where: { $0.id == targetID }) {
                existingFolder.items.append(sourceRef)
                layout.entries[targetIndex] = .folder(existingFolder)
                layout.entries.removeAll { $0.id == sourceID }
            } else if let targetRef = itemReference(from: targetEntry),
                      let targetIndex = layout.entries.firstIndex(where: { $0.id == targetID }) {
                let folder = ApplicationFolder(
                    name: name.isEmpty ? String(localized: "Folder") : name,
                    items: [targetRef, sourceRef]
                )
                layout.entries[targetIndex] = .folder(folder)
                layout.entries.removeAll { $0.id == sourceID }
            }
            await layoutStore.save(layout)
            await reload()
        }
    }

    public func renameFolder(_ folderID: UUID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            var layout = await syncedLayout()
            guard let index = layout.entries.firstIndex(where: {
                if case .folder(let folder) = $0 { return folder.id == folderID }
                return false
            }),
            case .folder(var folder) = layout.entries[index] else {
                return
            }
            folder.name = trimmed
            layout.entries[index] = .folder(folder)
            await layoutStore.save(layout)
            await reload()
        }
    }

    public func removeItem(_ itemID: String, fromFolder folderID: UUID) {
        Task {
            var layout = await syncedLayout()
            guard let index = layout.entries.firstIndex(where: {
                if case .folder(let folder) = $0 { return folder.id == folderID }
                return false
            }),
            case .folder(var folder) = layout.entries[index],
            let itemIndex = folder.items.firstIndex(where: { $0.stableID == itemID }) else {
                return
            }
            let removed = folder.items.remove(at: itemIndex)
            let restoredEntry: ApplicationGridEntry = switch removed {
            case .app(let appID): .app(id: appID)
            case .custom(let custom): .custom(custom)
            }
            if folder.items.isEmpty {
                layout.entries[index] = restoredEntry
                openFolderID = nil
            } else {
                layout.entries[index] = .folder(folder)
                layout.entries.insert(restoredEntry, at: min(index + 1, layout.entries.count))
            }
            await layoutStore.save(layout)
            await reload()
        }
    }

    public func hideApplication(appID: String) {
        Task {
            var layout = await syncedLayout()
            layout.hiddenAppIDs.insert(appID)
            await layoutStore.save(layout)
            await reload()
        }
    }

    public func unhideApplication(appID: String) {
        Task {
            var layout = await syncedLayout()
            layout.hiddenAppIDs.remove(appID)
            await layoutStore.save(layout)
            await reload()
        }
    }

    public func addCustomItem(title: String, target: String, isWebURL: Bool) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedTarget.isEmpty else { return }

        let normalizedTarget: String
        if isWebURL, let parsed = WebURLParser.parse(trimmedTarget) {
            normalizedTarget = parsed.absoluteString
        } else {
            normalizedTarget = trimmedTarget
        }

        Task {
            var layout = await syncedLayout()
            let entry = CustomApplicationEntry(
                title: trimmedTitle,
                target: normalizedTarget,
                isWebURL: isWebURL,
                symbol: isWebURL ? "globe" : nil
            )
            layout.entries.insert(.custom(entry), at: 0)
            await layoutStore.save(layout)
            await reload()
        }
    }

    public func removeCustomItem(id: UUID) {
        Task {
            var layout = await syncedLayout()
            layout.entries.removeAll {
                if case .custom(let custom) = $0 { return custom.id == id }
                return false
            }
            await layoutStore.save(layout)
            await reload()
        }
    }

    public func resetLayout() {
        Task {
            await layoutStore.reset()
            openFolderID = nil
            await reload()
        }
    }

    /// Materialises the current resolved grid into a persisted `ApplicationsLayout`
    /// so drag-and-drop and folder operations work on first edit.
    private func syncedLayout() async -> ApplicationsLayout {
        let current = await layoutStore.load()
        let entries: [ApplicationGridEntry] = nodes.map { node in
            switch node {
            case .item(let item):
                if let appID = item.appID {
                    return .app(id: appID)
                }
                if let customID = item.customID {
                    let isWeb = if case .openWebURL = item.action { true } else { false }
                    let target: String = switch item.action {
                    case .openWebURL(let url, _): url.absoluteString
                    case .openFile(let url): url.path
                    default: ""
                    }
                    return .custom(CustomApplicationEntry(
                        id: customID,
                        title: item.title,
                        target: target,
                        isWebURL: isWeb,
                        symbol: isWeb ? "globe" : nil
                    ))
                }
                return .app(id: item.id)

            case .folder(let id, let name, let items):
                let refs: [ApplicationGridItemReference] = items.compactMap { item in
                    if let appID = item.appID {
                        return .app(id: appID)
                    }
                    if let customID = item.customID {
                        let isWeb = if case .openWebURL = item.action { true } else { false }
                        let target: String = switch item.action {
                        case .openWebURL(let url, _): url.absoluteString
                        case .openFile(let url): url.path
                        default: ""
                        }
                        return .custom(CustomApplicationEntry(
                            id: customID,
                            title: item.title,
                            target: target,
                            isWebURL: isWeb,
                            symbol: isWeb ? "globe" : nil
                        ))
                    }
                    return nil
                }
                return .folder(ApplicationFolder(id: id, name: name, items: refs))
            }
        }
        return ApplicationsLayout(entries: entries, hiddenAppIDs: current.hiddenAppIDs)
    }

    private func itemReference(from entry: ApplicationGridEntry) -> ApplicationGridItemReference? {
        switch entry {
        case .app(let appID): .app(id: appID)
        case .custom(let custom): .custom(custom)
        case .folder: nil
        }
    }
}
