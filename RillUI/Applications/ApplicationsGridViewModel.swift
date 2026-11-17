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
    @ObservationIgnored private let layoutEditor = EditApplicationsLayoutUseCase()

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
        filteredItems = ApplicationGridFilter.filter(
            nodes.flatMap(\.items),
            query: SearchQuery(raw: trimmed)
        )
    }

    public var pageCount: Int {
        max(1, SectionPager.pageCount(itemCount: nodes.count, pageSize: pageSize))
    }

    public var pagedNodes: [ApplicationsGridNode] {
        Array(SectionPager.slice(nodes, page: currentPage, pageSize: pageSize))
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
        if let openFolderID, openFolder == nil {
            self.openFolderID = nil
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
        persistLayout { self.layoutEditor.moving(draggedID, to: targetID, in: $0) }
    }

    public func createFolder(combining sourceID: String, with targetID: String, name: String) {
        guard sourceID != targetID else { return }
        let folderName = name.isEmpty ? String(localized: "Folder") : name
        persistLayout {
            self.layoutEditor.creatingFolder(
                combining: sourceID, with: targetID, name: folderName, in: $0
            )
        }
    }

    public func renameFolder(_ folderID: UUID, to newName: String) {
        persistLayout { self.layoutEditor.renamingFolder(folderID, to: newName, in: $0) }
    }

    public func removeItem(_ itemID: String, fromFolder folderID: UUID) {
        persistLayout { self.layoutEditor.removingItem(itemID, fromFolder: folderID, in: $0) }
    }

    public func hideApplication(appID: String) {
        persistLayout { self.layoutEditor.settingHidden(appID, isHidden: true, in: $0) }
    }

    public func unhideApplication(appID: String) {
        persistLayout { self.layoutEditor.settingHidden(appID, isHidden: false, in: $0) }
    }

    public func addCustomItem(title: String, target: String, isWebURL: Bool) {
        persistLayout {
            self.layoutEditor.addingCustomItem(
                title: title, target: target, isWebURL: isWebURL, in: $0
            )
        }
    }

    public func removeCustomItem(id: UUID) {
        persistLayout { self.layoutEditor.removingCustomItem(id: id, in: $0) }
    }

    public func resetLayout() {
        Task {
            await layoutStore.reset()
            openFolderID = nil
            await reload()
        }
    }

    /// Materialises the resolved grid into the stored layout, applies `edit`,
    /// persists, then reloads so the grid reflects the saved state.
    private func persistLayout(
        _ edit: @escaping @MainActor (ApplicationsLayout) -> ApplicationsLayout
    ) {
        Task { @MainActor in
            let stored = await layoutStore.load()
            let synced = layoutEditor.materialized(stored, from: nodes)
            await layoutStore.save(edit(synced))
            await reload()
        }
    }
}
