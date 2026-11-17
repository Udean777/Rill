import Foundation
import Observation
import RillDomain

/// Permission, login-item, browser, and trackpad state for the Settings window.
@MainActor
@Observable
public final class PermissionsStatus {
    public var isAccessibilityGranted = false
    public var isFullDiskAccessGranted = false
    public var isRequestingFolderAccess = false
    public var isLaunchAtLoginEnabled = false
    public var launchAtLoginError: String?
    public var isSystemFourFingerPinchDisabled = false
    public var availableBrowsers: [BrowserOption] = []

    @ObservationIgnored private var actions = SettingsPermissionsActions()

    func configure(actions: SettingsPermissionsActions) {
        self.actions = actions
    }

    /// Reads permission and system state. No side effects.
    public func refresh() {
        if let checkAccessibility = actions.checkAccessibility {
            isAccessibilityGranted = checkAccessibility()
        }
        if let checkFullDiskAccess = actions.checkFullDiskAccess {
            isFullDiskAccessGranted = checkFullDiskAccess()
        }
        if let getLaunchAtLogin = actions.getLaunchAtLogin {
            isLaunchAtLoginEnabled = getLaunchAtLogin()
        }
        if let getInstalledBrowsers = actions.getInstalledBrowsers {
            availableBrowsers = getInstalledBrowsers()
        }
        if let checkSystemFourFingerPinchDisabled = actions.checkSystemFourFingerPinchDisabled {
            isSystemFourFingerPinchDisabled = checkSystemFourFingerPinchDisabled()
        }
    }

    public func toggleLaunchAtLogin(_ enabled: Bool) {
        guard let setLaunchAtLogin = actions.setLaunchAtLogin else { return }
        do {
            try setLaunchAtLogin(enabled)
            isLaunchAtLoginEnabled = enabled
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
            refresh()
        }
    }

    public func openAccessibilitySettings() {
        Task {
            await actions.openAccessibilitySettings?()
            refresh()
        }
    }

    public func openFullDiskAccessSettings() {
        Task {
            await actions.openFullDiskAccessSettings?()
            refresh()
        }
    }

    public func requestProtectedFolderAccess() {
        guard !isRequestingFolderAccess else { return }
        isRequestingFolderAccess = true
        Task {
            await actions.requestProtectedFolderAccess?()
            isRequestingFolderAccess = false
            refresh()
        }
    }

    public func revealApplicationInFinder() {
        actions.revealApplicationInFinder?()
    }

    public func openTrackpadMoreGesturesSettings() {
        actions.openTrackpadSettings?()
    }
}
