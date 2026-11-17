/// A single search hit, independent of how it was produced.
public struct SearchResult: Identifiable, Sendable, Hashable {
    /// Which provider produced a result. Raw values are persisted inside usage
    /// keys, so they must not change.
    public enum Source: Hashable, Sendable, Comparable {
        case application
        case customApplication
        case file
        case command
        case calculation
        case web
        case webURL
        case currency
        case systemSettings
        /// A source this build does not know, kept so old usage still loads.
        case other(String)

        public var rawValue: String {
            switch self {
            case .application: "application"
            case .customApplication: "custom-application"
            case .file: "file"
            case .command: "command"
            case .calculation: "calculation"
            case .web: "web"
            case .webURL: "web-url"
            case .currency: "currency"
            case .systemSettings: "system-settings"
            case .other(let raw): raw
            }
        }

        public init(rawValue: String) {
            switch rawValue {
            case "application": self = .application
            case "custom-application": self = .customApplication
            case "file": self = .file
            case "command": self = .command
            case "calculation": self = .calculation
            case "web": self = .web
            case "web-url": self = .webURL
            case "currency": self = .currency
            case "system-settings": self = .systemSettings
            default: self = .other(rawValue)
            }
        }

        public static func < (lhs: Source, rhs: Source) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// Stable identity across searches: the source plus the source's own key.
    public struct ID: Hashable, Sendable {
        public let source: Source
        public let raw: String

        public init(source: Source, raw: String) {
            self.source = source
            self.raw = raw
        }
    }

    public let id: ID
    public let title: String
    public let subtitle: String?
    public let icon: IconRef
    public let section: Section
    public let kind: Kind
    public let primaryAction: ActionDescriptor
    public let baseScore: Double

    public init(
        id: ID,
        title: String,
        subtitle: String? = nil,
        icon: IconRef,
        section: Section,
        kind: Kind,
        primaryAction: ActionDescriptor,
        baseScore: Double = 0
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.section = section
        self.kind = kind
        self.primaryAction = primaryAction
        self.baseScore = baseScore
    }

    /// The same result, regrouped into another section.
    public func withSection(_ section: Section) -> SearchResult {
        SearchResult(
            id: id,
            title: title,
            subtitle: subtitle,
            icon: icon,
            section: section,
            kind: kind,
            primaryAction: primaryAction,
            baseScore: baseScore
        )
    }
}
