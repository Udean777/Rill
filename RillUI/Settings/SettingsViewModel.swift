import Observation
import RillDomain
import Foundation

/// Presentation state for the Settings window 
@MainActor
@Observable
public final class SettingsViewModel {
    public var preferences: Preferences
    public var isAccessibilityGranted: Bool = false
    public var isLaunchAtLoginEnabled: Bool = false
    public var launchAtLoginError: String?

    private let preferencesStore: PreferencesStoring
    private let onHotkeyChanged: ((Hotkey) async -> Void)?
    private let getLaunchAtLogin: (() -> Bool)?
    private let setLaunchAtLogin: ((Bool) throws -> Void)?
    private let checkAccessibility: (() -> Bool)?

    public init(
        preferencesStore: PreferencesStoring,
        onHotkeyChanged: ((Hotkey) async -> Void)? = nil,
        getLaunchAtLogin: (() -> Bool)? = nil,
        setLaunchAtLogin: ((Bool) throws -> Void)? = nil,
        checkAccessibility: (() -> Bool)? = nil
    ) {
        self.preferencesStore = preferencesStore
        self.preferences = .default
        self.onHotkeyChanged = onHotkeyChanged
        self.getLaunchAtLogin = getLaunchAtLogin
        self.setLaunchAtLogin = setLaunchAtLogin
        self.checkAccessibility = checkAccessibility
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
        preferences.hotkey = newHotkey
        Task {
            await preferencesStore.save(preferences)
            if let onHotkeyChanged {
                await onHotkeyChanged(newHotkey)
            }
        }
    }

    public func updateFileSearchEnabled(_ enabled: Bool) {
        preferences.fileSearchEnabled = enabled
        Task {
            await preferencesStore.save(preferences)
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
}
