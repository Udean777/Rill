/// One ordered group of results. Ranking never crosses a section boundary.
public struct RankedSection: Identifiable, Sendable, Hashable {
    public var id: Section { section }
    public let section: Section
    public let results: [SearchResult]

    public init(section: Section, results: [SearchResult]) {
        self.section = section
        self.results = results
    }
}
