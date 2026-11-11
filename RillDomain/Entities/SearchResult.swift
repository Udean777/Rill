/// A single search hit, independent of how it was produced.
public struct SearchResult: Identifiable, Sendable, Hashable {
    /// Stable identity across searches: the source plus the source's own key.
    public struct ID: Hashable, Sendable {
        public let source: String
        public let raw: String

        public init(source: String, raw: String) {
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
    public let secondaryActions: [ActionDescriptor]
    public let baseScore: Double

    public init(
        id: ID,
        title: String,
        subtitle: String? = nil,
        icon: IconRef,
        section: Section,
        kind: Kind,
        primaryAction: ActionDescriptor,
        secondaryActions: [ActionDescriptor] = [],
        baseScore: Double = 0
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.section = section
        self.kind = kind
        self.primaryAction = primaryAction
        self.secondaryActions = secondaryActions
        self.baseScore = baseScore
    }
}
