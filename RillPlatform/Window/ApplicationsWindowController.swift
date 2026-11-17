import AppKit
import Carbon.HIToolbox
import RillDomain
import RillUI
import SwiftUI

/// Owns the floating Applications grid panel and its show/hide lifecycle.
///
/// Mirrors `PaletteWindowController`'s non-activating contract: the panel
/// becomes key without activating Rill (`LSUIElement = YES`), preserving the
/// previously active application's menu bar and Dock highlight.
@MainActor
public final class ApplicationsWindowController: NSObject, NSWindowDelegate {
    private let panel: ApplicationsPanel
    private let viewModel: ApplicationsGridViewModel
    private var isPrewarmed = false
    private var hideAnimationID = 0
    private var accumulatedScrollX: CGFloat = 0
    private var didFlipPageInScroll = false

    public var isVisible: Bool {
        panel.isVisible
    }

    public init(viewModel: ApplicationsGridViewModel) {
        self.viewModel = viewModel

        let panel = ApplicationsPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 720),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.isReleasedWhenClosed = false
        panel.contentViewController = NSHostingController(
            rootView: ApplicationsGridView(viewModel: viewModel)
        )
        self.panel = panel
        super.init()

        panel.delegate = self
        panel.onKeyDown = { [weak self] event in
            self?.handleKeyDown(event) ?? false
        }
        panel.onScrollWheel = { [weak self] event in
            self?.handleScrollWheel(event) ?? false
        }
        panel.onSwipeEvent = { [weak self] event in
            self?.handleAppKitSwipe(event) ?? false
        }
        viewModel.onRequestHide = { [weak self] in
            self?.hide()
        }
    }

    public func prewarm() {
        guard !isPrewarmed else { return }
        isPrewarmed = true
        panel.alphaValue = 0
        panel.contentView?.layoutSubtreeIfNeeded()
        Task {
            await viewModel.reload()
        }
    }

    public func apply(preferences: Preferences) {
        viewModel.apply(preferences: preferences)
    }

    public func show() {
        hideAnimationID += 1
        let targetFrame = frameForActiveScreen()
        panel.setFrame(targetFrame, display: false)

        if !panel.isVisible {
            panel.alphaValue = 0
            panel.makeKeyAndOrderFront(nil)
            viewModel.show()
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                panel.alphaValue = 1
            } else {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.14
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    panel.animator().alphaValue = 1
                }
            }
        } else {
            panel.makeKeyAndOrderFront(nil)
            viewModel.show()
        }
    }

    public func hide(animated: Bool = true) {
        guard panel.isVisible else { return }
        viewModel.isVisible = false
        hideAnimationID += 1
        let animationID = hideAnimationID

        if !animated || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.orderOut(nil)
            panel.alphaValue = 1
            viewModel.resetTransientState()
            return
        }

        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.10
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
            },
            completionHandler: { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, self.hideAnimationID == animationID else { return }
                    self.panel.orderOut(nil)
                    self.panel.alphaValue = 1
                    self.viewModel.resetTransientState()
                }
            }
        )
    }

    public func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    public func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private func frameForActiveScreen() -> NSRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        return screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch Int(event.keyCode) {
        case kVK_Escape:
            if viewModel.handleEscape() {
                hide()
            }
            return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            viewModel.activateSelected()
            return true
        case kVK_LeftArrow:
            if modifiers.contains(.command) {
                viewModel.changePage(by: -1)
                return true
            }
            if viewModel.query.isEmpty {
                viewModel.moveSelection(dx: -1, dy: 0)
                return true
            }
            return false
        case kVK_RightArrow:
            if modifiers.contains(.command) {
                viewModel.changePage(by: 1)
                return true
            }
            if viewModel.query.isEmpty {
                viewModel.moveSelection(dx: 1, dy: 0)
                return true
            }
            return false
        case kVK_UpArrow:
            viewModel.moveSelection(dx: 0, dy: -1)
            return true
        case kVK_DownArrow:
            viewModel.moveSelection(dx: 0, dy: 1)
            return true
        case kVK_PageUp:
            viewModel.changePage(by: -1)
            return true
        case kVK_PageDown:
            viewModel.changePage(by: 1)
            return true
        default:
            return false
        }
    }

    private func handleScrollWheel(_ event: NSEvent) -> Bool {
        guard event.hasPreciseScrollingDeltas,
              !viewModel.isFiltering,
              viewModel.openFolderID == nil else {
            return false
        }

        // Ignore inertia/momentum scroll frames so a single 2-finger flick flips at most one page.
        guard event.momentumPhase == [] else {
            return true
        }

        if event.phase == .began || event.phase == .mayBegin {
            accumulatedScrollX = 0
            didFlipPageInScroll = false
        }

        if event.phase == .ended || event.phase == .cancelled {
            accumulatedScrollX = 0
            didFlipPageInScroll = false
            return true
        }

        if !didFlipPageInScroll, abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
            accumulatedScrollX += event.scrollingDeltaX
            if accumulatedScrollX <= -35 {
                didFlipPageInScroll = true
                viewModel.changePage(by: 1)
                return true
            }
            if accumulatedScrollX >= 35 {
                didFlipPageInScroll = true
                viewModel.changePage(by: -1)
                return true
            }
        }
        return false
    }

    private func handleAppKitSwipe(_ event: NSEvent) -> Bool {
        guard !viewModel.isFiltering, viewModel.openFolderID == nil else { return false }
        if event.deltaX < 0 {
            viewModel.changePage(by: 1)
            return true
        }
        if event.deltaX > 0 {
            viewModel.changePage(by: -1)
            return true
        }
        return false
    }
}
