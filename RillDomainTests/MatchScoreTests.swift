import Testing

@testable import RillDomain

@Suite("MatchScore")
struct MatchScoreTests {
    @Test(
        arguments: [
            ("Safari", "Safari", 1.0),
            ("Safari", "safari", 1.0),
            ("Safari", "saf", 0.9),
            ("Open Safari", "saf", 0.8),
            ("Unsafely", "saf", 0.6),
        ]
    )
    func `match quality lands in its band`(
        title: String,
        query: String,
        expected: Double
    ) {
        #expect(MatchScore.score(title: title, query: SearchQuery(raw: query)) == expected)
    }

    @Test func `diacritics and case are ignored`() {
        #expect(MatchScore.score(title: "Café", query: SearchQuery(raw: "cafe")) == 1.0)
    }

    @Test func `subsequence matches score between floor and ceiling`() {
        let score = MatchScore.score(title: "Safari", query: SearchQuery(raw: "sfr"))
        #expect(score >= 0.3 && score <= 0.5)
    }

    @Test func `unmatched titles score zero`() {
        #expect(MatchScore.score(title: "Safari", query: SearchQuery(raw: "zzz")) == 0)
    }

    @Test func `an empty query matches everything`() {
        #expect(MatchScore.score(title: "Safari", query: SearchQuery(raw: "  ")) == 1.0)
    }
}
