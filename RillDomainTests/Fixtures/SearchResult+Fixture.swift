import Foundation

@testable import RillDomain

extension SearchResult {
    static func fixture(
        title: String,
        section: Section = .commands,
        kind: Kind = .command,
        source: String = "fixture",
        action: ActionDescriptor = .openFile(URL(fileURLWithPath: "/"))
    ) -> SearchResult {
        SearchResult(
            id: .init(source: source, raw: title),
            title: title,
            icon: .systemSymbol("circle"),
            section: section,
            kind: kind,
            primaryAction: action
        )
    }
}
