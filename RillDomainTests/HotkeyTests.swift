import Testing

@testable import RillDomain

@Suite("Hotkey")
struct HotkeyTests {
    @Test func `default hotkey is option-space`() {
        #expect(Hotkey.default.keyCode == 49)
        #expect(Hotkey.default.modifiers == .option)
    }

    @Test func `modifiers combine without collisions`() {
        let combined: HotkeyModifiers = [.command, .option]

        #expect(combined.contains(.command))
        #expect(combined.contains(.option))
        #expect(!combined.contains(.shift))
        #expect(!combined.contains(.control))
    }
}
