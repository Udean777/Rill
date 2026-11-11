import Foundation
import RillDomain

/// Scans the standard application locations once, then serves the cached list.
///
/// shortcut: one directory level per root, add nested traversal if users report
/// missing apps inside bundle-style folders.
public actor ApplicationCatalog: ApplicationCataloguing {
    private var cache: [SearchResult]?

    public init() {}

    public func applications() async -> [SearchResult] {
        if let cache {
            return cache
        }
        let scanned = Self.scan()
        cache = scanned
        return scanned
    }

    private static func scan() -> [SearchResult] {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Utilities", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true),
            // Safari and other sealed system apps live in the app cryptex.
            URL(fileURLWithPath: "/System/Cryptexes/App/System/Applications", isDirectory: true),
            home.appendingPathComponent("Applications", isDirectory: true),
        ]

        var results: [SearchResult] = []
        var seenPaths = Set<String>()

        for root in roots {
            guard
                let entries = try? fileManager.contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
            else { continue }

            for url in entries where url.pathExtension == "app" {
                let path = url.standardizedFileURL.path
                guard seenPaths.insert(path).inserted else { continue }
                results.append(makeResult(for: url))
            }
        }

        return results.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private static func makeResult(for url: URL) -> SearchResult {
        let bundle = Bundle(url: url)
        let bundleID = bundle?.bundleIdentifier
        let name =
            bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent

        return SearchResult(
            id: .init(source: "application", raw: bundleID ?? url.standardizedFileURL.path),
            title: name,
            subtitle: url.deletingLastPathComponent().path,
            icon: .fileURL(url),
            section: .applications,
            kind: .application,
            primaryAction: bundleID.map { .openApplication(bundleID: $0) } ?? .openFile(url)
        )
    }
}
