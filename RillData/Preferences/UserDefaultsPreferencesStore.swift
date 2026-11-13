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
        let fileSearchEnabled = userDefaults.object(forKey: Key.fileSearchEnabled) as? Bool ?? Preferences.default.fileSearchEnabled

        let hotkey: Hotkey
        if let rawKeyCode = userDefaults.object(forKey: Key.hotkeyKeyCode) as? UInt32,
           let rawModifiers = userDefaults.object(forKey: Key.hotkeyModifiers) as? UInt32 {
            hotkey = Hotkey(keyCode: rawKeyCode, modifiers: HotkeyModifiers(rawValue: rawModifiers))
        } else {
            hotkey = Preferences.default.hotkey
        }

        let clipboardHotkey: Hotkey
        if let rawKeyCode = userDefaults.object(forKey: Key.clipboardHotkeyKeyCode) as? UInt32,
           let rawModifiers = userDefaults.object(forKey: Key.clipboardHotkeyModifiers) as? UInt32 {
            clipboardHotkey = Hotkey(keyCode: rawKeyCode, modifiers: HotkeyModifiers(rawValue: rawModifiers))
        } else {
            clipboardHotkey = Preferences.default.clipboardHotkey
        }

        let scopeString = userDefaults.string(forKey: Key.fileSearchScope) ?? ""
        let scope = FileSearchScope(rawValue: scopeString) ?? Preferences.default.fileSearchScope

        return Preferences(
            hotkey: hotkey,
            fileSearchEnabled: fileSearchEnabled,
            fileSearchScope: scope,
            fileSearchIncludeFiles: userDefaults.object(forKey: Key.fileSearchIncludeFiles) as? Bool
                ?? Preferences.default.fileSearchIncludeFiles,
            fileSearchIncludeFolders: userDefaults.object(forKey: Key.fileSearchIncludeFolders) as? Bool
                ?? Preferences.default.fileSearchIncludeFolders,
            fileSearchIncludeHidden: userDefaults.object(forKey: Key.fileSearchIncludeHidden) as? Bool
                ?? Preferences.default.fileSearchIncludeHidden,
            fileSearchCustomPaths: userDefaults.stringArray(forKey: Key.fileSearchCustomPaths)
                ?? Preferences.default.fileSearchCustomPaths,
            fileSearchExcludedPaths: userDefaults.stringArray(forKey: Key.fileSearchExcludedPaths)
                ?? Preferences.default.fileSearchExcludedPaths,
            suggestionWindowDays: userDefaults.object(forKey: Key.suggestionWindowDays) as? Int
                ?? Preferences.default.suggestionWindowDays,
            applicationsPerPage: userDefaults.object(forKey: Key.applicationsPerPage) as? Int
                ?? Preferences.default.applicationsPerPage,
            statusBarEnabled: userDefaults.object(forKey: Key.statusBarEnabled) as? Bool
                ?? Preferences.default.statusBarEnabled,
            showKeyboardHints: userDefaults.object(forKey: Key.showKeyboardHints) as? Bool
                ?? Preferences.default.showKeyboardHints,
            hasCompletedOnboarding: userDefaults.object(forKey: Key.completedOnboarding) as? Bool
                ?? Preferences.default.hasCompletedOnboarding,
            clipboardHistoryEnabled: userDefaults.object(forKey: Key.clipboardHistoryEnabled) as? Bool
                ?? Preferences.default.clipboardHistoryEnabled,
            clipboardHotkey: clipboardHotkey,
            clipboardHistoryLimit: userDefaults.object(forKey: Key.clipboardHistoryLimit) as? Int
                ?? Preferences.default.clipboardHistoryLimit,
            clipboardDirectPaste: userDefaults.object(forKey: Key.clipboardDirectPaste) as? Bool
                ?? Preferences.default.clipboardDirectPaste,
            clipboardSaveImages: userDefaults.object(forKey: Key.clipboardSaveImages) as? Bool
                ?? Preferences.default.clipboardSaveImages,
            currencyConversionEnabled: userDefaults.object(forKey: Key.currencyConversionEnabled) as? Bool
                ?? Preferences.default.currencyConversionEnabled,
            calculatorEnabled: userDefaults.object(forKey: Key.calculatorEnabled) as? Bool
                ?? Preferences.default.calculatorEnabled,
            webSearchEnabled: userDefaults.object(forKey: Key.webSearchEnabled) as? Bool
                ?? Preferences.default.webSearchEnabled,
            hiddenSections: Set(
                (userDefaults.stringArray(forKey: Key.hiddenSections) ?? [])
                    .compactMap(Section.init(rawValue:))
            )
        ).sanitized()
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
