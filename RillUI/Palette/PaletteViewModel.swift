import Observation
import RillDomain

/// Palette presentation state: the query, the sectioned results and which row
/// is selected. Visibility lives here so the AppKit controller and the SwiftUI
/// field share one source of truth.
@Observable
public final class PaletteViewModel {
    public enum Mode: Sendable, Hashable {
        case launcher
        case clipboardHistory
    }

    public var mode: Mode = .launcher
    public var clipboardViewModel: ClipboardViewModel?

    public private(set) var query: String = ""
    public var isVisible: Bool = false
    public private(set) var sections: [RankedSection] = []
    public private(set) var selectedResultID: SearchResult.ID?
    public private(set) var applicationsPage: Int = 0

    /// Derived once per publish/page change, not per access: the palette reads
    /// these from every row while rendering.
    public private(set) var displaySections: [RankedSection] = []
    public private(set) var results: [SearchResult] = []

    /// Applications shown per page in the root layout (Preferences → Search).
    public var applicationsPageSize = Preferences.default.applicationsPerPage

    /// Whether the root layout shows the keyboard hint row (Preferences → General).
    public var showsKeyboardHints = Preferences.default.showKeyboardHints

    public var selectedResult: SearchResult? {
        guard let selectedResultID else { return results.first }
        return results.first { $0.id == selectedResultID } ?? results.first
    }

    /// Injected by the window controller: the view cannot import RillPlatform.
    @ObservationIgnored public var onRequestHide: (() -> Void)?
    @ObservationIgnored public var onExecute: ((SearchResult) -> Void)?
    @ObservationIgnored public var onTogglePin: ((SearchResult) -> Void)?
    @ObservationIgnored public var onOpenSettings: (() -> Void)?

    @ObservationIgnored private let searchUseCase: SearchUseCase
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    public init(searchUseCase: SearchUseCase) {
        self.searchUseCase = searchUseCase
    }

    /// The sections actually on screen: the applications section is cut to the
    /// current page so keyboard navigation matches what the user sees.
    private func rebuildDisplaySections() {
        displaySections = sections.map { ranked in
            guard ranked.section == .applications else { return ranked }
            let window = SectionPager.slice(
                ranked.results,
                page: applicationsPage,
                pageSize: applicationsPageSize
            )
            return RankedSection(section: ranked.section, results: Array(window))
        }
        results = displaySections.flatMap(\.results)
    }

    private func publish(_ newSections: [RankedSection]) {
        sections = newSections
        rebuildDisplaySections()
        // Load icons for the first screen at launch, never on the show path.
        if isRootQuery {
            IconCache.shared.prewarm(results)
        }
    }

    /// `true` when the field is effectively empty (whitespace counts as empty).
    public var isRootQuery: Bool {
        SearchQuery(raw: query).mode == .root
    }

    /// The commands section, rendered as a fixed chip row in the root layout.
    public var commandSection: RankedSection? {
        sections.first { $0.section == .commands }
    }

    public var applicationPageCount: Int {
        SectionPager.pageCount(
            itemCount: applicationResults.count,
            pageSize: applicationsPageSize
        )
    }

    public var hasMultipleApplicationPages: Bool {
        applicationPageCount > 1
    }

    /// Show the palette. The first frame is never empty: when there is no
    /// content yet, the empty query loads suggestions instantly instead of
    /// waiting for the first keystroke. An already-populated palette keeps
    /// its query and selection (design.md §4.2).
    public func show() {
        isVisible = true
        if mode == .clipboardHistory {
            clipboardViewModel?.show()
            return
        }
        // An empty field refreshes every show so suggestions follow real usage;
        // a typed query keeps its results and selection (design.md §4.2).
        if isRootQuery {
            updateQuery("")
            return
        }
        guard sections.isEmpty else { return }
        updateQuery(query)
    }

    public func openClipboardHistory() {
        mode = .clipboardHistory
        clipboardViewModel?.show()
    }

    public func exitClipboardHistory() {
        mode = .launcher
        refresh()
    }

    public func updateQuery(_ text: String) {
        query = text
        applicationsPage = 0
        searchTask?.cancel()

        let request = SearchQuery(raw: text)

        if request.mode == .root {
            // Suggestions for an empty field appear immediately; no debounce.
            searchTask = Task { [weak self] in
                let sections = await self?.searchUseCase(request) ?? []
                guard !Task.isCancelled, let self else { return }
                let previousSelectedID = self.selectedResultID
                self.publish(sections)
                if let previousSelectedID, self.results.contains(where: { $0.id == previousSelectedID }) {
                    self.selectedResultID = previousSelectedID
                } else {
                    self.selectedResultID = self.results.first?.id
                }
            }
            return
        }

        searchTask = Task { [weak self] in
            // 60 ms: below the perceived-latency floor, above one keystroke
            // interval, so a fast typist never sees stale results.
            try? await Task.sleep(for: .milliseconds(60))
            guard !Task.isCancelled, let self else { return }

            let sections = await self.searchUseCase(request)
            guard !Task.isCancelled else { return }

            let previousSelectedID = self.selectedResultID
            self.publish(sections)
            if let previousSelectedID, self.results.contains(where: { $0.id == previousSelectedID }) {
                self.selectedResultID = previousSelectedID
            } else {
                self.selectedResultID = self.results.first?.id
            }
        }
    }

    /// Esc: clear a non-empty query, otherwise ask to hide (design.md §4.2).
    /// - Returns: `true` when the caller should hide the palette.
    @discardableResult
    public func handleEscape() -> Bool {
        if mode == .clipboardHistory {
            if let cb = clipboardViewModel, !cb.query.isEmpty {
                cb.updateQuery("")
                return false
            }
            mode = .launcher
            refresh()
            return false
        }
        guard query.isEmpty else {
            updateQuery("")
            return false
        }
        return true
    }

    public func moveSelection(by delta: Int) {
        if mode == .clipboardHistory {
            clipboardViewModel?.moveSelection(by: delta)
            return
        }
        let results = results
        guard !results.isEmpty else { return }

        let currentIndex = results.firstIndex { $0.id == selectedResultID } ?? 0
        let targetIndex = currentIndex + delta
        guard targetIndex >= 0 && targetIndex < results.count else { return }
        selectedResultID = results[targetIndex].id
    }

    /// Moves the applications section by whole pages, keeping the selection
    /// visible (first app of the new page when it would fall off screen).
    public func changeApplicationsPage(by delta: Int) {
        let target = SectionPager.clamp(
            page: applicationsPage + delta,
            itemCount: applicationResults.count,
            pageSize: applicationsPageSize
        )
        guard target != applicationsPage else { return }
        applicationsPage = target
        rebuildDisplaySections()

        let visible = results
        guard !visible.contains(where: { $0.id == selectedResultID }) else { return }
        selectedResultID = firstApplicationID(onPage: applicationsPage) ?? visible.first?.id
    }

    /// Runs the row at a zero-based index (⌘1…⌘9).
    public func activate(index: Int) {
        let results = results
        guard results.indices.contains(index) else { return }
        selectedResultID = results[index].id
        activateSelected()
    }

    public func activateSelected() {
        if mode == .clipboardHistory {
            clipboardViewModel?.pasteSelected(asPlainText: false)
            return
        }
        guard
            let selectedResultID,
            let result = results.first(where: { $0.id == selectedResultID })
        else { return }
        onExecute?(result)
    }

    public func activateSelectedAlternate() {
        if mode == .clipboardHistory {
            clipboardViewModel?.pasteSelected(asPlainText: true)
        }
    }

    public func copySelected() -> Bool {
        if mode == .clipboardHistory {
            clipboardViewModel?.copySelected()
            return true
        }
        return false
    }

    public func deleteSelected() {
        if mode == .clipboardHistory {
            clipboardViewModel?.deleteSelected()
        }
    }

    public func selectAndActivate(_ result: SearchResult) {
        selectedResultID = result.id
        activateSelected()
    }

    /// Pin or unpin a row. A result is pinned exactly when it sits in the
    /// favourites section (see `SearchUseCase`).
    public func togglePin(_ result: SearchResult) {
        onTogglePin?(result)
    }

    public func togglePinSelected() {
        if mode == .clipboardHistory {
            clipboardViewModel?.togglePinSelected()
            return
        }
        guard
            let selectedResultID,
            let result = results.first(where: { $0.id == selectedResultID })
        else { return }
        togglePin(result)
    }

    /// The ⌘N hint for a row, or `nil` past the ninth result.
    public func shortcutNumber(for id: SearchResult.ID) -> Int? {
        guard let index = results.firstIndex(where: { $0.id == id }), index < 9 else {
            return nil
        }
        return index + 1
    }

    /// Re-runs the current query, e.g. after a preference that changes results.
    public func refresh() {
        updateQuery(query)
    }

    /// Clears transient state after an execute.
    public func reset() {
        searchTask?.cancel()
        query = ""
        sections = []
        displaySections = []
        results = []
        selectedResultID = nil
        applicationsPage = 0
        mode = .launcher
    }

    private var applicationResults: [SearchResult] {
        sections.first { $0.section == .applications }?.results ?? []
    }

    private func applicationResults(onPage page: Int) -> [SearchResult] {
        Array(
            SectionPager.slice(
                applicationResults,
                page: page,
                pageSize: applicationsPageSize
            )
        )
    }

    private func firstApplicationID(onPage page: Int) -> SearchResult.ID? {
        applicationResults(onPage: page).first?.id
    }

    private func lastApplicationID(onPage page: Int) -> SearchResult.ID? {
        applicationResults(onPage: page).last?.id
    }
}
