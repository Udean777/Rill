import Foundation
import Testing

@testable import RillDomain

@Suite("Frecency")
struct FrecencyTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func `unused results score zero`() {
        #expect(Frecency.score(nil, now: now) == 0)
        #expect(Frecency.score(.init(count: 0, lastUsed: now), now: now) == 0)
    }

    @Test func `recent use outranks old use`() {
        let recent = UsageSnapshot.Entry(count: 5, lastUsed: now)
        let old = UsageSnapshot.Entry(count: 5, lastUsed: now.addingTimeInterval(-90 * 86_400))

        #expect(Frecency.score(recent, now: now) > Frecency.score(old, now: now))
    }

    @Test func `more uses outrank fewer at the same time`() {
        let many = UsageSnapshot.Entry(count: 10, lastUsed: now)
        let few = UsageSnapshot.Entry(count: 1, lastUsed: now)

        #expect(Frecency.score(many, now: now) > Frecency.score(few, now: now))
    }

    @Test func `score never exceeds one`() {
        let entry = UsageSnapshot.Entry(count: Int.max, lastUsed: now)
        let score = Frecency.score(entry, now: now)

        #expect(score >= 0 && score <= 1)
    }

    @Test func `a future timestamp is treated as fresh`() {
        let future = UsageSnapshot.Entry(count: 1, lastUsed: now.addingTimeInterval(86_400))
        let current = UsageSnapshot.Entry(count: 1, lastUsed: now)

        #expect(Frecency.score(future, now: now) == Frecency.score(current, now: now))
    }
}
