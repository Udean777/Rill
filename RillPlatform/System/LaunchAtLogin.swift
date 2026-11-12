import ServiceManagement
import os

/// Errors that can occur when toggling launch-at-login state.
public enum LaunchAtLoginError: Error, Equatable, Sendable {
    case registrationFailed
}

/// Manages launch-at-login registration using macOS `SMAppService`
@MainActor
public final class LaunchAtLogin {
    private let log = Logger(subsystem: "com.ssajudn.Rill", category: "launchAtLogin")

    public init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public func setEnabled(_ enabled: Bool) throws(LaunchAtLoginError) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            log.error("Failed to update launch at login status to \(enabled): \(error.localizedDescription, privacy: .public)")
            throw .registrationFailed
        }
    }
}
