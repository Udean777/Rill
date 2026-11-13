import AppKit

/// Refcounts `.regular` overrides so an auxiliary window (Settings, About) can
/// activate without permanently giving the launcher a Dock tile or menu bar.
///
/// Nothing else in the codebase may call `NSApp.setActivationPolicy(_:)`.
@MainActor
public final class ActivationPolicyController {
    public static let shared = ActivationPolicyController()

    private var regularOverrides = 0

    public init() {}

    public func ensureAccessory() {
        guard regularOverrides == 0 else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    public func acquireRegular() {
        regularOverrides += 1
        guard regularOverrides == 1 else { return }
        NSApp.setActivationPolicy(.regular)
    }

    public func releaseRegular() {
        guard regularOverrides > 0 else { return }
        regularOverrides -= 1
        guard regularOverrides == 0 else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}
