import Foundation

/// User-configurable application preferences.
public struct Preferences: Sendable, Equatable {
    public var hotkey: Hotkey
    public var fileSearchEnabled: Bool
    public var fileSearchScope: FileSearchScope
    /// Whether regular files appear in file search results.
    public var fileSearchIncludeFiles: Bool
    /// Whether folders appear in file search results.
    public var fileSearchIncludeFolders: Bool
    /// Whether hidden (dot-prefixed / invisible) files and folders appear in file search results.
    public var fileSearchIncludeHidden: Bool
    /// Custom directory paths searched when `fileSearchScope == .custom`.
    public var fileSearchCustomPaths: [String]
    /// Directory paths excluded from file search results.
    public var fileSearchExcludedPaths: [String]
    /// How far back suggested apps look.
    public var suggestionWindowDays: Int
    /// Applications shown per page in the root layout.
    public var applicationsPerPage: Int
    /// Whether Rill installs a menu bar status item.
    public var statusBarEnabled: Bool
    /// Whether the palette's root layout shows the keyboard hint row.
    public var showKeyboardHints: Bool
    /// Set once the first-run welcome window has been shown and dismissed.
    public var hasCompletedOnboarding: Bool
    /// Whether clipboard history is recorded.
    public var clipboardHistoryEnabled: Bool
    /// Global hotkey to open clipboard history directly.
    public var clipboardHotkey: Hotkey
    /// Maximum number of clipboard history items retained.
    public var clipboardHistoryLimit: Int
    /// Whether Enter pastes directly into the target app.
    public var clipboardDirectPaste: Bool
    /// Whether copied images are stored in clipboard history.
    public var clipboardSaveImages: Bool
    /// Whether typing a currency amount converts it to the user's local currency.
    public var currencyConversionEnabled: Bool
    /// Whether math expressions are evaluated in the palette.
    public var calculatorEnabled: Bool
    /// Whether the web search fallback row appears for typed queries.
    public var webSearchEnabled: Bool
    /// Bundle identifier of the browser used to open web URLs, or `nil` for the system default.
    public var defaultBrowserBundleID: String?
    /// Whether the floating Applications grid launcher is enabled.
    public var applicationsLauncherEnabled: Bool
    /// Whether the 4-finger trackpad pinch gesture toggles the Applications grid.
    public var applicationsPinchGestureEnabled: Bool
    /// Pinch sensitivity ratio (`0.10...0.45`). Lower values trigger more easily.
    public var applicationsPinchSensitivity: Double
    /// Global hotkey to toggle the Applications grid launcher.
    public var applicationsHotkey: Hotkey
    /// Number of columns in the Applications grid.
    public var applicationsGridColumns: Int
    /// Number of rows per page in the Applications grid.
    public var applicationsGridRows: Int
    /// Sections the user chose to hide from the palette. Store what is hidden,
    /// not what is visible, so a section added later shows up by default.
    public var hiddenSections: Set<Section>

    public init(
        hotkey: Hotkey = .default,
        fileSearchEnabled: Bool = true,
        fileSearchScope: FileSearchScope = .homeDirectory,
        fileSearchIncludeFiles: Bool = true,
        fileSearchIncludeFolders: Bool = true,
        fileSearchIncludeHidden: Bool = false,
        fileSearchCustomPaths: [String] = [],
        fileSearchExcludedPaths: [String] = [],
        suggestionWindowDays: Int = 7,
        applicationsPerPage: Int = 5,
        statusBarEnabled: Bool = true,
        showKeyboardHints: Bool = true,
        hasCompletedOnboarding: Bool = false,
        clipboardHistoryEnabled: Bool = true,
        clipboardHotkey: Hotkey = Hotkey(keyCode: 9, modifiers: [.option, .command]),
        clipboardHistoryLimit: Int = 500,
        clipboardDirectPaste: Bool = true,
        clipboardSaveImages: Bool = true,
        currencyConversionEnabled: Bool = true,
        calculatorEnabled: Bool = true,
        webSearchEnabled: Bool = true,
        defaultBrowserBundleID: String? = nil,
        applicationsLauncherEnabled: Bool = true,
        applicationsPinchGestureEnabled: Bool = true,
        applicationsPinchSensitivity: Double = 0.22,
        applicationsHotkey: Hotkey = Hotkey(keyCode: 0, modifiers: [.option]),
        applicationsGridColumns: Int = 7,
        applicationsGridRows: Int = 5,
        hiddenSections: Set<Section> = []
    ) {
        self.hotkey = hotkey
        self.fileSearchEnabled = fileSearchEnabled
        self.fileSearchScope = fileSearchScope
        self.fileSearchIncludeFiles = fileSearchIncludeFiles
        self.fileSearchIncludeFolders = fileSearchIncludeFolders
        self.fileSearchIncludeHidden = fileSearchIncludeHidden
        self.fileSearchCustomPaths = fileSearchCustomPaths
        self.fileSearchExcludedPaths = fileSearchExcludedPaths
        self.suggestionWindowDays = suggestionWindowDays
        self.applicationsPerPage = applicationsPerPage
        self.statusBarEnabled = statusBarEnabled
        self.showKeyboardHints = showKeyboardHints
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.clipboardHistoryEnabled = clipboardHistoryEnabled
        self.clipboardHotkey = clipboardHotkey
        self.clipboardHistoryLimit = clipboardHistoryLimit
        self.clipboardDirectPaste = clipboardDirectPaste
        self.clipboardSaveImages = clipboardSaveImages
        self.currencyConversionEnabled = currencyConversionEnabled
        self.calculatorEnabled = calculatorEnabled
        self.webSearchEnabled = webSearchEnabled
        self.defaultBrowserBundleID = defaultBrowserBundleID
        self.applicationsLauncherEnabled = applicationsLauncherEnabled
        self.applicationsPinchGestureEnabled = applicationsPinchGestureEnabled
        self.applicationsPinchSensitivity = applicationsPinchSensitivity
        self.applicationsHotkey = applicationsHotkey
        self.applicationsGridColumns = applicationsGridColumns
        self.applicationsGridRows = applicationsGridRows
        self.hiddenSections = hiddenSections
    }

    public static let `default` = Preferences()

    /// The only window lengths the Settings UI offers, in days.
    public static let suggestionWindowChoices = [7, 14, 30]

    /// The only page sizes the Settings UI offers.
    public static let applicationsPerPageChoices = [3, 5, 7]

    /// The only history limits the Settings UI offers.
    public static let clipboardHistoryLimitChoices = [100, 250, 500, 1000]

    /// Column counts offered for the Applications grid.
    public static let applicationsGridColumnChoices = [5, 6, 7, 8]

    /// Row counts offered for the Applications grid.
    public static let applicationsGridRowChoices = [4, 5, 6]

    /// Replaces out-of-range stored values with defaults, so a corrupt
    /// `UserDefaults` entry cannot break the layout.
    public func sanitized() -> Preferences {
        var copy = self
        if !Self.suggestionWindowChoices.contains(suggestionWindowDays) {
            copy.suggestionWindowDays = Self.default.suggestionWindowDays
        }
        if !Self.applicationsPerPageChoices.contains(applicationsPerPage) {
            copy.applicationsPerPage = Self.default.applicationsPerPage
        }
        if !Self.clipboardHistoryLimitChoices.contains(clipboardHistoryLimit) {
            copy.clipboardHistoryLimit = Self.default.clipboardHistoryLimit
        }
        if !Self.applicationsGridColumnChoices.contains(applicationsGridColumns) {
            copy.applicationsGridColumns = Self.default.applicationsGridColumns
        }
        if !Self.applicationsGridRowChoices.contains(applicationsGridRows) {
            copy.applicationsGridRows = Self.default.applicationsGridRows
        }
        if !(0.10...0.45).contains(applicationsPinchSensitivity) {
            copy.applicationsPinchSensitivity = Self.default.applicationsPinchSensitivity
        }
        return copy
    }
}

/// Search scope for Spotlight file querying.
public enum FileSearchScope: String, Sendable, CaseIterable {
    case homeDirectory
    case computer
    case custom
}

/// An installed web browser that can be selected as Rill's default browser.
public struct BrowserOption: Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let bundleID: String?

    public init(name: String, bundleID: String?) {
        self.id = bundleID ?? "system-default"
        self.name = name
        self.bundleID = bundleID
    }
}

/// Port for reading and writing user preferences across application launches.
public protocol PreferencesStoring: Sendable {
    func load() async -> Preferences
    func save(_ preferences: Preferences) async
}
