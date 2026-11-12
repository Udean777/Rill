import Foundation

/// Port for executing a direct paste action into the previously active application.
public protocol DirectPasting: Sendable {
    func paste() async throws
    func isDirectPasteAvailable() -> Bool
}
