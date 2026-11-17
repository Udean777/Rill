import Foundation

/// Port for persisting the user's custom Applications grid order, folders,
/// hidden apps, and custom items.
public protocol ApplicationsLayoutStoring: Sendable {
    func load() async -> ApplicationsLayout
    func save(_ layout: ApplicationsLayout) async
    func reset() async
}
