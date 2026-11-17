import Foundation
import Observation
import RillDomain

/// Facade over the Settings window's editors. Each collaborator owns one slice
/// of the state; the views read `preferences.values`, `hotkeys`, `permissions`,
/// and `updates` directly.
@MainActor
@Observable
public final class SettingsViewModel {
    public let preferences: PreferencesEditor
    public let hotkeys: HotkeyCoordinator
    public let permissions: PermissionsStatus
    public let updates = UpdateStatus()

    /// Assigned by the composition root once the welcome window exists.
    @ObservationIgnored public var onShowWelcome: (() -> Void)?

    @ObservationIgnored private var dataActions = SettingsDataActions()

    public init(preferencesStore: PreferencesStoring) {
        let editor = PreferencesEditor(store: preferencesStore)
        self.preferences = editor
        self.hotkeys = HotkeyCoordinator(editor: editor)
        self.permissions = PermissionsStatus()
    }

    /// Wired by the composition root after the environment exists, so the
    /// callbacks can reference it weakly.
    public func configure(
        preferencesActions: SettingsPreferencesActions,
        permissionsActions: SettingsPermissionsActions,
        dataActions: SettingsDataActions
    ) {
        preferences.onChanged = preferencesActions.onPreferencesChanged
        hotkeys.configure(actions: preferencesActions)
        permissions.configure(actions: permissionsActions)
        self.dataActions = dataActions
    }

    public func load() async {
        await preferences.load()
        permissions.refresh()
    }

    /// Refreshes status and, when the system pinch setting changed, tells the
    /// composition root so the gesture monitor follows.
    public func refreshStatusAndReapplyPreferences() {
        let previous = permissions.isSystemFourFingerPinchDisabled
        permissions.refresh()
        guard permissions.isSystemFourFingerPinchDisabled != previous else { return }
        preferences.onChanged?(preferences.values)
    }

    /// Restores every preference except onboarding completion, so the welcome
    /// window does not come back. A hotkey conflict keeps the working shortcut.
    public func resetToDefaults() {
        let previousHotkey = preferences.values.hotkey
        preferences.resetToDefaults()
        hotkeys.primaryError = nil

        guard previousHotkey != preferences.values.hotkey else {
            Task { await preferences.persist() }
            return
        }

        Task {
            let registered = await hotkeys.registerPrimary(preferences.values.hotkey)
            guard registered else {
                preferences.restorePrimaryHotkey(previousHotkey)
                hotkeys.primaryError = String(
                    localized: "The default shortcut is already used by another app. The other settings were reset."
                )
                await preferences.persist()
                return
            }
            await preferences.persist()
            preferences.onChanged?(preferences.values)
        }
    }

    public func resetApplicationsLayoutAction() {
        Task {
            await dataActions.resetApplicationsLayout?()
        }
    }

    public func clearClipboardHistoryAction() {
        Task {
            await dataActions.clearClipboardHistory?()
        }
    }

    public func clearUsageHistory() {
        Task {
            await dataActions.resetUsage?()
        }
    }

    public func clearPinnedItems() {
        Task {
            await dataActions.clearPins?()
        }
    }

    public func revealUsageData() {
        dataActions.revealUsageFile?()
    }

    public func showWelcomeWindow() {
        onShowWelcome?()
    }
}
