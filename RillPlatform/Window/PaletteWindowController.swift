import AppKit
import os
import RillUI
import SwiftUI

/// Owns the palette panel and its show/hide lifecycle.
///
/// The panel is pre-warmed at launch, so showing it costs one
/// `makeKeyAndOrderFront`; the app itself never becomes active.
public final class PaletteWindowController {
    private static let size = CGSize(width: 680, height: 420)
    private static let showDuration: TimeInterval = 0.12
    private static let hideDuration: TimeInterval = 0.08

    private let panel: PalettePanel
    private let viewModel: PaletteViewModel
    private let log = Logger(subsystem: "com.ssajudn.Rill", category: "window")
    private var isShown = false

    public init(viewModel: PaletteViewModel) {
        self.viewModel = viewModel

        let panel = PalettePanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.animationBehavior = .none
        panel.contentView = NSHostingView(rootView: PaletteView(viewModel: viewModel))
        panel.alphaValue = 0
        self.panel = panel

        viewModel.onRequestHide = { [weak self] in
            self?.hide()
        }

        // Navigation keys are intercepted before the text field consumes them.
        panel.onKeyDown = { [weak self] event in
            self?.handleKeyDown(event) ?? false
        }

        // Click outside / another app taking focus hides the palette (design.md §4.2).
        Task { [weak self, panel] in
            for await _ in NotificationCenter.default.notifications(
                named: NSWindow.didResignKeyNotification,
                object: panel
            ) {
                self?.hide()
            }
        }
    }

    /// Builds and lays out the panel at launch, hidden, so the first show is instant.
    public func prewarm() {
        guard let screen = PanelPositioner.screenUnderPointer() else { return }
        panel.setFrame(PanelPositioner.frame(for: Self.size, on: screen), display: false)
        panel.contentView?.layoutSubtreeIfNeeded()
        // Populate root suggestions now so the very first show is never empty.
        viewModel.updateQuery("")
    }

    public func toggle() {
        if isShown {
            hide()
        } else {
            show()
        }
    }

    public func show() {
        guard let screen = PanelPositioner.screenUnderPointer() else {
            log.error("no screen available for palette")
            return
        }
        panel.setFrame(PanelPositioner.frame(for: Self.size, on: screen), display: true)
        viewModel.show()

        guard !isShown else {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        isShown = true
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)

        animate(alpha: 1, duration: Self.showDuration)
    }

    public func hide() {
        guard isShown else { return }
        isShown = false
        viewModel.isVisible = false

        animate(alpha: 0, duration: Self.hideDuration, orderingOut: true)
    }

    /// - Returns: `true` when the event was consumed.
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53:  // Esc
            if viewModel.handleEscape() {
                hide()
            }
            return true

        case 36, 76:  // Return, keypad Enter
            viewModel.activateSelected()
            return true

        case 126:  // Up
            viewModel.moveSelection(by: -1)
            return true

        case 125:  // Down
            viewModel.moveSelection(by: 1)
            return true

        case 48:  // Tab
            viewModel.moveSelection(by: event.modifierFlags.contains(.shift) ? -1 : 1)
            return true

        case 35, 45:  // ⌃P / ⌃N
            guard event.modifierFlags.contains(.control) else { return false }
            viewModel.moveSelection(by: event.keyCode == 35 ? -1 : 1)
            return true

        case 116, 121:  // Page Up / Page Down
            viewModel.changeApplicationsPage(by: event.keyCode == 116 ? -1 : 1)
            return true

        default:
            break
        }

        if event.modifierFlags.contains(.command),
           let character = event.charactersIgnoringModifiers,
           let number = Int(character),
           (1...9).contains(number) {
            viewModel.activate(index: number - 1)
            return true
        }

        return false
    }

    private func animate(alpha: CGFloat, duration: TimeInterval, orderingOut: Bool = false) {
        let effectiveDuration =
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : duration
        NSAnimationContext.runAnimationGroup { context in
            context.duration = effectiveDuration
            panel.animator().alphaValue = alpha
        } completionHandler: { [weak self] in
            guard orderingOut else { return }
            // Animation completions are delivered on the main thread.
            MainActor.assumeIsolated {
                self?.panel.orderOut(nil)
            }
        }
    }
}
