import AppKit

/// Borderless, non-activating floating panel for the Launchpad-style
/// Applications grid.
final class ApplicationsPanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?
    var onScrollWheel: ((NSEvent) -> Bool)?
    var onSwipeEvent: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }

    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, onKeyDown?(event) == true {
            return
        }
        super.sendEvent(event)
    }

    override func scrollWheel(with event: NSEvent) {
        if onScrollWheel?(event) == true {
            return
        }
        super.scrollWheel(with: event)
    }

    override func swipe(with event: NSEvent) {
        if onSwipeEvent?(event) == true {
            return
        }
        super.swipe(with: event)
    }
}
