import AppKit
import RillUI
import SwiftUI

/// Window controller managing the Settings window lifecycle (see design.md §5.5).
@MainActor
public final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let viewModel: SettingsViewModel
    private var window: NSWindow?

    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
        super.init()
    }

    public func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let settingsView = SettingsView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Rill Settings"
        window.contentView = hostingView
        // Stay on the space the user is actually looking at. Without this, a
        // fullscreen app makes macOS yank the user back to the desktop space
        // where the window was last placed.
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        centerOnActiveScreen(window)
        window.delegate = self
        window.isReleasedWhenClosed = false

        self.window = window

        // Stay `.accessory` rather than borrowing `.regular`: activating a
        // `.regular` app from another app's fullscreen space forces macOS to
        // switch Spaces to the desktop whenever the user clicks Settings.
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    public func windowWillClose(_ notification: Notification) {
        window = nil
    }

    /// Centers on the display the pointer is on, so a fullscreen app on another
    /// display opens Settings where the user is, not on the main display.
    private func centerOnActiveScreen(_ window: NSWindow) {
        guard let screen = PanelPositioner.screenUnderPointer() ?? window.screen else {
            window.center()
            return
        }
        let visible = screen.visibleFrame
        window.setFrameOrigin(NSPoint(
            x: visible.midX - window.frame.width / 2,
            y: visible.midY - window.frame.height / 2
        ))
    }
}
