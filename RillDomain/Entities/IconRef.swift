import Foundation

/// A value describing how to load a result's icon. Never an image: icons are
/// decoded lazily in the UI layer.
public enum IconRef: Sendable, Hashable {
    /// An SF Symbol name.
    case systemSymbol(String)

    /// A file or bundle path the UI resolves with `NSWorkspace`.
    case fileURL(URL)
}
