/// A system-wide hotkey, expressed in Carbon key codes so Domain never imports Carbon.
public struct Hotkey: Sendable, Hashable {
    /// Carbon virtual key code (`kVK_*`).
    public let keyCode: UInt32

    /// Modifier keys held with the key.
    public let modifiers: HotkeyModifiers

    public init(keyCode: UInt32, modifiers: HotkeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// ⌥Space. Chosen over ⌘Space because Spotlight owns that combination.
    public static let `default` = Hotkey(keyCode: 49, modifiers: .option)
}
