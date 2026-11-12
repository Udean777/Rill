import Foundation

/// Searches and filters clipboard items matching a query and filter.
public struct SearchClipboardUseCase: Sendable {
    private let store: ClipboardStoring

    public init(store: ClipboardStoring) {
        self.store = store
    }

    public func callAsFunction(
        query: String = "",
        filter: ClipboardFilter = .all,
        limit: Int = 100
    ) async -> [ClipboardItem] {
        await store.items(matching: query, filter: filter, limit: limit)
    }
}
