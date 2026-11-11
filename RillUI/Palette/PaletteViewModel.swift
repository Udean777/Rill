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

    /// Injected by the window controller: the view cannot import RillPlatform.
    @ObservationIgnored public var onRequestHide: (() -> Void)?
    @ObservationIgnored public var onExecute: ((SearchResult) -> Void)?

    @ObservationIgnored private let searchUseCase: SearchUseCase
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    public init(searchUseCase: SearchUseCase) {
        self.searchUseCase = searchUseCase
    }

    /// Every visible result in render order.
    public var results: [SearchResult] {
        sections.flatMap(\.results)
    }

    public func updateQuery(_ text: String) {
        query = text
        searchTask?.cancel()

        let request = SearchQuery(raw: text)
        searchTask = Task { [weak self] in
            // 60 ms: below the perceived-latency floor, above one keystroke interval.
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
        let nextIndex = (currentIndex + delta + results.count) % results.count
        selectedResultID = results[nextIndex].id
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
    }
}
