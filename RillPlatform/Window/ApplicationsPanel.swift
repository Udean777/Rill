import AppKit

/// Borderless, non-activating floating panel for the Launchpad-style
/// Applications grid.
final class ApplicationsPanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?
    var onScrollWheel: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }

    override var canBecomeMain: Bool { false }

    /// `super.sendEvent` hands scroll events straight to the SwiftUI hosting
    /// view, so `scrollWheel(with:)` alone never sees them once the grid has a
    /// `ScrollView`. Observing here runs before that dispatch.
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            if onKeyDown?(event) == true {
                return
            }
        case .scrollWheel:
            if onScrollWheel?(event) == true {
                return
            }
        default:
            break
        }
        super.sendEvent(event)
    }
}
