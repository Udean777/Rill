import Foundation
import RillDomain

/// The built-in catalogue of macOS System Settings panes.
///
/// Each pane is opened with the `x-apple.systempreferences:` URL scheme. The
/// identifiers are the Settings extensions shipped by macOS; a pane that is
/// missing on an older system simply fails to open, which the dispatcher logs.
public struct SystemSettingsCatalog: SystemSettingsProviding {
    public let settings: [SearchResult]

    public init() {
        settings = Self.builtIns()
    }

    private static func builtIns() -> [SearchResult] {
        [
            setting("wallpaper", "Wallpaper", "photo.on.rectangle",
                    "com.apple.Wallpaper-Settings.extension"),
            setting("desktop-dock", "Desktop & Dock", "macwindow",
                    "com.apple.Desktop-Settings.extension"),
            setting("accessibility", "Accessibility", "figure.stand",
                    "com.apple.Accessibility-Settings.extension"),
            setting("privacy", "Privacy & Security", "hand.raised",
                    "com.apple.settings.PrivacySecurity.extension"),
            setting("bluetooth", "Bluetooth", "wave.3.right",
                    "com.apple.BluetoothSettings"),
            setting("wifi", "Wi-Fi", "wifi",
                    "com.apple.Network-Settings.extension"),
            setting("displays", "Displays", "display",
                    "com.apple.Displays-Settings.extension"),
            setting("sound", "Sound", "speaker.wave.2",
                    "com.apple.Sound-Settings.extension"),
            setting("keyboard", "Keyboard", "keyboard",
                    "com.apple.Keyboard-Settings.extension"),
            setting("trackpad", "Trackpad", "rectangle.and.hand.point.up.left",
                    "com.apple.Trackpad-Settings.extension"),
            setting("mouse", "Mouse", "computermouse",
                    "com.apple.Mouse-Settings.extension"),
            setting("users", "Users & Groups", "person.2",
                    "com.apple.Users-Groups-Settings.extension"),
            setting("software-update", "Software Update", "arrow.triangle.2.circlepath",
                    "com.apple.Software-Update-Settings.extension"),
            setting("notifications", "Notifications", "bell",
                    "com.apple.Notifications-Settings.extension"),
            setting("appearance", "Appearance", "paintbrush",
                    "com.apple.Appearance-Settings.extension"),
            setting("lock-screen", "Lock Screen", "lock",
                    "com.apple.Lock-Screen-Settings.extension"),
            setting("focus", "Focus", "moon",
                    "com.apple.Focus-Settings.extension"),
            setting("spotlight", "Spotlight", "magnifyingglass",
                    "com.apple.Spotlight-Settings.extension"),
            setting("sharing", "Sharing", "square.and.arrow.up",
                    "com.apple.Sharing-Settings.extension"),
            setting("general", "General", "gearshape",
                    "com.apple.systempreferences.GeneralSettings"),
        ].compactMap { $0 }
    }

    private static func setting(
        _ raw: String,
        _ title: String.LocalizationValue,
        _ symbol: String,
        _ pane: String
    ) -> SearchResult? {
        guard let url = URL(string: "x-apple.systempreferences:\(pane)") else {
            return nil
        }
        return SearchResult(
            id: .init(source: "system-settings", raw: raw),
            title: String(localized: title),
            icon: .systemSymbol(symbol),
            section: .systemSettings,
            kind: .systemSettings,
            primaryAction: .openURL(url)
        )
    }
}
