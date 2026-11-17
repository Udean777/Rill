import AppKit
import Carbon.HIToolbox
import os
import RillDomain
import RillUI
import SwiftUI

/// Owns the palette panel and its show/hide lifecycle.
///
/// The panel is pre-warmed at launch, so showing it costs one
/// `makeKeyAndOrderFront`; the app itself never becomes active.
public final class PaletteWindowController {
    private static let size = CGSize(width: 680, height: 420)
    private static let showDuration: TimeInterval = 0.10
    private static let hideDuration: TimeInterval = 0.08

    public var onOpenSettings: (() -> Void)?

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

    public func toggleClipboardHistory() {
        if isShown && viewModel.mode == .clipboardHistory {
            hide()
            viewModel.reset()
        } else {
            viewModel.openClipboardHistory()
            show()
        }
    }

    /// Applies preference changes that affect the palette (page size, suggestion
    /// window) without a relaunch.
    public func apply(preferences: Preferences) {
        viewModel.applicationsPageSize = preferences.applicationsPerPage
        viewModel.showsKeyboardHints = preferences.showKeyboardHints
        viewModel.refresh()
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

    public func hide(animated: Bool = true) {
        guard isShown else { return }
        isShown = false
        viewModel.isVisible = false

        guard animated else {
            panel.alphaValue = 0
            panel.orderOut(nil)
            return
        }

        animate(alpha: 0, duration: Self.hideDuration, orderingOut: true)
    }

    /// - Returns: `true` when the event was consumed.
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let key = Int(event.keyCode)
        switch key {
        case kVK_Escape:
            if viewModel.handleEscape() {
                hide()
            }
            return true

        case kVK_Return, kVK_ANSI_KeypadEnter:
            if event.modifierFlags.contains(.option) {
                viewModel.activateSelectedAlternate()
            } else {
                viewModel.activateSelected()
            }
            return true

        case kVK_UpArrow:
            viewModel.moveSelection(by: -1)
            return true

        case kVK_DownArrow:
            viewModel.moveSelection(by: 1)
            return true

        case kVK_LeftArrow:
            if viewModel.hasMultipleApplicationPages && viewModel.query.isEmpty {
                viewModel.changeApplicationsPage(by: -1)
                return true
            }

        case kVK_RightArrow:
            if viewModel.hasMultipleApplicationPages && viewModel.query.isEmpty {
                viewModel.changeApplicationsPage(by: 1)
                return true
            }

        case kVK_Tab:
            viewModel.moveSelection(by: event.modifierFlags.contains(.shift) ? -1 : 1)
            return true

        case kVK_ANSI_P, kVK_ANSI_N:
            if event.modifierFlags.contains(.control) {
                viewModel.moveSelection(by: key == kVK_ANSI_P ? -1 : 1)
                return true
            }

        case kVK_PageUp, kVK_PageDown:
            viewModel.changeApplicationsPage(by: key == kVK_PageUp ? -1 : 1)
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

        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "," {
            hide()
            viewModel.reset()
            onOpenSettings?()
            return true
        }

        if event.modifierFlags.contains(.command), key == kVK_ANSI_P {
            viewModel.togglePinSelected()
            return true
        }

        if event.modifierFlags.contains(.command), key == kVK_Delete {
            if viewModel.mode == .clipboardHistory {
                if let clipboard = viewModel.clipboardViewModel, !clipboard.query.isEmpty {
                    clipboard.updateQuery("")
                    return true
                } else {
                    viewModel.deleteSelected()
                    return true
                }
            } else {
                if !viewModel.query.isEmpty {
                    viewModel.updateQuery("")
                    return true
                }
            }
            return false
        }

        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "c" {
            if viewModel.copySelected() {
                return true
            }
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
