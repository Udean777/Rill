import Foundation
import Observation
import RillDomain

/// Registers the global shortcuts and owns their conflict state. A rejected
/// shortcut is rolled back so the working one stays live.
@MainActor
@Observable
public final class HotkeyCoordinator {
    public var primaryError: String?
    public var isPrimaryRegistered = true
    public var clipboardError: String?
    public var isClipboardRegistered = true
    public var applicationsError: String?
    public var isApplicationsRegistered = true

    @ObservationIgnored private let editor: PreferencesEditor
    @ObservationIgnored private var actions = SettingsPreferencesActions()

    init(editor: PreferencesEditor) {
        self.editor = editor
    }

    func configure(actions: SettingsPreferencesActions) {
        self.actions = actions
    }

    public func updatePrimary(_ newHotkey: Hotkey) {
        guard editor.values.hotkey != newHotkey else { return }
        Task {
            await apply(
                newHotkey,
                keyPath: \.hotkey,
                registeredKeyPath: \.isPrimaryRegistered,
                errorKeyPath: \.primaryError,
                conflictMessage: String(localized: "That shortcut is already used by another app."),
                register: actions.onHotkeyChanged
            )
        }
    }

    public func updateClipboard(_ newHotkey: Hotkey) async {
        guard editor.values.clipboardHotkey != newHotkey else { return }
        await apply(
            newHotkey,
            keyPath: \.clipboardHotkey,
            registeredKeyPath: \.isClipboardRegistered,
            errorKeyPath: \.clipboardError,
            conflictMessage: String(localized: "This shortcut is in use by another application."),
            register: actions.onClipboardHotkeyChanged
        )
    }

    public func updateApplications(_ newHotkey: Hotkey) async {
        guard editor.values.applicationsHotkey != newHotkey else { return }
        await apply(
            newHotkey,
            keyPath: \.applicationsHotkey,
            registeredKeyPath: \.isApplicationsRegistered,
            errorKeyPath: \.applicationsError,
            conflictMessage: String(localized: "This shortcut is in use by another application."),
            register: actions.onApplicationsHotkeyChanged
        )
    }

    private func apply(
        _ newHotkey: Hotkey,
        keyPath: WritableKeyPath<Preferences, Hotkey>,
        registeredKeyPath: ReferenceWritableKeyPath<HotkeyCoordinator, Bool>,
        errorKeyPath: ReferenceWritableKeyPath<HotkeyCoordinator, String?>,
        conflictMessage: String,
        register: ((Hotkey) async -> Bool)?
    ) async {
        let previous = editor.values[keyPath: keyPath]
        editor.setHotkey(newHotkey, at: keyPath)
        self[keyPath: errorKeyPath] = nil

        let registered = await register?(newHotkey) ?? true
        self[keyPath: registeredKeyPath] = registered
        guard registered else {
            editor.setHotkey(previous, at: keyPath)
            self[keyPath: errorKeyPath] = conflictMessage
            return
        }
        await editor.persist()
    }

    /// Registers a stored shortcut without persisting; used by reset-to-defaults.
    func registerPrimary(_ hotkey: Hotkey) async -> Bool {
        let registered = await actions.onHotkeyChanged?(hotkey) ?? true
        isPrimaryRegistered = registered
        return registered
    }
}
