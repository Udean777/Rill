import Foundation

@testable import RillDomain

extension SearchResult {
    static func fixture(
        title: String,
        subtitle: String? = nil,
        section: Section = .commands,
        kind: Kind = .command,
        source: SearchResult.Source = .application,
        action: ActionDescriptor = .openFile(URL(fileURLWithPath: "/"))
    ) -> SearchResult {
        SearchResult(
            id: .init(source: source, raw: title),
            title: title,
            subtitle: subtitle,
            icon: .systemSymbol("circle"),
            section: section,
            kind: kind,
            primaryAction: action
        )
    }
}
