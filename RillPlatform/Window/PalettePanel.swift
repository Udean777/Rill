import AppKit

/// A borderless floating panel that accepts keystrokes without activating the app.
final class PalettePanel: NSPanel {
    /// Intercepts key-down before the responder chain (text field) sees it.
    /// - Returns: `true` when the event was consumed.
    var onKeyDown: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }

    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, onKeyDown?(event) == true {
            return
        }
        super.sendEvent(event)
    }
}
