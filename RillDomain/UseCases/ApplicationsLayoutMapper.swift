import Foundation

/// Converts between persisted layout entries and the resolved grid items the
/// launcher renders. The only place that knows how a custom shortcut maps both
/// ways.
public enum ApplicationsLayoutMapper {
    /// The resolved grid item for a saved custom shortcut.
    public static func item(
        for entry: CustomApplicationEntry,
        defaultBrowserBundleID: String?
    ) -> ApplicationGridItem {
        if entry.isWebURL, let url = URL(string: entry.target) {
            return ApplicationGridItem(
                id: "custom:\(entry.id.uuidString)",
                customID: entry.id,
                title: entry.title,
                subtitle: url.host ?? entry.target,
                icon: .systemSymbol(entry.symbol ?? "globe"),
                action: .openWebURL(url, browserBundleID: defaultBrowserBundleID)
            )
        }
        let fileURL = URL(fileURLWithPath: entry.target)
        return ApplicationGridItem(
            id: "custom:\(entry.id.uuidString)",
            customID: entry.id,
            title: entry.title,
            subtitle: fileURL.deletingLastPathComponent().path,
            icon: .fileURL(fileURL),
            action: .openFile(fileURL)
        )
    }

    /// The persisted top-level entry for a resolved grid node.
    public static func entry(for node: ApplicationsGridNode) -> ApplicationGridEntry {
        switch node {
        case .item(let item):
            if let appID = item.appID {
                return .app(id: appID)
            }
            if let customEntry = customEntry(for: item) {
                return .custom(customEntry)
            }
            return .app(id: item.id)

        case .folder(let id, let name, let items):
            return .folder(
                ApplicationFolder(
                    id: id,
                    name: name,
                    items: items.compactMap { reference(for: $0) }
                )
            )
        }
    }

    /// The persisted reference for a resolved item, or `nil` when the item has
    /// neither an application nor a custom-shortcut identity.
    public static func reference(
        for item: ApplicationGridItem
    ) -> ApplicationGridItemReference? {
        if let appID = item.appID {
            return .app(id: appID)
        }
        if let customEntry = customEntry(for: item) {
            return .custom(customEntry)
        }
        return nil
    }

    private static func customEntry(for item: ApplicationGridItem) -> CustomApplicationEntry? {
        guard let customID = item.customID else { return nil }
        let isWebURL = if case .openWebURL = item.action { true } else { false }
        let target: String = switch item.action {
        case .openWebURL(let url, _): url.absoluteString
        case .openFile(let url): url.path
        default: ""
        }
        return CustomApplicationEntry(
            id: customID,
            title: item.title,
            target: target,
            isWebURL: isWebURL,
            symbol: isWebURL ? "globe" : nil
        )
    }
}
