import AppKit

/// Refcounts `.regular` overrides so an auxiliary window (Settings, About) can
/// activate without permanently giving the launcher a Dock tile or menu bar.
///
/// Nothing else in the codebase may call `NSApp.setActivationPolicy(_:)`.
final class ActivationPolicyController {
    private var regularOverrides = 0

    func acquireRegular() {
        regularOverrides += 1
        guard regularOverrides == 1 else { return }
        NSApp.setActivationPolicy(.regular)
    }

    func releaseRegular() {
        guard regularOverrides > 0 else { return }
        regularOverrides -= 1
        guard regularOverrides == 0 else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}
