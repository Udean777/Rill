import Foundation
import Observation
import RillDomain

/// Presentation state for the Clipboard History panel.
@Observable
@MainActor
public final class ClipboardViewModel {
    public var query: String = ""
    public var activeFilter: ClipboardFilter = .all
    public private(set) var items: [ClipboardItem] = []
    public var selectedItemID: ClipboardItem.ID?
    public let imagesDirectoryURL: URL

    @ObservationIgnored public var onPaste: ((ClipboardItem, Bool) -> Void)?
    @ObservationIgnored public var onCopy: ((ClipboardItem) -> Void)?
    @ObservationIgnored public var onTogglePin: ((ClipboardItem) -> Void)?
    @ObservationIgnored public var onDelete: ((ClipboardItem) -> Void)?
    @ObservationIgnored public var onClearHistory: (() -> Void)?
    @ObservationIgnored public var onExit: (() -> Void)?

    @ObservationIgnored private let searchUseCase: SearchClipboardUseCase
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    public init(
        searchUseCase: SearchClipboardUseCase,
        imagesDirectoryURL: URL
    ) {
        self.searchUseCase = searchUseCase
        self.imagesDirectoryURL = imagesDirectoryURL
    }

    public var selectedItem: ClipboardItem? {
        guard let selectedItemID else { return items.first }
        return items.first { $0.id == selectedItemID } ?? items.first
    }

    public func show() {
        refresh()
    }

    public func updateQuery(_ text: String) {
        query = text
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(40))
            guard !Task.isCancelled, let self else { return }
            await self.reload()
        }
    }

    public func selectFilter(_ filter: ClipboardFilter) {
        guard activeFilter != filter else { return }
        activeFilter = filter
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            await self?.reload()
        }
    }

    public func refresh() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            await self?.reload()
        }
    }

    private func reload() async {
        let results = await searchUseCase(query: query, filter: activeFilter)
        guard !Task.isCancelled else { return }
        self.items = results
        if let current = selectedItemID, results.contains(where: { $0.id == current }) {
            // Keep current selection
        } else {
            self.selectedItemID = results.first?.id
        }
    }

    public func moveSelection(by delta: Int) {
        guard !items.isEmpty else { return }
        let currentIndex = items.firstIndex { $0.id == selectedItemID } ?? 0
        let targetIndex = currentIndex + delta
        guard targetIndex >= 0 && targetIndex < items.count else { return }
        selectedItemID = items[targetIndex].id
    }

    public func pasteSelected(asPlainText: Bool = false) {
        guard let selectedItem else { return }
        onPaste?(selectedItem, asPlainText)
    }

    public func copySelected() {
        guard let selectedItem else { return }
        onCopy?(selectedItem)
    }

    public func togglePinSelected() {
        guard let selectedItem else { return }
        onTogglePin?(selectedItem)
        refresh()
    }

    public func deleteSelected() {
        guard let selectedItem else { return }
        onDelete?(selectedItem)
        refresh()
    }

    public func clearHistory() {
        onClearHistory?()
        refresh()
    }

    public func handleEscape() -> Bool {
        if !query.isEmpty {
            updateQuery("")
            return false
        }
        onExit?()
        return true
    }
}
