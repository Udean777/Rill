import AppKit
import RillUI
import SwiftUI

/// Window controller managing the Settings window lifecycle and activation policy (see design.md §5.3, §5.5).
@MainActor
public final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let viewModel: SettingsViewModel
    private let activationPolicyController: ActivationPolicyController
    private var window: NSWindow?

    public init(
        viewModel: SettingsViewModel,
        activationPolicyController: ActivationPolicyController = .shared
    ) {
        self.viewModel = viewModel
        self.activationPolicyController = activationPolicyController
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
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Rill Settings"
        window.contentView = hostingView
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false

        self.window = window

        // Borrow .regular activation policy so Settings has menus and appears normally (design.md §5.3)
        activationPolicyController.acquireRegular()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    public func windowWillClose(_ notification: Notification) {
        activationPolicyController.releaseRegular()
        window = nil
    }
}
