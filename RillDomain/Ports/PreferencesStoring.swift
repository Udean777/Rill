import Foundation

/// User-configurable application preferences.
public struct Preferences: Sendable, Equatable {
    public var hotkey: Hotkey
    public var fileSearchEnabled: Bool
    public var fileSearchScope: FileSearchScope

    public init(
        hotkey: Hotkey = .default,
        fileSearchEnabled: Bool = true,
        fileSearchScope: FileSearchScope = .homeDirectory
    ) {
        self.hotkey = hotkey
        self.fileSearchEnabled = fileSearchEnabled
        self.fileSearchScope = fileSearchScope
    }

    public static let `default` = Preferences()
}

// shortcut: single home-directory scope, expand when user requests custom folders
/// Search scope for Spotlight file querying.
public enum FileSearchScope: String, Sendable, CaseIterable {
    case homeDirectory
}

/// Port for reading and writing user preferences across application launches.
public protocol PreferencesStoring: Sendable {
    func load() async -> Preferences
    func save(_ preferences: Preferences) async
}
