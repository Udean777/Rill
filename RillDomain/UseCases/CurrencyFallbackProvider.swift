import Foundation

/// Converts a currency amount in the query to the user's local currency.
///
/// A missing rate or a non-currency query yields `nil`; the palette degrades
/// rather than blocking on the network.
struct CurrencyFallbackProvider: Sendable {
    private let rates: CurrencyRateFetching
    private let locale: LocaleProviding

    init(rates: CurrencyRateFetching, locale: LocaleProviding) {
        self.rates = rates
        self.locale = locale
    }

    func result(for query: SearchQuery, enabled: Bool) async -> SearchResult? {
        guard enabled else { return nil }
        let raw = query.raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = CurrencyParser.parse(raw) else { return nil }

        let target = (parsed.targetCode ?? locale.currencyCode)?.uppercased()
        guard let target, !target.isEmpty else { return nil }

        let source = parsed.code
        let rate: Double
        if source == target {
            rate = 1
        } else {
            // Offline is expected, not exceptional: skip the row, keep the palette.
            guard let fetched = try? await rates.rate(base: source, quote: target) else {
                return nil
            }
            rate = fetched
        }

        let converted = parsed.amount * Decimal(rate)
        let formatted = CurrencyFormatter.string(converted, code: target, locale: locale.locale)
        return SearchResult(
            id: .init(source: .currency, raw: raw),
            title: formatted,
            subtitle: "\(parsed.amount) \(source) → \(target)",
            icon: .systemSymbol("dollarsign.circle"),
            section: .currency,
            kind: .currency,
            primaryAction: .copyToPasteboard(formatted),
            baseScore: 1.0
        )
    }
}
