import Foundation
import Testing

@testable import RillDomain

@Suite("CurrencyConverter")
struct CurrencyConverterTests {
    @Test func `a currency amount yields a top conversion row`() async throws {
        let useCase = makeUseCase(
            rates: FakeRates(["USD/IDR": 18_000]),
            locale: FixedLocale(currencyCode: "IDR")
        )

        let sections = await useCase(SearchQuery(raw: "$20"))

        let first = try #require(sections.first)
        #expect(first.section == .currency)
        let row = try #require(first.results.first { $0.kind == .currency })
        #expect(row.subtitle == "20 USD → IDR")
        guard case .copyToPasteboard(let text) = row.primaryAction else {
            Issue.record("expected a copy action")
            return
        }
        #expect(!text.isEmpty)
    }

    @Test func `converting to the same currency needs no rate`() async {
        let useCase = makeUseCase(
            rates: FakeRates([:]),
            locale: FixedLocale(currencyCode: "USD")
        )

        let sections = await useCase(SearchQuery(raw: "$20"))

        #expect(sections.flatMap(\.results).contains { $0.kind == .currency })
    }

    @Test func `an explicit target overrides the local currency`() async throws {
        let useCase = makeUseCase(
            rates: FakeRates(["USD/EUR": 0.9]),
            locale: FixedLocale(currencyCode: "IDR")
        )

        let sections = await useCase(SearchQuery(raw: "20 USD to EUR"))

        let row = try #require(sections.flatMap(\.results).first { $0.kind == .currency })
        #expect(row.subtitle == "20 USD → EUR")
    }

    @Test func `a missing rate omits the conversion but keeps the palette`() async {
        let useCase = makeUseCase(
            rates: FailingRates(),
            locale: FixedLocale(currencyCode: "IDR")
        )

        let sections = await useCase(SearchQuery(raw: "$20"))

        #expect(!sections.flatMap(\.results).contains { $0.kind == .currency })
        #expect(sections.contains { $0.section == .fallback })
    }

    @Test func `disabling conversion suppresses the currency row`() async {
        let useCase = makeUseCase(
            rates: FakeRates(["USD/IDR": 18_000]),
            locale: FixedLocale(currencyCode: "IDR"),
            preferences: { Preferences(currencyConversionEnabled: false) }
        )

        let sections = await useCase(SearchQuery(raw: "$20"))

        #expect(!sections.flatMap(\.results).contains { $0.kind == .currency })
    }

    private func makeUseCase(
        rates: CurrencyRateFetching,
        locale: LocaleProviding,
        preferences: (@Sendable () async -> Preferences)? = nil
    ) -> SearchUseCase {
        SearchUseCase(
            commands: EmptyCommands(),
            applications: EmptyApplications(),
            usage: EmptyUsage(),
            clock: FixedClock(now: Date(timeIntervalSince1970: 0)),
            preferences: preferences,
            currencyRates: rates,
            locale: locale
        )
    }
}

private struct EmptyCommands: CommandProviding {
    var commands: [SearchResult] { [] }
}

private struct EmptyApplications: ApplicationCataloguing {
    func applications() async -> [SearchResult] { [] }
}

private struct EmptyUsage: UsageStoring {
    func snapshot() async -> UsageSnapshot { .empty }
    func record(_ id: SearchResult.ID, at date: Date) async {}
    func pinned() async -> [PinnedResult] { [] }
    func setPinned(_ result: SearchResult, isPinned: Bool, at date: Date) async {}
    func clearPins() async {}
    func reset() async {}
}

private struct FakeRates: CurrencyRateFetching {
    let rates: [String: Double]

    init(_ rates: [String: Double]) {
        self.rates = rates
    }

    func rate(base: String, quote: String) async throws -> Double {
        guard let rate = rates["\(base)/\(quote)"] else { throw FakeRateError.missing }
        return rate
    }
}

private struct FailingRates: CurrencyRateFetching {
    func rate(base: String, quote: String) async throws -> Double {
        throw FakeRateError.missing
    }
}

private enum FakeRateError: Error {
    case missing
}

private struct FixedLocale: LocaleProviding {
    let currencyCode: String?
    var regionCode: String? { nil }
    var locale: Locale { Locale(identifier: "en_US") }
}

private struct FixedClock: RillDomain.Clock {
    let now: Date
}
