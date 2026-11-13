import Foundation

/// Supplies the user's local currency and region from the system locale.
///
/// Injected so Domain never reads `Locale.current` (an ambient side effect),
/// and tests can pin a locale.
public protocol LocaleProviding: Sendable {
    /// The user's currency code (ISO 4217), e.g. `"IDR"`, or `nil` when unknown.
    var currencyCode: String? { get }

    /// The user's region code, e.g. `"ID"`, or `nil` when unknown.
    var regionCode: String? { get }

    /// The locale used to format converted amounts.
    var locale: Locale { get }
}
