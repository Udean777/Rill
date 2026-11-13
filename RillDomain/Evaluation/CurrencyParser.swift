import Foundation

/// A parsed currency amount, e.g. `$20` → 20 USD, or `20 USD to IDR`.
public struct CurrencyAmount: Sendable, Hashable {
    /// The numeric amount. `Decimal`, not `Double`, so money never drifts.
    public let amount: Decimal

    /// ISO 4217 code of the amount, uppercased.
    public let code: String

    /// Explicit target currency when the query named one (`20 USD to IDR`).
    public let targetCode: String?

    public init(amount: Decimal, code: String, targetCode: String? = nil) {
        self.amount = amount
        self.code = code
        self.targetCode = targetCode
    }
}

/// Parses a currency amount out of the palette query. Pure and deterministic:
/// no clock, no locale, no I/O. Formatting lives in `CurrencyFormatter`.
public enum CurrencyParser {
    /// Parses `$20`, `€50`, `Rp 20000`, `20 USD`, `1000 JPY`, `20 USD to IDR`.
    ///
    /// - Returns: The amount and source currency, or `nil` when the text is not
    ///   a recognisable currency amount.
    public static func parse(_ raw: String) -> CurrencyAmount? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var working = trimmed
        var targetCode: String?

        // Explicit target: "20 USD to IDR", "$20 in IDR".
        if let targetRange = working.range(
            of: #"\s+(?:to|in)\s+"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            let targetText = String(working[targetRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let code = knownCode(targetText) else { return nil }
            targetCode = code
            working = String(working[..<targetRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let (amount, code) = amountAndCode(from: working) else { return nil }
        return CurrencyAmount(amount: amount, code: code, targetCode: targetCode)
    }

    private static func amountAndCode(from text: String) -> (Decimal, String)? {
        guard !text.isEmpty else { return nil }

        // Sort longest symbol first so "US$"/"R$" win over "$"; fold case for
        // alphabetic symbols ("rp 20000") while keeping glyph matching exact.
        let folded = text.lowercased()
        for symbol in symbols.sorted(by: { $0.key.count > $1.key.count }) {
            guard folded.hasPrefix(symbol.key.lowercased()) else { continue }
            let remainder = String(text.dropFirst(symbol.key.count))
            if let amount = parseNumber(remainder) {
                return (amount, symbol.value)
            }
        }

        // Code forms need exactly a number and a code token: "20 USD", "IDR 200000".
        let tokens = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard tokens.count == 2 else { return nil }

        if let code = knownCode(tokens[0]), let amount = parseNumber(tokens[1]) {
            return (amount, code)
        }
        if let amount = parseNumber(tokens[0]), let code = knownCode(tokens[1]) {
            return (amount, code)
        }
        return nil
    }

    private static func knownCode(_ text: String) -> String? {
        let upper = text.uppercased()
        return knownCodes.contains(upper) ? upper : nil
    }

    private static func parseNumber(_ text: String) -> Decimal? {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard !cleaned.isEmpty else { return nil }
        guard cleaned.range(of: #"^[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil else {
            return nil
        }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Symbols that map unambiguously (or by documented convention) to a code.
    /// `$` defaults to USD; the local dollar variant must be typed explicitly.
    private static let symbols: [String: String] = [
        "US$": "USD", "C$": "CAD", "A$": "AUD", "S$": "SGD", "HK$": "HKD",
        "NZ$": "NZD", "R$": "BRL", "$": "USD",
        "€": "EUR", "£": "GBP", "¥": "JPY", "₹": "INR", "₩": "KRW",
        "₽": "RUB", "₺": "TRY", "₫": "VND", "฿": "THB", "₱": "PHP",
        "₪": "ILS", "₴": "UAH", "₦": "NGN", "₡": "CRC", "₲": "PYG",
        "₸": "KZT", "₮": "MNT", "Rp": "IDR", "RM": "MYR", "kr": "SEK",
        "zł": "PLN", "Kč": "CZK", "Ft": "HUF", "lei": "RON", "CHF": "CHF",
        "د.إ": "AED", "﷼": "SAR",
    ]

    /// Active ISO 4217 codes. A 3-letter word that is not a real code must not
    /// trigger a network call, so membership is checked before conversion.
    private static let knownCodes: Set<String> = Set(
        """
        AED AFN ALL AMD ANG AOA ARS AUD AWG AZN BAM BBD BDT BGN BHD BIF BMD BND
        BOB BRL BSD BTN BWP BYN BZD CAD CDF CHF CLP CNY COP CRC CUP CVE CZK DJF
        DKK DOP DZD EGP ERN ETB EUR FJD FKP GBP GEL GHS GIP GMD GNF GTQ GYD HKD
        HNL HTG HUF IDR ILS INR IQD IRR ISK JMD JOD JPY KES KGS KHR KMF KPW KRW
        KWD KYD KZT LAK LBP LKR LRD LSL LYD MAD MDL MGA MKD MMK MNT MOP MRU MUR
        MVR MWK MXN MYR MZN NAD NGN NIO NOK NPR NZD OMR PAB PEN PGK PHP PKR PLN
        PYG QAR RON RSD RUB RWF SAR SBD SCR SDG SEK SGD SHP SLE SOS SRD SSP STN
        SVC SYP SZL THB TJS TMT TND TOP TRY TTD TWD TZS UAH UGX USD UYU UZS VES
        VND VUV WST XAF XCD XOF XPF YER ZAR ZMW ZWL
        """.split(whereSeparator: \.isWhitespace).map(String.init)
    )
}

/// Formats a converted amount for display, using the user's locale.
///
/// Formatting is technically a presentation concern, but the palette row's text
/// is built in Domain (the calculator fallback formats there too), so it lives
/// here — locale-aware and testable without a window.
public enum CurrencyFormatter {
    /// - Returns: The amount rendered in `code`'s currency style, e.g. `Rp 320.000`.
    public static func string(_ amount: Decimal, code: String, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = locale
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount) \(code)"
    }
}
