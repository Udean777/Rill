import Testing

@testable import RillDomain

@Suite("SearchQuery")
struct SearchQueryTests {
    @Test func `empty and whitespace queries are root`() {
        #expect(SearchQuery(raw: "").mode == .root)
        #expect(SearchQuery(raw: "   ").mode == .root)
        #expect(SearchQuery(raw: "safari").mode == .text("safari"))
    }

    @Test func `matching ignores case`() {
        #expect(SearchQuery(raw: "SAF").matches(title: "Safari"))
    }

    @Test func `matching ignores diacritics`() {
        #expect(SearchQuery(raw: "cafe").matches(title: "Café"))
    }

    @Test func `non-matching text is rejected`() {
        #expect(!SearchQuery(raw: "zzz").matches(title: "Safari"))
    }

    @Test func `an empty query matches everything`() {
        #expect(SearchQuery(raw: "").matches(title: "Safari"))
    }
}
