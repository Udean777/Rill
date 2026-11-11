import Foundation

@testable import RillDomain

extension SearchResult {
    static func fixture(
        title: String,
        section: Section = .commands,
        kind: Kind = .command,
        action: ActionDescriptor = .openFile(URL(fileURLWithPath: "/"))
    ) -> SearchResult {
        SearchResult(
            id: .init(source: "fixture", raw: title),
            title: title,
            icon: .systemSymbol("circle"),
            section: section,
            kind: kind,
            primaryAction: action
        )
    }
}
