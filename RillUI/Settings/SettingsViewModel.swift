import Foundation
import Observation
import RillDomain

public struct SettingsActions {
    public var onHotkeyChanged: ((Hotkey) async -> Bool)?
    public var onClipboardHotkeyChanged: ((Hotkey) async -> Bool)?
    public var onPreferencesChanged: ((Preferences) -> Void)?
    public var getLaunchAtLogin: (() -> Bool)?
    public var setLaunchAtLogin: ((Bool) throws -> Void)?
    public var checkAccessibility: (() -> Bool)?
    public var resetUsage: (() async -> Void)?
    public var clearPins: (() async -> Void)?
    public var clearClipboardHistory: (() async -> Void)?
    public var revealUsageFile: (() -> Void)?
    public var openAccessibilitySettings: (() async -> Void)?
    public var checkFullDiskAccess: (() -> Bool)?
    public var openFullDiskAccessSettings: (() async -> Void)?
    public var requestProtectedFolderAccess: (() async -> Void)?
    public var revealApplicationInFinder: (() -> Void)?

    public init(
        onHotkeyChanged: ((Hotkey) async -> Bool)? = nil,
        onClipboardHotkeyChanged: ((Hotkey) async -> Bool)? = nil,
        onPreferencesChanged: ((Preferences) -> Void)? = nil,
        getLaunchAtLogin: (() -> Bool)? = nil,
        setLaunchAtLogin: ((Bool) throws -> Void)? = nil,
        checkAccessibility: (() -> Bool)? = nil,
        resetUsage: (() async -> Void)? = nil,
        clearPins: (() async -> Void)? = nil,
        clearClipboardHistory: (() async -> Void)? = nil,
        revealUsageFile: (() -> Void)? = nil,
        openAccessibilitySettings: (() async -> Void)? = nil,
        checkFullDiskAccess: (() -> Bool)? = nil,
        openFullDiskAccessSettings: (() async -> Void)? = nil,
        requestProtectedFolderAccess: (() async -> Void)? = nil,
        revealApplicationInFinder: (() -> Void)? = nil
    ) {
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
        self.openAccessibilitySettings = openAccessibilitySettings
        self.checkFullDiskAccess = checkFullDiskAccess
        self.openFullDiskAccessSettings = openFullDiskAccessSettings
        self.requestProtectedFolderAccess = requestProtectedFolderAccess
        self.revealApplicationInFinder = revealApplicationInFinder
    }
}

/// Presentation state for the Settings window.
@MainActor
@Observable
public final class SettingsViewModel {
    public var preferences: Preferences
    public var isAccessibilityGranted: Bool = false
    public var isFullDiskAccessGranted: Bool = false
    public var isRequestingFolderAccess: Bool = false
    public var isLaunchAtLoginEnabled: Bool = false
    public var launchAtLoginError: String?
    public var hotkeyError: String?
    /// Whether the stored shortcut is currently registered with the system.
    public var isHotkeyRegistered = true
    public var clipboardHotkeyError: String?
    public var isClipboardHotkeyRegistered = true
    public var updateState: UpdateState = .idle

    private let preferencesStore: PreferencesStoring
    private let actions: SettingsActions

    /// Assigned by the composition root once the welcome window exists.
    @ObservationIgnored public var onShowWelcome: (() -> Void)?
    @ObservationIgnored public var onCheckForUpdates: (() -> Void)?
    @ObservationIgnored public var onInstallUpdate: (() -> Void)?
    @ObservationIgnored public var onRestartToUpdate: (() -> Void)?

    public init(
        preferencesStore: PreferencesStoring,
        actions: SettingsActions = SettingsActions()
    ) {
        self.preferencesStore = preferencesStore
        self.preferences = .default
        self.actions = actions
    }

    public func load() async {
        preferences = await preferencesStore.load()
        refreshStatus()
    }

    public func refreshStatus() {
        if let checkAccessibility = actions.checkAccessibility {
            isAccessibilityGranted = checkAccessibility()
        }
        if let checkFullDiskAccess = actions.checkFullDiskAccess {
            isFullDiskAccessGranted = checkFullDiskAccess()
        }
        if let getLaunchAtLogin = actions.getLaunchAtLogin {
            isLaunchAtLoginEnabled = getLaunchAtLogin()
        }
    }

    public func updateHotkey(_ newHotkey: Hotkey) {
        guard preferences.hotkey != newHotkey else { return }
        Task {
            await applyHotkey(
                newHotkey,
                keyPath: \.hotkey,
                registeredKeyPath: \.isHotkeyRegistered,
                errorKeyPath: \.hotkeyError,
                conflictMessage: String(localized: "That shortcut is already used by another app."),
                register: actions.onHotkeyChanged
            )
        }
    }

    /// Updates any equatable preference field and persists the change.
    public func update<Value: Equatable>(
        _ keyPath: WritableKeyPath<Preferences, Value>,
        to value: Value
    ) {
        guard preferences[keyPath: keyPath] != value else { return }
        preferences[keyPath: keyPath] = value
        save()
    }

    public func addFileSearchCustomPath(_ path: String) {
        addPath(path, to: \.fileSearchCustomPaths)
    }

    public func removeFileSearchCustomPath(_ path: String) {
        removePath(path, from: \.fileSearchCustomPaths)
    }

    public func addFileSearchExcludedPath(_ path: String) {
        addPath(path, to: \.fileSearchExcludedPaths)
    }

    public func removeFileSearchExcludedPath(_ path: String) {
        removePath(path, from: \.fileSearchExcludedPaths)
    }

    private func addPath(_ path: String, to keyPath: WritableKeyPath<Preferences, [String]>) {
        let normalized = Self.normalizePath(path)
        guard !normalized.isEmpty, !preferences[keyPath: keyPath].contains(normalized) else { return }
        preferences[keyPath: keyPath].append(normalized)
        save()
    }

    private func removePath(_ path: String, from keyPath: WritableKeyPath<Preferences, [String]>) {
        preferences[keyPath: keyPath].removeAll { $0 == path }
        save()
    }

    private static func normalizePath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 1, trimmed.hasSuffix("/") else { return trimmed }
        return String(trimmed.dropLast())
    }

    public func updateSectionVisibility(_ section: Section, isVisible: Bool) {
        if isVisible {
            preferences.hiddenSections.remove(section)
        } else {
            preferences.hiddenSections.insert(section)
        }
        save()
    }

    public func updateClipboardHotkey(_ newHotkey: Hotkey) async {
        guard newHotkey != preferences.clipboardHotkey else { return }
        await applyHotkey(
            newHotkey,
            keyPath: \.clipboardHotkey,
            registeredKeyPath: \.isClipboardHotkeyRegistered,
            errorKeyPath: \.clipboardHotkeyError,
            conflictMessage: String(localized: "This shortcut is in use by another application."),
            register: actions.onClipboardHotkeyChanged
        )
    }

    private func applyHotkey(
        _ newHotkey: Hotkey,
        keyPath: WritableKeyPath<Preferences, Hotkey>,
        registeredKeyPath: ReferenceWritableKeyPath<SettingsViewModel, Bool>,
        errorKeyPath: ReferenceWritableKeyPath<SettingsViewModel, String?>,
        conflictMessage: String,
        register: ((Hotkey) async -> Bool)?
    ) async {
        let previous = preferences[keyPath: keyPath]
        preferences[keyPath: keyPath] = newHotkey
        self[keyPath: errorKeyPath] = nil

        let registered = await register?(newHotkey) ?? true
        self[keyPath: registeredKeyPath] = registered
        guard registered else {
            preferences[keyPath: keyPath] = previous
            self[keyPath: errorKeyPath] = conflictMessage
            return
        }
        await preferencesStore.save(preferences)
    }

    public func clearClipboardHistoryAction() {
        Task {
            await actions.clearClipboardHistory?()
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
            let registered = await actions.onHotkeyChanged?(preferences.hotkey) ?? true
            isHotkeyRegistered = registered
            guard registered else {
                preferences.hotkey = previousHotkey
                hotkeyError = String(
                    localized: "The default shortcut is already used by another app. The other settings were reset."
                )
                save()
                return
            }
            save()
        }
    }

    public func toggleLaunchAtLogin(_ enabled: Bool) {
        guard let setLaunchAtLogin = actions.setLaunchAtLogin else { return }
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
            await actions.resetUsage?()
        }
    }

    public func clearPinnedItems() {
        Task {
            await actions.clearPins?()
        }
    }

    public func showWelcomeWindow() {
        onShowWelcome?()
    }

    public func revealUsageData() {
        actions.revealUsageFile?()
    }

    public func openAccessibilitySettings() {
        Task {
            await actions.openAccessibilitySettings?()
            refreshStatus()
        }
    }

    public func openFullDiskAccessSettings() {
        Task {
            await actions.openFullDiskAccessSettings?()
            refreshStatus()
        }
    }

    public func revealApplicationInFinder() {
        actions.revealApplicationInFinder?()
    }

    public func requestProtectedFolderAccess() {
        guard !isRequestingFolderAccess else { return }
        isRequestingFolderAccess = true
        Task {
            await actions.requestProtectedFolderAccess?()
            isRequestingFolderAccess = false
            refreshStatus()
        }
    }

    public func checkForUpdates() {
        onCheckForUpdates?()
    }

    public func installUpdate() {
        onInstallUpdate?()
    }

    public func restartToUpdate() {
        onRestartToUpdate?()
    }

    private func save() {
        let snapshot = preferences
        Task {
            await preferencesStore.save(snapshot)
            // Apply after persisting: the palette re-runs its search and reads
            // these values back from the store.
            actions.onPreferencesChanged?(snapshot)
        }
    }
}
