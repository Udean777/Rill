import AppKit
import RillUI
import SwiftUI

/// First-run welcome window. Stays `.accessory` like Settings to avoid
/// forcing a Space switch from fullscreen apps.
@MainActor
public final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private let viewModel: SettingsViewModel
    private let onCompletion: @MainActor (Bool) -> Void
    private var window: NSWindow?
    private var isFinishing = false

    /// - Parameter onCompletion: receives `true` when the user pressed
    ///   Get Started, `false` when the window was merely closed.
    public init(
        viewModel: SettingsViewModel,
        onCompletion: @escaping @MainActor (Bool) -> Void
    ) {
        self.viewModel = viewModel
        self.onCompletion = onCompletion
        super.init()
    }

    public var isVisible: Bool { window != nil }

    public func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let onboardingView = OnboardingView(
            viewModel: viewModel,
            onFinish: { [weak self] in self?.finish() }
        )
        let hostingView = NSHostingView(rootView: onboardingView)

        let window = AuxiliaryWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 540, height: 520)
        window.title = String(localized: "Welcome to Rill")
        window.contentView = hostingView
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.centerOnActiveScreen()
        window.delegate = self
        window.isReleasedWhenClosed = false

        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    /// Closes after a Get Started press and reports that the palette should show.
    private func finish() {
        isFinishing = true
        window?.close()
    }

    public func windowWillClose(_ notification: Notification) {
        window = nil
        onCompletion(isFinishing)
        isFinishing = false
    }
}
