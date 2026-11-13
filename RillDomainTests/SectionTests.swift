import Testing

@testable import RillDomain

@Suite("Section")
struct SectionTests {
    @Test func `sections render in the order users learned`() {
        #expect(
            Section.allCases == [
                .currency, .systemSettings, .favorites, .suggestions, .applications,
                .commands, .files, .fallback,
            ]
        )
    }
}
