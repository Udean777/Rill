import Foundation

/// Builds the calculator and web-search rows for a typed query.
struct FallbackResultsProvider: Sendable {
    func results(
        for query: SearchQuery,
        calculatorEnabled: Bool,
        webSearchEnabled: Bool,
        defaultBrowserBundleID: String?
    ) -> [SearchResult] {
        let raw = query.raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return [] }

        var results: [SearchResult] = []
        if calculatorEnabled, let calculation = calculationResult(for: raw) {
            results.append(calculation)
        }
        if webSearchEnabled {
            results.append(contentsOf: webResults(for: raw, browserBundleID: defaultBrowserBundleID))
        }
        return results
    }

    private func calculationResult(for raw: String) -> SearchResult? {
        guard let value = ExpressionEvaluator.evaluate(raw) else { return nil }
        let formatted = ExpressionEvaluator.formatResult(value)
        return SearchResult(
            id: .init(source: .calculation, raw: raw),
            title: formatted,
            subtitle: "= \(raw)",
            icon: .systemSymbol("equal.circle"),
            section: .calculator,
            kind: .calculation,
            primaryAction: .copyToPasteboard(formatted),
            baseScore: 1.0
        )
    }

    private func webResults(for raw: String, browserBundleID: String?) -> [SearchResult] {
        var results: [SearchResult] = []

        if let directURL = WebURLParser.parse(raw) {
            results.append(
                SearchResult(
                    id: .init(source: .webURL, raw: directURL.absoluteString),
                    title: "Open \(directURL.host ?? raw)",
                    subtitle: "Open in Browser",
                    icon: .systemSymbol("safari"),
                    section: .fallback,
                    kind: .web,
                    primaryAction: .openWebURL(
                        directURL,
                        browserBundleID: browserBundleID
                    ),
                    baseScore: 0.95
                )
            )
        }

        if let searchURL = googleSearchURL(for: raw) {
            results.append(
                SearchResult(
                    id: .init(source: .web, raw: raw),
                    title: "Search Google for \"\(raw)\"",
                    subtitle: "Open in browser",
                    icon: .systemSymbol("globe"),
                    section: .fallback,
                    kind: .web,
                    primaryAction: .openWebURL(
                        searchURL,
                        browserBundleID: browserBundleID
                    ),
                    baseScore: 0.1
                )
            )
        }

        return results
    }

    private func googleSearchURL(for query: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.google.com"
        components.path = "/search"
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        return components.url
    }
}
