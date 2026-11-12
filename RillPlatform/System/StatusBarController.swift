import AppKit

/// Owns the system menu bar status item that provides access to Settings and Quit
/// without activating the app or touching the app menu bar (see design.md §5.3).
@MainActor
public final class StatusBarController {
    private let statusItem: NSStatusItem
    private let onShowPalette: () -> Void
    private let onOpenSettings: () -> Void

    public init(onShowPalette: @escaping () -> Void, onOpenSettings: @escaping () -> Void) {
        self.onShowPalette = onShowPalette
        self.onOpenSettings = onOpenSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configure()
    }

    private func configure() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Rill")
        button.image?.isTemplate = true

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Rill", action: #selector(showPalette), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Rill", action: #selector(quitApp), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        statusItem.menu = menu
    }

    @objc private func showPalette() {
        onShowPalette()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
