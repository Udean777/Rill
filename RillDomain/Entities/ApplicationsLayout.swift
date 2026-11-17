import Foundation

/// A custom shortcut added by the user to the Applications grid (e.g. a
/// folder, script, or web app).
public struct CustomApplicationEntry: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public var title: String
    public var target: String
    public var isWebURL: Bool
    public var symbol: String?

    public init(
        id: UUID = UUID(),
        title: String,
        target: String,
        isWebURL: Bool,
        symbol: String? = nil
    ) {
        self.id = id
        self.title = title
        self.target = target
        self.isWebURL = isWebURL
        self.symbol = symbol
    }
}

/// Reference to a single launchable entry inside the persisted layout or a folder.
public enum ApplicationGridItemReference: Codable, Sendable, Equatable, Hashable {
    case app(id: String)
    case custom(CustomApplicationEntry)

    public var stableID: String {
        switch self {
        case .app(let id): "app:\(id)"
        case .custom(let entry): "custom:\(entry.id.uuidString)"
        }
    }
}

/// A named folder grouping multiple applications in the grid.
public struct ApplicationFolder: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public var name: String
    public var items: [ApplicationGridItemReference]

    public init(
        id: UUID = UUID(),
        name: String,
        items: [ApplicationGridItemReference]
    ) {
        self.id = id
        self.name = name
        self.items = items
    }
}

/// A top-level entry in the persisted Applications grid layout.
public enum ApplicationGridEntry: Codable, Sendable, Equatable, Hashable, Identifiable {
    case app(id: String)
    case custom(CustomApplicationEntry)
    case folder(ApplicationFolder)

    public var id: String {
        switch self {
        case .app(let id): "app:\(id)"
        case .custom(let entry): "custom:\(entry.id.uuidString)"
        case .folder(let folder): "folder:\(folder.id.uuidString)"
        }
    }
}

/// Persisted customisation for the floating Applications grid.
public struct ApplicationsLayout: Codable, Sendable, Equatable {
    public var entries: [ApplicationGridEntry]
    public var hiddenAppIDs: Set<String>

    public init(
        entries: [ApplicationGridEntry] = [],
        hiddenAppIDs: Set<String> = []
    ) {
        self.entries = entries
        self.hiddenAppIDs = hiddenAppIDs
    }

    public static let empty = ApplicationsLayout()
}

/// A resolved, launchable item ready to render in the Applications grid.
public struct ApplicationGridItem: Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let appID: String?
    public let customID: UUID?
    public let title: String
    public let subtitle: String?
    public let icon: IconRef
    public let action: ActionDescriptor

    public init(
        id: String,
        appID: String? = nil,
        customID: UUID? = nil,
        title: String,
        subtitle: String? = nil,
        icon: IconRef,
        action: ActionDescriptor
    ) {
        self.id = id
        self.appID = appID
        self.customID = customID
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.action = action
    }

    /// Converts this grid item to a `SearchResult` so `ExecuteResultUseCase`
    /// can run it and record frecency.
    public var asSearchResult: SearchResult {
        SearchResult(
            id: .init(source: appID != nil ? .application : .customApplication, raw: appID ?? id),
            title: title,
            subtitle: subtitle,
            icon: icon,
            section: .applications,
            kind: .application,
            primaryAction: action
        )
    }
}

/// A resolved top-level node in the Applications grid (either a single item or
/// a folder containing items).
public enum ApplicationsGridNode: Sendable, Equatable, Hashable, Identifiable {
    case item(ApplicationGridItem)
    case folder(id: UUID, name: String, items: [ApplicationGridItem])

    public var id: String {
        switch self {
        case .item(let item): item.id
        case .folder(let id, _, _): "folder:\(id.uuidString)"
        }
    }

    public var title: String {
        switch self {
        case .item(let item): item.title
        case .folder(_, let name, _): name
        }
    }

    /// The launchable items this node exposes: itself, or the folder's contents.
    public var items: [ApplicationGridItem] {
        switch self {
        case .item(let item): [item]
        case .folder(_, _, let items): items
        }
    }
}
