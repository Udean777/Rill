import Foundation
import os
import RillDomain

/// Searches files via Spotlight's `NSMetadataQuery` on the user home directory.
///
/// `NSMetadataQuery` requires an active run loop and posts notifications on the
/// thread where it was started, so this adapter is `@MainActor`-isolated.
@MainActor
public final class SpotlightFileSearch: FileSearching {
    private static let maxResults = 20
    private static let minimumQueryLength = 2

    private let log = Logger(subsystem: "com.ssajudn.Rill", category: "files")
    private var currentQuery: NSMetadataQuery?
    private var activeContinuation: CheckedContinuation<[SearchResult], Never>?
    private var activeOptions: FileSearchOptions = .default
    private var notificationObservers: [Any] = []

    public init() {}

    public nonisolated func search(query: SearchQuery, options: FileSearchOptions) async -> [SearchResult] {
        await withTaskCancellationHandler {
            await self.performSearch(query: query, options: options)
        } onCancel: {
            Task { @MainActor in
                self.cancelCurrentQuery()
            }
        }
    }

    private func performSearch(query: SearchQuery, options: FileSearchOptions) async -> [SearchResult] {
        cancelCurrentQuery()

        guard options.includeFiles || options.includeFolders else {
            return []
        }

        guard case let .text(text) = query.mode, text.count >= Self.minimumQueryLength else {
            return []
        }

        activeOptions = options

        return await withCheckedContinuation { continuation in
            activeContinuation = continuation

            let metadataQuery = NSMetadataQuery()
            metadataQuery.searchScopes = Self.searchScopes(for: options)

            let predicateString = Self.predicateString(for: text, options: options)
            metadataQuery.predicate = NSPredicate(fromMetadataQueryString: predicateString)

            metadataQuery.sortDescriptors = [
                NSSortDescriptor(key: NSMetadataItemFSContentChangeDateKey, ascending: false)
            ]

            // NotificationCenter closures are @Sendable in Swift 6; hop to MainActor
            // explicitly so we can safely call @MainActor-isolated methods (see
            // architecture.md §5 on run-loop-affine APIs).
            let finishObserver = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: metadataQuery,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleQueryGathered()
                }
            }

            let updateObserver = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidUpdate,
                object: metadataQuery,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, let query = self.currentQuery else { return }
                    let threshold = self.activeOptions.excludedPaths.isEmpty && self.activeOptions.includeHidden
                        ? Self.maxResults
                        : Self.maxResults * 3
                    if query.resultCount >= threshold {
                        self.handleQueryGathered()
                    }
                }
            }

            notificationObservers = [finishObserver, updateObserver]
            currentQuery = metadataQuery

            if !metadataQuery.start() {
                log.error("failed to start metadata query")
                tearDownObservers()
                activeContinuation = nil
                currentQuery = nil
                continuation.resume(returning: [])
            }
        }
    }

    private func handleQueryGathered() {
        guard let metadataQuery = currentQuery else { return }
        metadataQuery.disableUpdates()

        var results: [SearchResult] = []
        let total = metadataQuery.resultCount
        let options = activeOptions

        for index in 0..<total {
            guard results.count < Self.maxResults else { break }
            guard let item = metadataQuery.result(at: index) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  !Self.shouldExclude(path: path, options: options)
            else { continue }

            let url = URL(fileURLWithPath: path)
            let displayName = (item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String)
                ?? url.lastPathComponent

            let subtitle = url.deletingLastPathComponent().path
                .replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")

            results.append(
                SearchResult(
                    id: .init(source: "file", raw: path),
                    title: displayName,
                    subtitle: subtitle,
                    icon: .fileURL(url),
                    section: .files,
                    kind: .file,
                    primaryAction: .openFile(url)
                )
            )
        }

        metadataQuery.stop()
        tearDownObservers()
        let continuation = activeContinuation
        activeContinuation = nil
        currentQuery = nil
        continuation?.resume(returning: results)
    }

    private func cancelCurrentQuery() {
        if let query = currentQuery {
            query.stop()
            currentQuery = nil
        }
        tearDownObservers()
        if let continuation = activeContinuation {
            activeContinuation = nil
            continuation.resume(returning: [])
        }
    }

    private func tearDownObservers() {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
    }

    /// Builds the Spotlight `NSMetadataQuery` predicate string for `text` and `options`.
    public nonisolated static func predicateString(for text: String, options: FileSearchOptions) -> String {
        let escaped = text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "*", with: "\\*")
            .replacingOccurrences(of: "?", with: "\\?")

        var clauses = [
            "(kMDItemDisplayName == \"*\(escaped)*\"cd || kMDItemFSName == \"*\(escaped)*\"cd)",
            "kMDItemContentType != \"com.apple.application-bundle\"",
        ]

        if options.includeFiles && !options.includeFolders {
            clauses.append("kMDItemContentType != \"public.folder\"")
        } else if !options.includeFiles && options.includeFolders {
            clauses.append("kMDItemContentType == \"public.folder\"")
        }

        if !options.includeHidden {
            clauses.append("kMDItemFSInvisible != 1")
        }

        return clauses.joined(separator: " && ")
    }

    /// Resolves `NSMetadataQuery.searchScopes` from `options`.
    public nonisolated static func searchScopes(for options: FileSearchOptions) -> [Any] {
        switch options.scope {
        case .homeDirectory:
            [NSMetadataQueryUserHomeScope]
        case .computer:
            [NSMetadataQueryLocalComputerScope]
        case .custom:
            options.customPaths.isEmpty
                ? [NSMetadataQueryUserHomeScope]
                : options.customPaths.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath, isDirectory: true) }
        }
    }

    /// Returns `true` when `path` should be hidden due to dot-segments or excluded directories.
    public nonisolated static func shouldExclude(path: String, options: FileSearchOptions) -> Bool {
        if !options.includeHidden {
            let components = URL(fileURLWithPath: path).pathComponents
            if components.contains(where: { $0.hasPrefix(".") && $0 != "." && $0 != ".." }) {
                return true
            }
        }

        for rawExcluded in options.excludedPaths {
            let expanded = (rawExcluded as NSString).expandingTildeInPath
            let normalized = expanded.hasSuffix("/") && expanded.count > 1
                ? String(expanded.dropLast())
                : expanded
            guard !normalized.isEmpty else { continue }
            if path == normalized || path.hasPrefix(normalized + "/") {
                return true
            }
        }

        return false
    }
}
