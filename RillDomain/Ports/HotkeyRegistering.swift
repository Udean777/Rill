/// A handle to a registered global hotkey.
public struct HotkeyToken: Hashable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

/// Failure modes when registering a hotkey. Closed set, so it is typed on the throw.
public enum HotkeyError: Error, Equatable, Sendable {
    /// The system refused the combination, usually because another app owns it.
    case unavailable
}

/// Registers a system-wide hotkey that fires while any app is frontmost.
///
/// Presses reach the implementation through the trigger it was constructed with,
/// so this port stays free of any UI or AppKit type.
public protocol HotkeyRegistering: Sendable {
    /// Registers `hotkey` and starts delivering its presses.
    func register(_ hotkey: Hotkey) async throws(HotkeyError) -> HotkeyToken

    /// Releases a registration. Unknown tokens are ignored.
    func unregister(_ token: HotkeyToken) async
}
