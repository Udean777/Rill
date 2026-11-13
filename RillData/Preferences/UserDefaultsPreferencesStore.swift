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
        static let fileSearchIncludeFiles = "preferences.fileSearch.includeFiles"
        static let fileSearchIncludeFolders = "preferences.fileSearch.includeFolders"
        static let fileSearchIncludeHidden = "preferences.fileSearch.includeHidden"
        static let fileSearchCustomPaths = "preferences.fileSearch.customPaths"
        static let fileSearchExcludedPaths = "preferences.fileSearch.excludedPaths"
        static let suggestionWindowDays = "preferences.suggestions.windowDays"
        static let applicationsPerPage = "preferences.applications.perPage"
        static let statusBarEnabled = "preferences.statusBar.enabled"
        static let showKeyboardHints = "preferences.palette.keyboardHints"
        static let completedOnboarding = "preferences.onboarding.completed"
        static let clipboardHistoryEnabled = "preferences.clipboard.historyEnabled"
        static let clipboardHotkeyKeyCode = "preferences.clipboard.hotkey.keyCode"
        static let clipboardHotkeyModifiers = "preferences.clipboard.hotkey.modifiers"
        static let clipboardHistoryLimit = "preferences.clipboard.historyLimit"
        static let clipboardDirectPaste = "preferences.clipboard.directPaste"
        static let clipboardSaveImages = "preferences.clipboard.saveImages"
        static let currencyConversionEnabled = "preferences.currency.enabled"
        static let calculatorEnabled = "preferences.calculator.enabled"
        static let webSearchEnabled = "preferences.webSearch.enabled"
        static let hiddenSections = "preferences.sections.hidden"
    }

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func load() async -> Preferences {
        let defaults = Preferences.default
        let scopeString = userDefaults.string(forKey: Key.fileSearchScope) ?? ""
        let scope = FileSearchScope(rawValue: scopeString) ?? defaults.fileSearchScope

        return Preferences(
            hotkey: loadHotkey(
                keyCodeKey: Key.hotkeyKeyCode,
                modifiersKey: Key.hotkeyModifiers,
                default: defaults.hotkey
            ),
            fileSearchEnabled: value(forKey: Key.fileSearchEnabled, default: defaults.fileSearchEnabled),
            fileSearchScope: scope,
            fileSearchIncludeFiles: value(forKey: Key.fileSearchIncludeFiles, default: defaults.fileSearchIncludeFiles),
            fileSearchIncludeFolders: value(forKey: Key.fileSearchIncludeFolders, default: defaults.fileSearchIncludeFolders),
            fileSearchIncludeHidden: value(forKey: Key.fileSearchIncludeHidden, default: defaults.fileSearchIncludeHidden),
            fileSearchCustomPaths: userDefaults.stringArray(forKey: Key.fileSearchCustomPaths)
                ?? defaults.fileSearchCustomPaths,
            fileSearchExcludedPaths: userDefaults.stringArray(forKey: Key.fileSearchExcludedPaths)
                ?? defaults.fileSearchExcludedPaths,
            suggestionWindowDays: value(forKey: Key.suggestionWindowDays, default: defaults.suggestionWindowDays),
            applicationsPerPage: value(forKey: Key.applicationsPerPage, default: defaults.applicationsPerPage),
            statusBarEnabled: value(forKey: Key.statusBarEnabled, default: defaults.statusBarEnabled),
            showKeyboardHints: value(forKey: Key.showKeyboardHints, default: defaults.showKeyboardHints),
            hasCompletedOnboarding: value(forKey: Key.completedOnboarding, default: defaults.hasCompletedOnboarding),
            clipboardHistoryEnabled: value(forKey: Key.clipboardHistoryEnabled, default: defaults.clipboardHistoryEnabled),
            clipboardHotkey: loadHotkey(
                keyCodeKey: Key.clipboardHotkeyKeyCode,
                modifiersKey: Key.clipboardHotkeyModifiers,
                default: defaults.clipboardHotkey
            ),
            clipboardHistoryLimit: value(forKey: Key.clipboardHistoryLimit, default: defaults.clipboardHistoryLimit),
            clipboardDirectPaste: value(forKey: Key.clipboardDirectPaste, default: defaults.clipboardDirectPaste),
            clipboardSaveImages: value(forKey: Key.clipboardSaveImages, default: defaults.clipboardSaveImages),
            currencyConversionEnabled: value(forKey: Key.currencyConversionEnabled, default: defaults.currencyConversionEnabled),
            calculatorEnabled: value(forKey: Key.calculatorEnabled, default: defaults.calculatorEnabled),
            webSearchEnabled: value(forKey: Key.webSearchEnabled, default: defaults.webSearchEnabled),
            hiddenSections: Set(
                (userDefaults.stringArray(forKey: Key.hiddenSections) ?? [])
                    .compactMap(Section.init(rawValue:))
            )
        ).sanitized()
    }

    private func value<T>(forKey key: String, default fallback: T) -> T {
        userDefaults.object(forKey: key) as? T ?? fallback
    }

    private func loadHotkey(keyCodeKey: String, modifiersKey: String, default fallback: Hotkey) -> Hotkey {
        guard let rawKeyCode = userDefaults.object(forKey: keyCodeKey) as? UInt32,
              let rawModifiers = userDefaults.object(forKey: modifiersKey) as? UInt32 else {
            return fallback
        }
        return Hotkey(keyCode: rawKeyCode, modifiers: HotkeyModifiers(rawValue: rawModifiers))
    }

    public func save(_ preferences: Preferences) async {
        userDefaults.set(preferences.hotkey.keyCode, forKey: Key.hotkeyKeyCode)
        userDefaults.set(preferences.hotkey.modifiers.rawValue, forKey: Key.hotkeyModifiers)
        userDefaults.set(preferences.fileSearchEnabled, forKey: Key.fileSearchEnabled)
        userDefaults.set(preferences.fileSearchScope.rawValue, forKey: Key.fileSearchScope)
        userDefaults.set(preferences.fileSearchIncludeFiles, forKey: Key.fileSearchIncludeFiles)
        userDefaults.set(preferences.fileSearchIncludeFolders, forKey: Key.fileSearchIncludeFolders)
        userDefaults.set(preferences.fileSearchIncludeHidden, forKey: Key.fileSearchIncludeHidden)
        userDefaults.set(preferences.fileSearchCustomPaths, forKey: Key.fileSearchCustomPaths)
        userDefaults.set(preferences.fileSearchExcludedPaths, forKey: Key.fileSearchExcludedPaths)
        userDefaults.set(preferences.suggestionWindowDays, forKey: Key.suggestionWindowDays)
        userDefaults.set(preferences.applicationsPerPage, forKey: Key.applicationsPerPage)
        userDefaults.set(preferences.statusBarEnabled, forKey: Key.statusBarEnabled)
        userDefaults.set(preferences.showKeyboardHints, forKey: Key.showKeyboardHints)
        userDefaults.set(preferences.clipboardHistoryEnabled, forKey: Key.clipboardHistoryEnabled)
        userDefaults.set(preferences.clipboardHotkey.keyCode, forKey: Key.clipboardHotkeyKeyCode)
        userDefaults.set(preferences.clipboardHotkey.modifiers.rawValue, forKey: Key.clipboardHotkeyModifiers)
        userDefaults.set(preferences.clipboardHistoryLimit, forKey: Key.clipboardHistoryLimit)
        userDefaults.set(preferences.clipboardDirectPaste, forKey: Key.clipboardDirectPaste)
        userDefaults.set(preferences.clipboardSaveImages, forKey: Key.clipboardSaveImages)
        userDefaults.set(preferences.currencyConversionEnabled, forKey: Key.currencyConversionEnabled)
        userDefaults.set(preferences.calculatorEnabled, forKey: Key.calculatorEnabled)
        userDefaults.set(preferences.webSearchEnabled, forKey: Key.webSearchEnabled)
        userDefaults.set(
            preferences.hiddenSections.map(\.rawValue).sorted(),
            forKey: Key.hiddenSections
        )
        // Monotonic: a stale settings snapshot must never resurrect the welcome
        // window after onboarding has been completed.
        let completed =
            userDefaults.object(forKey: Key.completedOnboarding) as? Bool ?? false
        userDefaults.set(preferences.hasCompletedOnboarding || completed, forKey: Key.completedOnboarding)
    }
}
