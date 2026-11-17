import RillDomain

extension PaletteViewModel {
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
