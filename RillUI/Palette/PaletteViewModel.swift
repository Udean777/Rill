import Observation
import RillDomain

/// Palette presentation state: the query, the sectioned results and which row
/// is selected. Visibility lives here so the AppKit controller and the SwiftUI
/// field share one source of truth.
@Observable
public final class PaletteViewModel {
    public private(set) var query: String = ""
    public var isVisible: Bool = false
    public private(set) var sections: [RankedSection] = []
    public private(set) var selectedResultID: SearchResult.ID?
    public private(set) var applicationsPage: Int = 0

    /// All apps are shown five per page in the root layout (design.md §5.2).
    public static let applicationsPageSize = 5

    /// Injected by the window controller: the view cannot import RillPlatform.
    @ObservationIgnored public var onRequestHide: (() -> Void)?
    @ObservationIgnored public var onExecute: ((SearchResult) -> Void)?

    @ObservationIgnored private let searchUseCase: SearchUseCase
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    public init(searchUseCase: SearchUseCase) {
        self.searchUseCase = searchUseCase
    }

    /// The sections actually on screen: the applications section is cut to the
    /// current page so keyboard navigation matches what the user sees.
    public var displaySections: [RankedSection] {
        sections.map { ranked in
            guard ranked.section == .applications else { return ranked }
            let window = SectionPager.slice(
                ranked.results,
                page: applicationsPage,
                pageSize: Self.applicationsPageSize
            )
            return RankedSection(section: ranked.section, results: Array(window))
        }
    }

    /// Every visible result in render order.
    public var results: [SearchResult] {
        displaySections.flatMap(\.results)
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
            pageSize: Self.applicationsPageSize
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
        // An empty field refreshes every show so suggestions follow real usage;
        // a typed query keeps its results and selection (design.md §4.2).
        if isRootQuery {
            updateQuery("")
            return
        }
        guard sections.isEmpty else { return }
        updateQuery(query)
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
                self.sections = sections
                self.selectedResultID = sections.first?.results.first?.id
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

            self.sections = sections
            self.selectedResultID = sections.first?.results.first?.id
        }
    }

    /// Esc: clear a non-empty query, otherwise ask to hide (design.md §4.2).
    /// - Returns: `true` when the caller should hide the palette.
    @discardableResult
    public func handleEscape() -> Bool {
        guard query.isEmpty else {
            updateQuery("")
            return false
        }
        return true
    }

    public func moveSelection(by delta: Int) {
        let results = results
        guard !results.isEmpty else { return }

        let currentIndex = results.firstIndex { $0.id == selectedResultID } ?? 0

        // Walking off an edge of the applications page flips the page first.
        if delta > 0,
           results[currentIndex].id == lastApplicationID(onPage: applicationsPage),
           applicationsPage + 1 < applicationPageCount {
            applicationsPage += 1
            selectedResultID = firstApplicationID(onPage: applicationsPage)
            return
        }
        if delta < 0,
           results[currentIndex].id == firstApplicationID(onPage: applicationsPage),
           applicationsPage > 0 {
            applicationsPage -= 1
            selectedResultID = lastApplicationID(onPage: applicationsPage)
            return
        }

        let nextIndex = (currentIndex + delta + results.count) % results.count
        selectedResultID = results[nextIndex].id
    }

    /// Moves the applications section by whole pages, keeping the selection
    /// visible (first app of the new page when it would fall off screen).
    public func changeApplicationsPage(by delta: Int) {
        let target = SectionPager.clamp(
            page: applicationsPage + delta,
            itemCount: applicationResults.count,
            pageSize: Self.applicationsPageSize
        )
        guard target != applicationsPage else { return }
        applicationsPage = target

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
        guard
            let selectedResultID,
            let result = results.first(where: { $0.id == selectedResultID })
        else { return }
        onExecute?(result)
    }

    public func selectAndActivate(_ result: SearchResult) {
        selectedResultID = result.id
        activateSelected()
    }

    /// The ⌘N hint for a row, or `nil` past the ninth result.
    public func shortcutNumber(for id: SearchResult.ID) -> Int? {
        guard let index = results.firstIndex(where: { $0.id == id }), index < 9 else {
            return nil
        }
        return index + 1
    }

    /// Clears transient state after an execute.
    public func reset() {
        searchTask?.cancel()
        query = ""
        sections = []
        selectedResultID = nil
        applicationsPage = 0
    }

    private var applicationResults: [SearchResult] {
        sections.first { $0.section == .applications }?.results ?? []
    }

    private func applicationResults(onPage page: Int) -> [SearchResult] {
        Array(
            SectionPager.slice(
                applicationResults,
                page: page,
                pageSize: Self.applicationsPageSize
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
