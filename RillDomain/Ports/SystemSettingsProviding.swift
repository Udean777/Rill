import Foundation

/// Supplies the built-in catalogue of macOS System Settings panes.
///
/// These are data, not behaviour: each result carries an `openURL` action that
/// the platform dispatcher already knows how to perform.
public protocol SystemSettingsProviding: Sendable {
    var settings: [SearchResult] { get }
}
