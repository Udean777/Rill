import AppKit
import RillDomain
import SwiftUI

/// NSView wrapper that intercepts key events to record a user-defined hotkey.
public struct HotkeyRecorderView: NSViewRepresentable {
    @Binding public var hotkey: Hotkey
    public var onRecorded: ((Hotkey) -> Void)?

    public init(hotkey: Binding<Hotkey>, onRecorded: ((Hotkey) -> Void)? = nil) {
        self._hotkey = hotkey
        self.onRecorded = onRecorded
    }

    public func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.currentHotkey = hotkey
        view.onHotkeyChanged = { newHotkey in
            self.hotkey = newHotkey
            self.onRecorded?(newHotkey)
        }
        return view
    }

    public func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.currentHotkey = hotkey
    }
}

public final class HotkeyRecorderNSView: NSView {
    public var currentHotkey: Hotkey = .default {
        didSet {
            button.title = formatHotkey(currentHotkey)
        }
    }

    public var onHotkeyChanged: ((Hotkey) -> Void)?

    private var isRecording = false {
        didSet {
            button.title = isRecording ? String(localized: "Type shortcut...") : formatHotkey(currentHotkey)
            button.highlight(isRecording)
        }
    }

    private let button = NSButton(title: "", target: nil, action: nil)

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        button.target = self
        button.action = #selector(buttonClicked)
        button.bezelStyle = .rounded
        button.title = formatHotkey(currentHotkey)
        button.translatesAutoresizingMaskIntoConstraints = false

        addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @objc private func buttonClicked() {
        if isRecording {
            isRecording = false
            window?.makeFirstResponder(nil)
        } else {
            isRecording = true
            window?.makeFirstResponder(self)
        }
    }

    public override var acceptsFirstResponder: Bool { true }

    public override func resignFirstResponder() -> Bool {
        if isRecording {
            isRecording = false
        }
        return super.resignFirstResponder()
    }

    public override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 { // Escape cancels recording
            isRecording = false
            window?.makeFirstResponder(nil)
            return
        }

        var modifiers: HotkeyModifiers = []
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
        if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
        if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }

        // At least one modifier is generally expected for global shortcuts
        guard !modifiers.isEmpty else {
            NSSound.beep()
            return
        }

        let newHotkey = Hotkey(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        currentHotkey = newHotkey
        isRecording = false
        window?.makeFirstResponder(nil)
        onHotkeyChanged?(newHotkey)
    }

    private static let keyNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[",
        34: "I", 35: "P", 36: "Return", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
        42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
        50: "`", 51: "Delete", 53: "Esc",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    private func formatHotkey(_ hotkey: Hotkey) -> String {
        var parts: [String] = []
        if hotkey.modifiers.contains(.control) { parts.append("⌃") }
        if hotkey.modifiers.contains(.option) { parts.append("⌥") }
        if hotkey.modifiers.contains(.shift) { parts.append("⇧") }
        if hotkey.modifiers.contains(.command) { parts.append("⌘") }
        parts.append(Self.keyNames[hotkey.keyCode] ?? "Key \(hotkey.keyCode)")
        return parts.joined()
    }
}
