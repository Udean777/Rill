import Foundation
import Observation
import RillDomain

/// Presentation state for the Settings window
@MainActor
@Observable
public final class SettingsViewModel {
    public var preferences: Preferences
    public var isAccessibilityGranted: Bool = false
    public var isLaunchAtLoginEnabled: Bool = false
    public var launchAtLoginError: String?
    public var hotkeyError: String?
    /// Whether the stored shortcut is currently registered with the system.
    public var isHotkeyRegistered = true
    public var clipboardHotkeyError: String?
    public var isClipboardHotkeyRegistered = true

    private let preferencesStore: PreferencesStoring
    private let onHotkeyChanged: ((Hotkey) async -> Bool)?
    private let onClipboardHotkeyChanged: ((Hotkey) async -> Bool)?
    private let onPreferencesChanged: ((Preferences) -> Void)?
    private let getLaunchAtLogin: (() -> Bool)?
    private let setLaunchAtLogin: ((Bool) throws -> Void)?
    private let checkAccessibility: (() -> Bool)?
    private let resetUsage: (() async -> Void)?
    private let clearPins: (() async -> Void)?
    private let clearClipboardHistory: (() async -> Void)?
    private let revealUsageFile: (() -> Void)?

    /// Assigned by the composition root once the welcome window exists.
    @ObservationIgnored public var onShowWelcome: (() -> Void)?

    public init(
        preferencesStore: PreferencesStoring,
        onHotkeyChanged: ((Hotkey) async -> Bool)? = nil,
        onClipboardHotkeyChanged: ((Hotkey) async -> Bool)? = nil,
        onPreferencesChanged: ((Preferences) -> Void)? = nil,
        getLaunchAtLogin: (() -> Bool)? = nil,
        setLaunchAtLogin: ((Bool) throws -> Void)? = nil,
        checkAccessibility: (() -> Bool)? = nil,
        resetUsage: (() async -> Void)? = nil,
        clearPins: (() async -> Void)? = nil,
        clearClipboardHistory: (() async -> Void)? = nil,
        revealUsageFile: (() -> Void)? = nil
    ) {
        self.preferencesStore = preferencesStore
        self.preferences = .default
        self.onHotkeyChanged = onHotkeyChanged
        self.onClipboardHotkeyChanged = onClipboardHotkeyChanged
        self.onPreferencesChanged = onPreferencesChanged
        self.getLaunchAtLogin = getLaunchAtLogin
        self.setLaunchAtLogin = setLaunchAtLogin
        self.checkAccessibility = checkAccessibility
        self.resetUsage = resetUsage
        self.clearPins = clearPins
        self.clearClipboardHistory = clearClipboardHistory
        self.revealUsageFile = revealUsageFile
    }

    public func load() async {
        preferences = await preferencesStore.load()
        refreshStatus()
    }

    public func refreshStatus() {
        if let checkAccessibility {
            isAccessibilityGranted = checkAccessibility()
        }
        if let getLaunchAtLogin {
            isLaunchAtLoginEnabled = getLaunchAtLogin()
        }
    }

    public func updateHotkey(_ newHotkey: Hotkey) {
        guard preferences.hotkey != newHotkey else { return }
        let previous = preferences.hotkey
        preferences.hotkey = newHotkey
        hotkeyError = nil

        Task {
            let registered = await onHotkeyChanged?(newHotkey) ?? true
            isHotkeyRegistered = registered
            guard registered else {
                // Keep the working shortcut; the recorder shows the old one again.
                preferences.hotkey = previous
                hotkeyError = String(
                    localized: "That shortcut is already used by another app."
                )
                return
            }
            await preferencesStore.save(preferences)
        }
    }

    public func updateFileSearchEnabled(_ enabled: Bool) {
        preferences.fileSearchEnabled = enabled
        save()
    }

    public func updateSuggestionWindowDays(_ days: Int) {
        guard preferences.suggestionWindowDays != days else { return }
        preferences.suggestionWindowDays = days
        save()
    }

    public func updateApplicationsPerPage(_ count: Int) {
        guard preferences.applicationsPerPage != count else { return }
        preferences.applicationsPerPage = count
        save()
    }

    public func updateStatusBarEnabled(_ enabled: Bool) {
        guard preferences.statusBarEnabled != enabled else { return }
        preferences.statusBarEnabled = enabled
        save()
    }

    public func updateShowKeyboardHints(_ enabled: Bool) {
        guard preferences.showKeyboardHints != enabled else { return }
        preferences.showKeyboardHints = enabled
        save()
    }

    public func updateClipboardHistoryEnabled(_ enabled: Bool) {
        guard preferences.clipboardHistoryEnabled != enabled else { return }
        preferences.clipboardHistoryEnabled = enabled
        save()
    }

    public func updateClipboardHistoryLimit(_ limit: Int) {
        guard preferences.clipboardHistoryLimit != limit else { return }
        preferences.clipboardHistoryLimit = limit
        save()
    }

    public func updateClipboardDirectPaste(_ enabled: Bool) {
        guard preferences.clipboardDirectPaste != enabled else { return }
        preferences.clipboardDirectPaste = enabled
        save()
    }

    public func updateClipboardSaveImages(_ enabled: Bool) {
        guard preferences.clipboardSaveImages != enabled else { return }
        preferences.clipboardSaveImages = enabled
        save()
    }

    public func updateCurrencyConversionEnabled(_ enabled: Bool) {
        guard preferences.currencyConversionEnabled != enabled else { return }
        preferences.currencyConversionEnabled = enabled
        save()
    }

    public func updateClipboardHotkey(_ newHotkey: Hotkey) async {
        guard newHotkey != preferences.clipboardHotkey else { return }
        let previousHotkey = preferences.clipboardHotkey
        preferences.clipboardHotkey = newHotkey

        let registered = await onClipboardHotkeyChanged?(newHotkey) ?? true
        isClipboardHotkeyRegistered = registered

        guard registered else {
            preferences.clipboardHotkey = previousHotkey
            clipboardHotkeyError = String(localized: "This shortcut is in use by another application.")
            return
        }

        clipboardHotkeyError = nil
        save()
    }

    public func clearClipboardHistoryAction() {
        Task {
            await clearClipboardHistory?()
        }
    }

    /// Restores every preference except onboarding completion, so the welcome
    /// window does not come back. A hotkey conflict keeps the working shortcut.
    public func resetToDefaults() {
        let previousHotkey = preferences.hotkey
        let completed = preferences.hasCompletedOnboarding
        preferences = .default
        preferences.hasCompletedOnboarding = completed
        hotkeyError = nil

        guard previousHotkey != preferences.hotkey else {
            save()
            return
        }

        Task {
            let registered = await onHotkeyChanged?(preferences.hotkey) ?? true
            isHotkeyRegistered = registered
            guard registered else {
                preferences.hotkey = previousHotkey
                hotkeyError = String(
                    localized: "The default shortcut is already used by another app. The other settings were reset."
                )
                save()
                return
            }
            await preferencesStore.save(preferences)
            onPreferencesChanged?(preferences)
        }
    }

    public func toggleLaunchAtLogin(_ enabled: Bool) {
        guard let setLaunchAtLogin else { return }
        do {
            try setLaunchAtLogin(enabled)
            isLaunchAtLoginEnabled = enabled
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
            refreshStatus()
        }
    }

    public func clearUsageHistory() {
        Task {
            await resetUsage?()
        }
    }

    public func clearPinnedItems() {
        Task {
            await clearPins?()
        }
    }

    public func showWelcomeWindow() {
        onShowWelcome?()
    }

    public func revealUsageData() {
        revealUsageFile?()
    }

    private func save() {
        let snapshot = preferences
        Task {
            await preferencesStore.save(snapshot)
            // Apply after persisting: the palette re-runs its search and reads
            // these values back from the store.
            onPreferencesChanged?(snapshot)
        }
    }
}
