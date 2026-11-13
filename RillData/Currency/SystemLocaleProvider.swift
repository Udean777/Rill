import Foundation
import RillDomain

/// Reads the user's currency and region from the system locale.
///
/// This is the only place the app touches `Locale.current`; the rest of the
/// code receives it through the `LocaleProviding` port.
public struct SystemLocaleProvider: LocaleProviding {
    public init() {}

    public var currencyCode: String? {
        Locale.current.currency?.identifier
    }

    public var regionCode: String? {
        Locale.current.region?.identifier
    }

    public var locale: Locale {
        Locale.current
    }
}
