/// Filtering and scope options applied to a file search query.
public struct FileSearchOptions: Sendable, Equatable {
    public var includeFiles: Bool
    public var includeFolders: Bool
    public var includeHidden: Bool
    public var scope: FileSearchScope
    public var customPaths: [String]
    public var excludedPaths: [String]

    public init(
        includeFiles: Bool = true,
        includeFolders: Bool = true,
        includeHidden: Bool = false,
        scope: FileSearchScope = .homeDirectory,
        customPaths: [String] = [],
        excludedPaths: [String] = []
    ) {
        self.includeFiles = includeFiles
        self.includeFolders = includeFolders
        self.includeHidden = includeHidden
        self.scope = scope
        self.customPaths = customPaths
        self.excludedPaths = excludedPaths
    }

    public init(preferences: Preferences) {
        self.init(
            includeFiles: preferences.fileSearchIncludeFiles,
            includeFolders: preferences.fileSearchIncludeFolders,
            includeHidden: preferences.fileSearchIncludeHidden,
            scope: preferences.fileSearchScope,
            customPaths: preferences.fileSearchCustomPaths,
            excludedPaths: preferences.fileSearchExcludedPaths
        )
    }

    public static let `default` = FileSearchOptions()
}

/// Searches files indexed by the operating system metadata service.
public protocol FileSearching: Sendable {
    /// Queries indexed files matching `query`.
    /// - Parameters:
    ///   - query: The user search input.
    ///   - options: Filtering and scope options from user preferences.
    /// - Returns: File search candidates matching the query, capped per section policy.
    func search(query: SearchQuery, options: FileSearchOptions) async -> [SearchResult]
}
