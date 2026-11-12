import Foundation

/// Port for persisting and querying clipboard history.
public protocol ClipboardStoring: Sendable {
    func items(matching query: String, filter: ClipboardFilter, limit: Int) async -> [ClipboardItem]
    func save(_ item: ClipboardItem) async
    func delete(id: ClipboardItem.ID) async
    func togglePin(id: ClipboardItem.ID) async
    func clearHistory(keepingPinned: Bool) async
    func itemCount() async -> Int
}
