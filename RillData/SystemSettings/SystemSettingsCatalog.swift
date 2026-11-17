import Foundation
import RillDomain

/// The built-in catalogue of macOS System Settings panes, sub-menus,
/// sub-sub-menus, and searchable setting actions.
///
/// Each entry opens with the `x-apple.systempreferences:` URL scheme. Curated
/// entries cover main panes, sub-menus, and popular actions with clean
/// breadcrumb subtitles; additional entries are discovered from macOS
/// ExtensionKit `.searchTerms` and `AppIntents` bundles on disk.
public actor SystemSettingsCatalog: SystemSettingsProviding {
    private var cache: [SearchResult]?

    public init() {}

    public func settings() async -> [SearchResult] {
        if let cache {
            return cache
        }
        let built = Self.buildCatalog()
        cache = built
        return built
    }

    private static func buildCatalog() -> [SearchResult] {
        var results: [SearchResult] = []
        var seenIDs = Set<String>()
        var seenTitles = Set<String>()
        var paneTitles: [String: String] = [:]
        var paneSymbols: [String: String] = [:]

        func appendUnique(_ item: SearchResult) {
            guard seenIDs.insert(item.id.raw).inserted,
                  seenTitles.insert(item.title.lowercased()).inserted else {
                return
            }
            results.append(item)
        }

        for entry in SystemSettingsCuratedEntries.all {
            if !entry.target.contains("?") && !entry.target.contains(":") {
                paneTitles[entry.target] = entry.title
                paneSymbols[entry.target] = entry.symbol
            }
            if let result = makeResult(
                raw: entry.raw,
                title: entry.title,
                subtitle: entry.subtitle,
                symbol: entry.symbol,
                target: entry.target
            ) {
                appendUnique(result)
            }
        }

        for item in discoverExtensionSearchTerms(paneTitles: paneTitles, paneSymbols: paneSymbols) {
            appendUnique(item)
        }

        for item in discoverExtensionAppIntents() {
            appendUnique(item)
        }

        return results
    }

    private static func makeResult(
        raw: String,
        title: String,
        subtitle: String?,
        symbol: String,
        target: String
    ) -> SearchResult? {
        guard let url = URL(string: "x-apple.systempreferences:\(target)") else {
            return nil
        }
        return SearchResult(
            id: .init(source: .systemSettings, raw: raw),
            title: title,
            subtitle: subtitle,
            icon: .systemSymbol(symbol),
            section: .systemSettings,
            kind: .systemSettings,
            primaryAction: .openURL(url)
        )
    }

    // MARK: - .searchTerms Discovery

    /// Reads all entries inside `.searchTerms` plists across macOS Settings UI
    /// extensions and preference panes.
    private static func discoverExtensionSearchTerms(
        paneTitles: [String: String],
        paneSymbols: [String: String]
    ) -> [SearchResult] {
        let roots = [
            URL(fileURLWithPath: "/System/Library/ExtensionKit/Extensions", isDirectory: true),
            URL(fileURLWithPath: "/System/Library/PreferencePanes", isDirectory: true),
        ]
        let fileManager = FileManager.default
        var discovered: [SearchResult] = []

        for root in roots {
            guard let bundles = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for bundleURL in bundles where bundleURL.pathExtension == "appex" || bundleURL.pathExtension == "prefPane" {
                let infoURL = bundleURL.appendingPathComponent("Contents/Info.plist")
                guard let infoData = try? Data(contentsOf: infoURL),
                      let info = try? PropertyListSerialization.propertyList(
                          from: infoData,
                          format: nil
                      ) as? [String: Any],
                      let paneID = info["CFBundleIdentifier"] as? String,
                      let parentTitle = paneTitles[paneID] else {
                    continue
                }

                let enLproj = bundleURL.appendingPathComponent("Contents/Resources/en.lproj", isDirectory: true)
                guard let resourceFiles = try? fileManager.contentsOfDirectory(
                    at: enLproj,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ) else { continue }

                let symbol = paneSymbols[paneID] ?? "gearshape"
                for fileURL in resourceFiles where fileURL.pathExtension == "searchTerms" {
                    guard let data = try? Data(contentsOf: fileURL),
                          let plist = try? PropertyListSerialization.propertyList(
                              from: data,
                              format: nil
                          ) as? [String: Any] else { continue }

                    for (anchor, rawValue) in plist.sorted(by: { $0.key < $1.key }) {
                        guard !anchor.isEmpty,
                              let entryDict = rawValue as? [String: Any],
                              let localizable = entryDict["localizableStrings"] as? [[String: Any]] else {
                            continue
                        }
                        let encodedAnchor = anchor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? anchor
                        let target = "\(paneID)?\(encodedAnchor)"
                        for (itemIndex, item) in localizable.enumerated() {
                            guard let title = item["title"] as? String, !title.isEmpty else { continue }
                            if let result = makeResult(
                                raw: "ext-\(paneID)-\(anchor)-\(itemIndex)",
                                title: title,
                                subtitle: "System Settings › \(parentTitle)",
                                symbol: symbol,
                                target: target
                            ) {
                                discovered.append(result)
                            }
                        }
                    }
                }
            }
        }
        return discovered
    }

    // MARK: - AppIntents Discovery

    /// Scans System Settings AppIntents bundles (`extract.actionsdata` and
    /// `.loctable` files) so actions such as "Change the wallpaper" and
    /// modern Settings sub-items are indexed alongside `.searchTerms`.
    private static func discoverExtensionAppIntents() -> [SearchResult] {
        let extensionsRoot = URL(
            fileURLWithPath: "/System/Library/ExtensionKit/Extensions",
            isDirectory: true
        )
        var discovered: [SearchResult] = []

        for metadata in SystemSettingsCuratedEntries.intentsBundles {
            let bundleURL = extensionsRoot.appendingPathComponent(metadata.bundleName, isDirectory: true)
            let resourcesURL = bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
            let loctable = loadMergedLoctable(in: resourcesURL)
            let actionsURL = resourcesURL.appendingPathComponent("Metadata.appintents/extract.actionsdata")

            var candidates: [(suffix: String, title: String, anchor: String?)] = []

            if let actionsData = try? Data(contentsOf: actionsURL),
               let json = try? JSONSerialization.jsonObject(with: actionsData) as? [String: Any] {
                candidates.append(contentsOf: extractActionsCandidates(from: json, loctable: loctable))
            }

            for (key, value) in loctable.sorted(by: { $0.key < $1.key }) {
                if key.hasSuffix(".title") || key.hasSuffix("_TITLE") {
                    if isCleanSettingTitle(value) {
                        candidates.append(("loc-key-\(key)", value, nil))
                    }
                } else if !metadata.bundleName.hasPrefix("AccessibilitySettings"),
                          isCleanSettingTitle(value) {
                    candidates.append(("loc-val-\(key)", value, nil))
                }
            }

            for (index, candidate) in candidates.enumerated() {
                let target: String
                if let anchor = candidate.anchor, !anchor.isEmpty {
                    let encoded = anchor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? anchor
                    target = "\(metadata.paneID)?\(encoded)"
                } else {
                    target = metadata.paneID
                }
                if let result = makeResult(
                    raw: "intent-\(metadata.bundleName)-\(candidate.suffix)-\(index)",
                    title: candidate.title,
                    subtitle: "System Settings › \(metadata.parentTitle)",
                    symbol: metadata.symbol,
                    target: target
                ) {
                    discovered.append(result)
                }
            }
        }
        return discovered
    }

    private static func loadMergedLoctable(in resourcesURL: URL) -> [String: String] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: resourcesURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return [:]
        }

        var merged: [String: String] = [:]
        for fileURL in files where fileURL.pathExtension == "loctable"
            && fileURL.lastPathComponent != "InfoPlist.loctable" {
            guard let data = try? Data(contentsOf: fileURL),
                  let plist = try? PropertyListSerialization.propertyList(
                      from: data,
                      format: nil
                  ) as? [String: Any] else { continue }

            let localeDict =
                (plist["en"] as? [String: Any])
                ?? (plist["en_US"] as? [String: Any])
                ?? (plist["en_GB"] as? [String: Any])
                ?? (plist["en_AU"] as? [String: Any])
                ?? (plist["Base"] as? [String: Any])
                ?? [:]

            for (key, rawValue) in localeDict {
                if let text = rawValue as? String, !text.isEmpty {
                    merged[key] = text
                }
            }
        }
        return merged
    }

    private static func extractActionsCandidates(
        from json: [String: Any],
        loctable: [String: String]
    ) -> [(suffix: String, title: String, anchor: String?)] {
        var candidates: [(suffix: String, title: String, anchor: String?)] = []

        if let enums = json["enums"] as? [[String: Any]] {
            for enumDict in enums {
                guard let identifier = enumDict["identifier"] as? String,
                      identifier.contains("DeepLink"),
                      let cases = enumDict["cases"] as? [[String: Any]] else { continue }
                for enumCase in cases {
                    guard let caseID = enumCase["identifier"] as? String,
                          let rep = enumCase["displayRepresentation"] as? [String: Any],
                          let titleObj = rep["title"] as? [String: Any],
                          let rawKey = titleObj["key"] as? String else { continue }
                    let resolved = loctable[rawKey] ?? rawKey
                    guard isCleanSettingTitle(resolved) else { continue }
                    let anchor = caseID == "root" ? nil : caseID
                    candidates.append(("enum-\(identifier)-\(caseID)", resolved, anchor))
                }
            }
        }

        if let entities = json["entities"] as? [String: Any] {
            for (entityName, rawEntity) in entities.sorted(by: { $0.key < $1.key }) {
                guard let entityDict = rawEntity as? [String: Any] else { continue }
                if let displayType = entityDict["displayTypeName"] as? [String: Any],
                   let rawKey = displayType["key"] as? String {
                    let resolved = loctable[rawKey] ?? rawKey
                    if isCleanSettingTitle(resolved) {
                        candidates.append(("ent-\(entityName)", resolved, nil))
                    }
                }
                if let properties = entityDict["properties"] as? [[String: Any]] {
                    for prop in properties {
                        guard let propID = prop["identifier"] as? String,
                              let titleObj = prop["title"] as? [String: Any],
                              let rawKey = titleObj["key"] as? String else { continue }
                        let resolved = loctable[rawKey] ?? rawKey
                        if isCleanSettingTitle(resolved) {
                            candidates.append(("prop-\(entityName)-\(propID)", resolved, nil))
                        }
                    }
                }
            }
        }

        return candidates
    }

    private static func isCleanSettingTitle(_ value: String) -> Bool {
        guard value.count >= 3, value.count <= 75 else { return false }
        guard let first = value.first, first.isUppercase else { return false }
        guard !ignoredLoctableTitles.contains(value) else { return false }
        guard !value.hasSuffix(".") else { return false }

        let disallowedSubstrings = [
            " value of ", " to update", "Update ", "%", "${", "\n",
            "Entity", "DeepLink", "Intents", "?", "!", "…",
        ]
        return !disallowedSubstrings.contains(where: { value.contains($0) })
    }

    private static let ignoredLoctableTitles: Set<String> = [
        "Disabled", "Enabled", "On", "Off", "Always", "Never", "Settings",
        "General", "Target", "None", "Other", "Cancel", "Delete", "OK",
        "Continue", "Done", "Save", "Close", "Edit", "Add", "Remove",
        "Default", "Automatic", "Custom", "All", "Decrease", "Increase",
        "Faster", "Slower", "Lower", "Higher", "Left", "Right", "Top",
        "Bottom", "Firm", "Light", "Medium", "Dark", "Auto", "Reset",
        "Start", "Stop", "Open", "Show", "Hide", "Select", "Choose",
    ]
}
