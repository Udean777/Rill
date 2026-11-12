import AppKit
import RillUI
import SwiftUI

/// First-run welcome window. Borrows `.regular` like Settings (design.md §5.3),
/// because a normal window needs a menu bar and keyboard focus.
@MainActor
public final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private let viewModel: SettingsViewModel
    private let activationPolicyController: ActivationPolicyController
    private let onCompletion: @MainActor (Bool) -> Void
    private var window: NSWindow?
    private var isFinishing = false

    /// - Parameter onCompletion: receives `true` when the user pressed
    ///   Get Started, `false` when the window was merely closed.
    public init(
        viewModel: SettingsViewModel,
        activationPolicyController: ActivationPolicyController = .shared,
        onCompletion: @escaping @MainActor (Bool) -> Void
    ) {
        self.viewModel = viewModel
        self.activationPolicyController = activationPolicyController
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

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Rill"
        window.contentView = hostingView
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false

        self.window = window

        activationPolicyController.acquireRegular()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    /// Closes after a Get Started press and reports that the palette should show.
    private func finish() {
        isFinishing = true
        window?.close()
    }

    public func windowWillClose(_ notification: Notification) {
        activationPolicyController.releaseRegular()
        window = nil
        onCompletion(isFinishing)
        isFinishing = false
    }
}
