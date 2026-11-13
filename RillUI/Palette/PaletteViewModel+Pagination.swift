import RillDomain

extension PaletteViewModel {
    /// The commands section, rendered as a fixed chip row in the root layout.
    public var commandSection: RankedSection? {
        sections.first { $0.section == .commands }
    }

    public var applicationPageCount: Int {
        SectionPager.pageCount(
            itemCount: applicationResults.count,
            pageSize: applicationsPageSize
        )
    }

    public var hasMultipleApplicationPages: Bool {
        applicationPageCount > 1
    }

    var applicationResults: [SearchResult] {
        sections.first { $0.section == .applications }?.results ?? []
    }

    func firstApplicationID(onPage page: Int) -> SearchResult.ID? {
        SectionPager.slice(
            applicationResults,
            page: page,
            pageSize: applicationsPageSize
        ).first?.id
    }
}
