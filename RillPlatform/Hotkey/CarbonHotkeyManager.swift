import Carbon
import os
import RillDomain

/// Registers global hotkeys through Carbon's `RegisterEventHotKey`, the only
/// global-hotkey API that needs no Accessibility grant and installs no event tap.
@MainActor
public final class CarbonHotkeyManager: HotkeyRegistering {
    private static let signature: FourCharCode = 0x52494C4C  // "RILL"

    /// Carbon delivers hotkey events on the main run loop, so this table is only
    /// ever touched there. It is the project's one justified piece of static state.
    private static let handlerTable = HandlerTable()

    private static let eventHandler: EventHandlerUPP = { _, event, _ in
        guard let event else { return OSStatus(eventNotHandledErr) }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr else { return OSStatus(eventNotHandledErr) }

        // Carbon dispatches hotkey events on the main run loop.
        MainActor.assumeIsolated {
            CarbonHotkeyManager.handlerTable.handlers[hotKeyID.id]?()
        }
        return noErr
    }

    private let log = Logger(subsystem: "com.ssajudn.Rill", category: "hotkey")
    private let onTrigger: @MainActor () -> Void
    private var registrations: [HotkeyToken: EventHotKeyRef] = [:]
    private var eventHandlerRef: EventHandlerRef?
    private var nextID: UInt32 = 1

    public init(onTrigger: @escaping @MainActor () -> Void) {
        self.onTrigger = onTrigger
    }

    public nonisolated func register(
        _ hotkey: Hotkey,
        handler: (@MainActor () -> Void)? = nil
    ) async throws(HotkeyError) -> HotkeyToken {
        switch await MainActor.run(body: { self.registerOnMain(hotkey, handler: handler) }) {
        case .success(let token):
            return token
        case .failure(let error):
            throw error
        }
    }

    public nonisolated func register(
        _ hotkey: Hotkey
    ) async throws(HotkeyError) -> HotkeyToken {
        try await register(hotkey, handler: nil)
    }

    public nonisolated func unregister(_ token: HotkeyToken) async {
        await MainActor.run {
            self.unregisterOnMain(token)
        }
    }

    private func registerOnMain(
        _ hotkey: Hotkey,
        handler: (@MainActor () -> Void)? = nil
    ) -> Result<HotkeyToken, HotkeyError> {
        do {
            try installEventHandler()
        } catch {
            return .failure(error)
        }

        let token = HotkeyToken(rawValue: nextID)
        nextID += 1

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers.rawValue,
            EventHotKeyID(signature: Self.signature, id: token.rawValue),
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            log.error("hotkey registration failed status=\(status)")
            return .failure(.unavailable)
        }

        registrations[token] = ref
        Self.handlerTable.handlers[token.rawValue] = handler ?? onTrigger
        return .success(token)
    }

    private func unregisterOnMain(_ token: HotkeyToken) {
        guard let ref = registrations.removeValue(forKey: token) else { return }
        UnregisterEventHotKey(ref)
        Self.handlerTable.handlers[token.rawValue] = nil
    }

    private func installEventHandler() throws(HotkeyError) {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        var ref: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandler,
            1,
            &eventType,
            nil,
            &ref
        )
        guard status == noErr else {
            log.error("hotkey event handler install failed status=\(status)")
            throw .unavailable
        }
        eventHandlerRef = ref
    }
}

/// Holds the token→trigger map. A reference box keeps the static storage `let`.
@MainActor
private final class HandlerTable {
    var handlers: [UInt32: @MainActor () -> Void] = [:]
}
