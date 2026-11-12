import AppKit
import ApplicationServices
import os
import RillDomain

/// Simulates a ⌘V keystroke via `CGEvent` when Accessibility permissions are trusted.
public final class AccessibilityDirectPaster: DirectPasting {
    private let log = Logger(subsystem: "com.ssajudn.Rill", category: "directPaster")

    public init() {}

    public nonisolated func isDirectPasteAvailable() -> Bool {
        AXIsProcessTrusted()
    }

    public nonisolated func paste() async throws {
        guard AXIsProcessTrusted() else {
            log.warning("cannot direct paste: Accessibility not trusted")
            return
        }

        // Small delay so previous app regains active focus before keystroke arrives
        try? await Task.sleep(for: .milliseconds(50))

        let source = CGEventSource(stateID: .combinedSessionState)
        let virtualKeyV: CGKeyCode = 0x09 // kVK_ANSI_V

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKeyV, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKeyV, keyDown: false) else {
            log.error("failed to create CGEvent for paste")
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
