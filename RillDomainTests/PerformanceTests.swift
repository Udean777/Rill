import Foundation
import RillDomain
import Testing

@Suite("Performance")
struct PerformanceTests {
    /// Latency budget per design.md §4.6 (≤ 50 ms measured on bare-metal M-series Mac).
    /// CI runners execute in virtualized environments with shared CPU scheduling,
    /// so we allow headroom for VM jitter.
    private var latencyBudget: Duration {
        ProcessInfo.processInfo.environment["CI"] != nil ? .seconds(2) : .milliseconds(50)
    }

    private var microsecondBudget: Duration {
        ProcessInfo.processInfo.environment["CI"] != nil ? .milliseconds(50) : .milliseconds(10)
    }

    @Test func `ranking 4000 items completes well under 50ms budget`() {
        let clock = ContinuousClock()

        // Generate 4,000 candidate items (applications & commands) per design.md §4.6
        var candidates: [SearchResult] = []
        candidates.reserveCapacity(4000)

        for i in 0..<3500 {
            candidates.append(
                SearchResult(
                    id: .init(source: "application", raw: "app-\(i)"),
                    title: "Application \(i)",
                    subtitle: "/Applications/App\(i).app",
                    icon: .systemSymbol("app"),
                    section: .applications,
                    kind: .application,
                    primaryAction: .openApplication(bundleID: "com.test.app\(i)"),
                    baseScore: Double(i % 10) / 10.0
                )
            )
        }

        for i in 0..<500 {
            candidates.append(
                SearchResult(
                    id: .init(source: "command", raw: "cmd-\(i)"),
                    title: "Command \(i)",
                    subtitle: "Built-in command",
                    icon: .systemSymbol("terminal"),
                    section: .commands,
                    kind: .command,
                    primaryAction: .openFile(URL(fileURLWithPath: "/")),
                    baseScore: 1.0
                )
            )
        }

        let query = SearchQuery(raw: "app")
        let usage = UsageSnapshot.empty
        let now = Date()

        let elapsed = clock.measure {
            _ = Ranking.rank(candidates, query: query, usage: usage, now: now)
        }

        #expect(elapsed < latencyBudget)
    }

    @Test func `ranking 4000 unscored candidates stays under budget`() {
        let clock = ContinuousClock()

        // Real app and command results carry no baseScore, so this exercises
        // the folding-heavy MatchScore path the previous test skips.
        let candidates = (0..<4000).map { index in
            SearchResult(
                id: .init(source: "application", raw: "app-\(index)"),
                title: "Application \(index)",
                icon: .systemSymbol("app"),
                section: .applications,
                kind: .application,
                primaryAction: .openApplication(bundleID: "com.test.app\(index)")
            )
        }

        let elapsed = clock.measure {
            _ = Ranking.rank(
                candidates,
                query: SearchQuery(raw: "app"),
                usage: .empty,
                now: Date()
            )
        }

        #expect(elapsed < latencyBudget)
    }

    @Test func `expression evaluation finishes in microseconds`() {
        let clock = ContinuousClock()
        let expression = "((12 * 45) + 340) / 2"

        let elapsed = clock.measure {
            for _ in 0..<100 {
                _ = ExpressionEvaluator.evaluate(expression)
            }
        }

        #expect(elapsed < microsecondBudget)
    }
}
