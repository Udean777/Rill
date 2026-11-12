import Foundation

/// The behaviour a result runs. Data, not a closure, so it can cross an async
/// boundary and be logged.
public enum ActionDescriptor: Sendable, Hashable {
    /// Launches the application with this bundle identifier.
    case openApplication(bundleID: String)

    /// Opens a URL in the user's default handler.
    case openURL(URL)

    /// Opens a file or folder in its default application.
    case openFile(URL)

    /// Copies text to the system pasteboard.
    case copyToPasteboard(String)

    /// Opens this app's own Settings window. Handled by the app layer, which
    /// owns the window; a system action performer cannot show it.
    case openSettings

    /// Opens the Clipboard History palette mode.
    case openClipboardHistory
}
