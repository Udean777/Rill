import AppKit

/// Owns the system menu bar status item that provides access to Settings and Quit
/// without activating the app or touching the app menu bar (see design.md §5.3).
@MainActor
public final class StatusBarController {
    private var statusItem: NSStatusItem?
    private let onShowPalette: () -> Void
    private let onOpenSettings: () -> Void
    private let onCheckForUpdates: (() -> Void)?

    public init(
        onShowPalette: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onCheckForUpdates: (() -> Void)? = nil
    ) {
        self.onShowPalette = onShowPalette
        self.onOpenSettings = onOpenSettings
        self.onCheckForUpdates = onCheckForUpdates
    }

    /// Installs or removes the menu bar icon (Preferences → General).
    public func setEnabled(_ enabled: Bool) {
        if enabled {
            guard statusItem == nil else { return }
            install()
        } else {
            guard let statusItem else { return }
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    private func install() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }

        let icon = NSImage(named: "StatusBarIcon")
            ?? NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Rill")
        icon?.isTemplate = true
        button.image = icon

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Rill", action: #selector(showPalette), keyEquivalent: ""))
        menu.addItem(.separator())
        if onCheckForUpdates != nil {
            menu.addItem(NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: ""))
        }
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Rill", action: #selector(quitApp), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        statusItem.menu = menu
        self.statusItem = statusItem
    }

    @objc private func showPalette() {
        onShowPalette()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func checkForUpdates() {
        onCheckForUpdates?()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
