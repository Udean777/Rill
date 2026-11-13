import Foundation
import RillDomain

/// Fetches mid-market rates from Frankfurter and caches them in memory.
///
/// The app's first network adapter (architecture.md ADR-009). Frankfurter is
/// free, keyless and anonymous; requests carry only the currency pair.
public actor FrankfurterRateFetcher: CurrencyRateFetching {
    private struct CachedRate {
        let rate: Double
        let fetchedAt: Date
    }

    private struct Response: Decodable {
        let rate: Double
    }

    private let session: URLSession
    private let clock: Clock
    private let ttl: TimeInterval
    private var cache: [String: CachedRate] = [:]

    /// - Parameters:
    ///   - session: Injected so tests can stub the transport.
    ///   - clock: Injected so cache expiry is deterministic under test.
    ///   - ttl: How long a fetched rate stays fresh (Frankfurter updates daily).
    public init(
        session: URLSession = .shared,
        clock: Clock,
        ttl: TimeInterval = 86_400
    ) {
        self.session = session
        self.clock = clock
        self.ttl = ttl
    }

    public func rate(base: String, quote: String) async throws -> Double {
        let source = base.uppercased()
        let target = quote.uppercased()
        guard source != target else { return 1 }

        let key = "\(source)/\(target)"
        if let cached = cache[key], clock.now.timeIntervalSince(cached.fetchedAt) < ttl {
            return cached.rate
        }

        let fetched = try await fetch(base: source, quote: target)
        cache[key] = CachedRate(rate: fetched, fetchedAt: clock.now)
        return fetched
    }

    private func fetch(base: String, quote: String) async throws -> Double {
        guard let url = URL(string: "https://api.frankfurter.dev/v2/rate/\(base)/\(quote)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(Response.self, from: data).rate
    }
}
