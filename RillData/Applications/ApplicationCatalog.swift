import Foundation
import RillDomain
import Security

/// Scans the standard application locations once, then serves the cached list.
/// A folder timestamp change (new install or removal) triggers a rescan.
///
/// shortcut: one directory level per root, add nested traversal if users report
/// missing apps inside bundle-style folders.
public actor ApplicationCatalog: ApplicationCataloguing {
    private let roots: [URL]
    private var cache: [SearchResult]?
    private var cachedStamp: [String] = []

    public init() {
        self.init(roots: Self.defaultRoots)
    }

    init(roots: [URL]) {
        self.roots = roots
    }

    public func applications() async -> [SearchResult] {
        let stamp = Self.stamp(of: roots)
        if let cache, stamp == cachedStamp {
            return cache
        }
        let scanned = Self.scan(roots: roots)
        cache = scanned
        cachedStamp = stamp
        return scanned
    }

    private static var defaultRoots: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Utilities", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true),
            // Safari and other sealed system apps live in the app cryptex.
            URL(fileURLWithPath: "/System/Cryptexes/App/System/Applications", isDirectory: true),
            home.appendingPathComponent("Applications", isDirectory: true),
        ]
    }

    /// The `.app` names under each root. A directory mtime is not reliable here
    /// (APFS can leave it unchanged after an install), but listing names is
    /// cheap enough to run before every search.
    ///
    /// shortcut: names only, an app replaced in place under the same name keeps
    /// its cached identity until relaunch.
    private static func stamp(of roots: [URL]) -> [String] {
        var stamp: [String] = []
        for root in roots {
            stamp.append(root.path)
            let names = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
            stamp.append(contentsOf: names.filter { $0.hasSuffix(".app") }.sorted())
        }
        return stamp
    }

    private static func scan(roots: [URL]) -> [SearchResult] {
        let fileManager = FileManager.default
        var candidates: [(url: URL, result: SearchResult)] = []
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
                candidates.append((url, makeResult(for: url)))
            }
        }

        return deduplicated(candidates).sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    /// One row per bundle identifier: a debug copy (signed with
    /// `get-task-allow`) loses to the release copy, then `/Applications` wins
    /// over any other scanned folder.
    private static func deduplicated(
        _ candidates: [(url: URL, result: SearchResult)]
    ) -> [SearchResult] {
        var chosen: [(url: URL, result: SearchResult)] = []
        var indexByID: [SearchResult.ID: Int] = [:]

        for candidate in candidates {
            guard let index = indexByID[candidate.result.id] else {
                indexByID[candidate.result.id] = chosen.count
                chosen.append(candidate)
                continue
            }
            if prefers(candidate.url, over: chosen[index].url) {
                chosen[index] = candidate
            }
        }
        return chosen.map(\.result)
    }

    private static func prefers(_ candidate: URL, over current: URL) -> Bool {
        let candidateDebug = allowsDebugging(candidate)
        let currentDebug = allowsDebugging(current)
        if candidateDebug != currentDebug {
            return !candidateDebug
        }
        return isPreferredLocation(candidate.path, over: current.path)
    }

    static func isPreferredLocation(_ candidate: String, over current: String) -> Bool {
        let candidateSystemWide = candidate.hasPrefix("/Applications/")
        let currentSystemWide = current.hasPrefix("/Applications/")
        return candidateSystemWide && !currentSystemWide
    }

    private static func allowsDebugging(_ url: URL) -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess,
              let code else { return false }

        var information: CFDictionary?
        guard SecCodeCopySigningInformation(
            code,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &information
        ) == errSecSuccess,
            let dictionary = information as? [String: Any],
            let entitlements = dictionary[kSecCodeInfoEntitlementsDict as String]
                as? [String: Any]
        else { return false }

        return entitlements["com.apple.security.get-task-allow"] as? Bool ?? false
    }

    /// Install folder for the palette subtitle; the home folder becomes `~`.
    static func displayPath(
        for url: URL,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> String {
        let directory = url.deletingLastPathComponent().path
        guard directory.hasPrefix(home.path) else { return directory }
        return "~" + directory.dropFirst(home.path.count)
    }

    private static func makeResult(for url: URL) -> SearchResult {
        let bundle = Bundle(url: url)
        let bundleID = bundle?.bundleIdentifier
        let name =
            bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent

        return SearchResult(
            id: .init(source: .application, raw: bundleID ?? url.standardizedFileURL.path),
            title: name,
            subtitle: displayPath(for: url),
            icon: .fileURL(url),
            section: .applications,
            kind: .application,
            primaryAction: bundleID.map { .openApplication(bundleID: $0) } ?? .openFile(url)
        )
    }
}
