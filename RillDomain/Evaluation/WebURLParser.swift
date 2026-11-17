import Foundation

/// Parses a user query into a web `URL` when it represents a direct website
/// address, domain, or localhost endpoint.
public enum WebURLParser {
    /// Returns a normalized `URL` when `raw` looks like a web URL or domain,
    /// or `nil` for ordinary search terms, file paths, or math expressions.
    public static func parse(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !trimmed.contains(where: \.isWhitespace) else { return nil }
        guard !trimmed.hasPrefix("/"), !trimmed.hasPrefix("~") else { return nil }

        let lower = trimmed.lowercased()
        if lower.hasPrefix("https://") || lower.hasPrefix("http://") {
            guard let components = URLComponents(string: trimmed),
                  let host = components.host,
                  !host.isEmpty else {
                return nil
            }
            return components.url
        }

        // Ignore expressions or strings with schemes other than http/https.
        if trimmed.contains("://") {
            return nil
        }

        let hostPart = trimmed.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? trimmed
        let hostWithoutQuery = hostPart.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? hostPart

        if isLocalHost(hostWithoutQuery) {
            return URL(string: "http://\(trimmed)")
        }

        guard isLikelyDomain(hostWithoutQuery) else { return nil }
        return URL(string: "https://\(trimmed)")
    }

    private static func isLocalHost(_ hostPort: String) -> Bool {
        let parts = hostPort.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let host = String(parts[0]).lowercased()
        if parts.count == 2 {
            guard let port = Int(parts[1]), (1...65535).contains(port) else {
                return false
            }
        }
        return host == "localhost" || isIPv4(host)
    }

    private static func isIPv4(_ host: String) -> Bool {
        let octets = host.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else { return false }
        return octets.allSatisfy { part in
            guard let value = Int(part), (0...255).contains(value) else { return false }
            return String(value) == part
        }
    }

    private static func isLikelyDomain(_ hostPort: String) -> Bool {
        let parts = hostPort.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let host = String(parts[0])
        if parts.count == 2 {
            guard let port = Int(parts[1]), (1...65535).contains(port) else {
                return false
            }
        }

        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }
        guard let tld = labels.last, tld.count >= 2, tld.count <= 24 else { return false }
        guard tld.allSatisfy({ $0.isASCII && $0.isLetter }) else { return false }

        return labels.dropLast().allSatisfy { label in
            guard !label.isEmpty, label.count <= 63 else { return false }
            guard !label.hasPrefix("-"), !label.hasSuffix("-") else { return false }
            return label.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
        }
    }
}
