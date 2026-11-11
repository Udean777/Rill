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
    private var notificationObservers: [Any] = []

    public init() {}

    public nonisolated func search(query: SearchQuery) async -> [SearchResult] {
        await withTaskCancellationHandler {
            await self.performSearch(query: query)
        } onCancel: {
            Task { @MainActor in
                self.cancelCurrentQuery()
            }
        }
    }

    private func performSearch(query: SearchQuery) async -> [SearchResult] {
        cancelCurrentQuery()

        guard case let .text(text) = query.mode, text.count >= Self.minimumQueryLength else {
            return []
        }

        return await withCheckedContinuation { continuation in
            activeContinuation = continuation

            let metadataQuery = NSMetadataQuery()
            metadataQuery.searchScopes = [NSMetadataQueryUserHomeScope]

            let escaped = text.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "*", with: "\\*")
                .replacingOccurrences(of: "?", with: "\\?")

            let predicateString = """
            (kMDItemDisplayName == "*\(escaped)*"cd || kMDItemFSName == "*\(escaped)*"cd) && \
            kMDItemContentType != "com.apple.application-bundle"
            """
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
                    if query.resultCount >= Self.maxResults {
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
        let count = min(metadataQuery.resultCount, Self.maxResults)

        for index in 0..<count {
            guard let item = metadataQuery.result(at: index) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String
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
}
