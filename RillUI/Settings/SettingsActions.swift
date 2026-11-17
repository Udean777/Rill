import RillDomain

/// Callbacks the Settings window uses to mutate preferences and register
/// shortcuts. Wired once by the composition root.
public struct SettingsPreferencesActions {
    public var onHotkeyChanged: ((Hotkey) async -> Bool)?
    public var onClipboardHotkeyChanged: ((Hotkey) async -> Bool)?
    public var onApplicationsHotkeyChanged: ((Hotkey) async -> Bool)?
    public var onPreferencesChanged: ((Preferences) -> Void)?

    public init(
        onHotkeyChanged: ((Hotkey) async -> Bool)? = nil,
        onClipboardHotkeyChanged: ((Hotkey) async -> Bool)? = nil,
        onApplicationsHotkeyChanged: ((Hotkey) async -> Bool)? = nil,
        onPreferencesChanged: ((Preferences) -> Void)? = nil
    ) {
        self.onHotkeyChanged = onHotkeyChanged
        self.onClipboardHotkeyChanged = onClipboardHotkeyChanged
        self.onApplicationsHotkeyChanged = onApplicationsHotkeyChanged
        self.onPreferencesChanged = onPreferencesChanged
    }
}

/// Callbacks for permissions, login items, browsers, and the trackpad panel.
public struct SettingsPermissionsActions {
    public var getLaunchAtLogin: (() -> Bool)?
    public var setLaunchAtLogin: ((Bool) throws -> Void)?
    public var checkAccessibility: (() -> Bool)?
    public var checkFullDiskAccess: (() -> Bool)?
    public var openAccessibilitySettings: (() async -> Void)?
    public var openFullDiskAccessSettings: (() async -> Void)?
    public var requestProtectedFolderAccess: (() async -> Void)?
    public var revealApplicationInFinder: (() -> Void)?
    public var getInstalledBrowsers: (() -> [BrowserOption])?
    public var openTrackpadSettings: (() -> Void)?
    public var checkSystemFourFingerPinchDisabled: (() -> Bool)?

    public init(
        getLaunchAtLogin: (() -> Bool)? = nil,
        setLaunchAtLogin: ((Bool) throws -> Void)? = nil,
        checkAccessibility: (() -> Bool)? = nil,
        checkFullDiskAccess: (() -> Bool)? = nil,
        openAccessibilitySettings: (() async -> Void)? = nil,
        openFullDiskAccessSettings: (() async -> Void)? = nil,
        requestProtectedFolderAccess: (() async -> Void)? = nil,
        revealApplicationInFinder: (() -> Void)? = nil,
        getInstalledBrowsers: (() -> [BrowserOption])? = nil,
        openTrackpadSettings: (() -> Void)? = nil,
        checkSystemFourFingerPinchDisabled: (() -> Bool)? = nil
    ) {
        self.getLaunchAtLogin = getLaunchAtLogin
        self.setLaunchAtLogin = setLaunchAtLogin
        self.checkAccessibility = checkAccessibility
        self.checkFullDiskAccess = checkFullDiskAccess
        self.openAccessibilitySettings = openAccessibilitySettings
        self.openFullDiskAccessSettings = openFullDiskAccessSettings
        self.requestProtectedFolderAccess = requestProtectedFolderAccess
        self.revealApplicationInFinder = revealApplicationInFinder
        self.getInstalledBrowsers = getInstalledBrowsers
        self.openTrackpadSettings = openTrackpadSettings
        self.checkSystemFourFingerPinchDisabled = checkSystemFourFingerPinchDisabled
    }
}

/// Callbacks for destructive or revealing actions on stored data.
public struct SettingsDataActions {
    public var resetUsage: (() async -> Void)?
    public var clearPins: (() async -> Void)?
    public var clearClipboardHistory: (() async -> Void)?
    public var revealUsageFile: (() -> Void)?
    public var resetApplicationsLayout: (() async -> Void)?

    public init(
        resetUsage: (() async -> Void)? = nil,
        clearPins: (() async -> Void)? = nil,
        clearClipboardHistory: (() async -> Void)? = nil,
        revealUsageFile: (() -> Void)? = nil,
        resetApplicationsLayout: (() async -> Void)? = nil
    ) {
        self.resetUsage = resetUsage
        self.clearPins = clearPins
        self.clearClipboardHistory = clearClipboardHistory
        self.revealUsageFile = revealUsageFile
        self.resetApplicationsLayout = resetApplicationsLayout
    }
}
