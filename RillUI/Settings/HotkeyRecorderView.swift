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
            button.title = isRecording ? "Type shortcut..." : formatHotkey(currentHotkey)
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

    private func formatHotkey(_ hotkey: Hotkey) -> String {
        var parts: [String] = []
        if hotkey.modifiers.contains(.control) { parts.append("⌃") }
        if hotkey.modifiers.contains(.option) { parts.append("⌥") }
        if hotkey.modifiers.contains(.shift) { parts.append("⇧") }
        if hotkey.modifiers.contains(.command) { parts.append("⌘") }

        let keyString: String
        switch hotkey.keyCode {
        case 0: keyString = "A"
        case 1: keyString = "S"
        case 2: keyString = "D"
        case 3: keyString = "F"
        case 4: keyString = "H"
        case 5: keyString = "G"
        case 6: keyString = "Z"
        case 7: keyString = "X"
        case 8: keyString = "C"
        case 9: keyString = "V"
        case 11: keyString = "B"
        case 12: keyString = "Q"
        case 13: keyString = "W"
        case 14: keyString = "E"
        case 15: keyString = "R"
        case 16: keyString = "Y"
        case 17: keyString = "T"
        case 18: keyString = "1"
        case 19: keyString = "2"
        case 20: keyString = "3"
        case 21: keyString = "4"
        case 22: keyString = "6"
        case 23: keyString = "5"
        case 24: keyString = "="
        case 25: keyString = "9"
        case 26: keyString = "7"
        case 27: keyString = "-"
        case 28: keyString = "8"
        case 29: keyString = "0"
        case 30: keyString = "]"
        case 31: keyString = "O"
        case 32: keyString = "U"
        case 33: keyString = "["
        case 34: keyString = "I"
        case 35: keyString = "P"
        case 36: keyString = "Return"
        case 37: keyString = "L"
        case 38: keyString = "J"
        case 39: keyString = "'"
        case 40: keyString = "K"
        case 41: keyString = ";"
        case 42: keyString = "\\"
        case 43: keyString = ","
        case 44: keyString = "/"
        case 45: keyString = "N"
        case 46: keyString = "M"
        case 47: keyString = "."
        case 48: keyString = "Tab"
        case 49: keyString = "Space"
        case 50: keyString = "`"
        case 51: keyString = "Delete"
        case 53: keyString = "Esc"
        case 123: keyString = "←"
        case 124: keyString = "→"
        case 125: keyString = "↓"
        case 126: keyString = "↑"
        default:
            keyString = "Key \(hotkey.keyCode)"
        }
        parts.append(keyString)

        return parts.joined()
    }
}
