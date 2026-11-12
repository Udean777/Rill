import Foundation
import RillDomain

/// Persists application preferences to `UserDefaults`
public actor UserDefaultsPreferencesStore: PreferencesStoring {
    private let userDefaults: UserDefaults

    private enum Key {
        static let hotkeyKeyCode = "preferences.hotkey.keyCode"
        static let hotkeyModifiers = "preferences.hotkey.modifiers"
        static let fileSearchEnabled = "preferences.fileSearch.enabled"
        static let fileSearchScope = "preferences.fileSearch.scope"
    }

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func load() async -> Preferences {
        let fileSearchEnabled = userDefaults.object(forKey: Key.fileSearchEnabled) as? Bool ?? Preferences.default.fileSearchEnabled

        let hotkey: Hotkey
        if let rawKeyCode = userDefaults.object(forKey: Key.hotkeyKeyCode) as? UInt32,
           let rawModifiers = userDefaults.object(forKey: Key.hotkeyModifiers) as? UInt32 {
            hotkey = Hotkey(keyCode: rawKeyCode, modifiers: HotkeyModifiers(rawValue: rawModifiers))
        } else {
            hotkey = Preferences.default.hotkey
        }

        let scopeString = userDefaults.string(forKey: Key.fileSearchScope) ?? ""
        let scope = FileSearchScope(rawValue: scopeString) ?? Preferences.default.fileSearchScope

        return Preferences(
            hotkey: hotkey,
            fileSearchEnabled: fileSearchEnabled,
            fileSearchScope: scope
        )
    }

    public func save(_ preferences: Preferences) async {
        userDefaults.set(preferences.hotkey.keyCode, forKey: Key.hotkeyKeyCode)
        userDefaults.set(preferences.hotkey.modifiers.rawValue, forKey: Key.hotkeyModifiers)
        userDefaults.set(preferences.fileSearchEnabled, forKey: Key.fileSearchEnabled)
        userDefaults.set(preferences.fileSearchScope.rawValue, forKey: Key.fileSearchScope)
    }
}
