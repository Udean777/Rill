import Foundation

/// Curated macOS System Settings panes, sub-menus, and sub-sub-menus.
enum SystemSettingsCuratedEntries {
    struct Entry: Sendable {
        let raw: String
        let title: String
        let subtitle: String?
        let symbol: String
        let target: String
    }

    struct IntentsBundleMetadata: Sendable {
        let bundleName: String
        let paneID: String
        let parentTitle: String
        let symbol: String
    }

    static var all: [Entry] {
        mainPanes
            + generalSubMenus
            + privacySubMenus
            + accessibilitySubMenus
            + desktopDisplaysKeyboardSubMenus
            + systemAndAccountSubMenus
            + popularActionEntries
    }

    // MARK: - Main Panes

    private static let mainPanes: [Entry] = [
        Entry(raw: "apple-account", title: "Apple Account", subtitle: nil, symbol: "person.crop.circle", target: "com.apple.systempreferences.AppleIDSettings"),
        Entry(raw: "family", title: "Family", subtitle: nil, symbol: "figure.2.and.child.holdinghands", target: "com.apple.Family-Settings.extension"),
        Entry(raw: "wifi", title: "Wi-Fi", subtitle: nil, symbol: "wifi", target: "com.apple.wifi-settings-extension"),
        Entry(raw: "bluetooth", title: "Bluetooth", subtitle: nil, symbol: "wave.3.right", target: "com.apple.BluetoothSettings"),
        Entry(raw: "network", title: "Network", subtitle: nil, symbol: "network", target: "com.apple.Network-Settings.extension"),
        Entry(raw: "vpn", title: "VPN", subtitle: nil, symbol: "network.badge.shield.half.filled", target: "com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension"),
        Entry(raw: "battery", title: "Battery", subtitle: nil, symbol: "battery.100percent", target: "com.apple.Battery-Settings.extension"),
        Entry(raw: "general", title: "General", subtitle: nil, symbol: "gearshape", target: "com.apple.systempreferences.GeneralSettings"),
        Entry(raw: "accessibility", title: "Accessibility", subtitle: nil, symbol: "figure.stand", target: "com.apple.Accessibility-Settings.extension"),
        Entry(raw: "appearance", title: "Appearance", subtitle: nil, symbol: "paintbrush", target: "com.apple.Appearance-Settings.extension"),
        Entry(raw: "siri", title: "Apple Intelligence & Siri", subtitle: nil, symbol: "sparkles", target: "com.apple.Siri-Settings.extension"),
        Entry(raw: "control-center", title: "Control Center", subtitle: nil, symbol: "switch.2", target: "com.apple.ControlCenter-Settings.extension"),
        Entry(raw: "desktop-dock", title: "Desktop & Dock", subtitle: nil, symbol: "macwindow", target: "com.apple.Desktop-Settings.extension"),
        Entry(raw: "displays", title: "Displays", subtitle: nil, symbol: "display", target: "com.apple.Displays-Settings.extension"),
        Entry(raw: "screen-saver", title: "Screen Saver", subtitle: nil, symbol: "sparkles.tv", target: "com.apple.ScreenSaver-Settings.extension"),
        Entry(raw: "spotlight", title: "Spotlight", subtitle: nil, symbol: "magnifyingglass", target: "com.apple.Spotlight-Settings.extension"),
        Entry(raw: "wallpaper", title: "Wallpaper", subtitle: nil, symbol: "photo.on.rectangle", target: "com.apple.Wallpaper-Settings.extension"),
        Entry(raw: "notifications", title: "Notifications", subtitle: nil, symbol: "bell", target: "com.apple.Notifications-Settings.extension"),
        Entry(raw: "sound", title: "Sound", subtitle: nil, symbol: "speaker.wave.2", target: "com.apple.Sound-Settings.extension"),
        Entry(raw: "focus", title: "Focus", subtitle: nil, symbol: "moon", target: "com.apple.Focus-Settings.extension"),
        Entry(raw: "screen-time", title: "Screen Time", subtitle: nil, symbol: "hourglass", target: "com.apple.Screen-Time-Settings.extension"),
        Entry(raw: "lock-screen", title: "Lock Screen", subtitle: nil, symbol: "lock", target: "com.apple.Lock-Screen-Settings.extension"),
        Entry(raw: "privacy", title: "Privacy & Security", subtitle: nil, symbol: "hand.raised", target: "com.apple.settings.PrivacySecurity.extension"),
        Entry(raw: "touch-id", title: "Touch ID & Password", subtitle: nil, symbol: "touchid", target: "com.apple.Touch-ID-Settings.extension"),
        Entry(raw: "users", title: "Users & Groups", subtitle: nil, symbol: "person.2", target: "com.apple.Users-Groups-Settings.extension"),
        Entry(raw: "internet-accounts", title: "Internet Accounts", subtitle: nil, symbol: "at", target: "com.apple.Internet-Accounts-Settings.extension"),
        Entry(raw: "game-center", title: "Game Center", subtitle: nil, symbol: "gamecontroller", target: "com.apple.Game-Center-Settings.extension"),
        Entry(raw: "wallet", title: "Wallet & Apple Pay", subtitle: nil, symbol: "creditcard", target: "com.apple.WalletSettingsExtension"),
        Entry(raw: "passwords", title: "Passwords", subtitle: nil, symbol: "key", target: "com.apple.Passwords-Settings.extension"),
        Entry(raw: "keyboard", title: "Keyboard", subtitle: nil, symbol: "keyboard", target: "com.apple.Keyboard-Settings.extension"),
        Entry(raw: "mouse", title: "Mouse", subtitle: nil, symbol: "computermouse", target: "com.apple.Mouse-Settings.extension"),
        Entry(raw: "trackpad", title: "Trackpad", subtitle: nil, symbol: "rectangle.and.hand.point.up.left", target: "com.apple.Trackpad-Settings.extension"),
        Entry(raw: "game-controllers", title: "Game Controllers", subtitle: nil, symbol: "gamecontroller.fill", target: "com.apple.Game-Controller-Settings.extension"),
        Entry(raw: "printers-scanners", title: "Printers & Scanners", subtitle: nil, symbol: "printer", target: "com.apple.Print-Scan-Settings.extension"),
        Entry(raw: "headphones", title: "Headphones", subtitle: nil, symbol: "headphones", target: "com.apple.HeadphoneSettings"),
        Entry(raw: "cds-dvds", title: "CDs & DVDs", subtitle: nil, symbol: "opticaldisc", target: "com.apple.CD-DVD-Settings.extension"),
    ]

    // MARK: - General (Sub-Menus & Sub-Sub-Menus)

    private static let generalSubMenus: [Entry] = [
        Entry(raw: "general-about", title: "About", subtitle: "System Settings › General", symbol: "info.circle", target: "com.apple.SystemProfiler.AboutExtension"),
        Entry(raw: "general-about-displays", title: "About Displays", subtitle: "System Settings › General › About", symbol: "display", target: "com.apple.SystemProfiler.AboutExtension?deviceDisplays"),
        Entry(raw: "general-about-coverage", title: "AppleCare & Warranty", subtitle: "System Settings › General", symbol: "checkmark.shield", target: "com.apple.Coverage-Settings.extension"),
        Entry(raw: "software-update", title: "Software Update", subtitle: "System Settings › General", symbol: "arrow.triangle.2.circlepath", target: "com.apple.Software-Update-Settings.extension"),
        Entry(raw: "general-storage", title: "Storage", subtitle: "System Settings › General", symbol: "internaldrive", target: "com.apple.settings.Storage"),
        Entry(raw: "general-airdrop-handoff", title: "AirDrop & Handoff", subtitle: "System Settings › General", symbol: "airplayvideo", target: "com.apple.AirDrop-Handoff-Settings.extension"),
        Entry(raw: "general-airplay-receiver", title: "AirPlay Receiver", subtitle: "System Settings › General › AirDrop & Handoff", symbol: "airplayvideo", target: "com.apple.AirDrop-Handoff-Settings.extension?AirPlay_Receiver"),
        Entry(raw: "general-iphone-mirroring", title: "iPhone Mirroring", subtitle: "System Settings › General › AirDrop & Handoff", symbol: "iphone", target: "com.apple.AirDrop-Handoff-Settings.extension?iPhone_Mirroring"),
        Entry(raw: "general-login-items", title: "Login Items & Extensions", subtitle: "System Settings › General", symbol: "list.bullet.rectangle", target: "com.apple.LoginItems-Settings.extension"),
        Entry(raw: "general-login-startup", title: "Open at Login", subtitle: "System Settings › General › Login Items & Extensions", symbol: "power", target: "com.apple.LoginItems-Settings.extension?startupItemsPref"),
        Entry(raw: "general-login-extensions", title: "Background Extensions", subtitle: "System Settings › General › Login Items & Extensions", symbol: "puzzlepiece.extension", target: "com.apple.LoginItems-Settings.extension?ExtensionItems"),
        Entry(raw: "general-language-region", title: "Language & Region", subtitle: "System Settings › General", symbol: "globe", target: "com.apple.Localization-Settings.extension"),
        Entry(raw: "general-date-time", title: "Date & Time", subtitle: "System Settings › General", symbol: "clock", target: "com.apple.Date-Time-Settings.extension"),
        Entry(raw: "general-date-time-zone", title: "Time Zone", subtitle: "System Settings › General › Date & Time", symbol: "clock.badge.checkmark", target: "com.apple.Date-Time-Settings.extension?TimeZonePref"),
        Entry(raw: "general-date-24h", title: "24-Hour Time", subtitle: "System Settings › General › Date & Time", symbol: "clock", target: "com.apple.Date-Time-Settings.extension?24HourTime"),
        Entry(raw: "sharing", title: "Sharing", subtitle: "System Settings › General", symbol: "square.and.arrow.up", target: "com.apple.Sharing-Settings.extension"),
        Entry(raw: "sharing-file", title: "File Sharing", subtitle: "System Settings › General › Sharing", symbol: "folder.badge.person.crop", target: "com.apple.Sharing-Settings.extension?Services_PersonalFileSharing"),
        Entry(raw: "sharing-screen", title: "Screen Sharing", subtitle: "System Settings › General › Sharing", symbol: "rectangle.inset.filled.and.person.filled", target: "com.apple.Sharing-Settings.extension?Services_ScreenSharing"),
        Entry(raw: "sharing-remote-login", title: "Remote Login (SSH)", subtitle: "System Settings › General › Sharing", symbol: "terminal", target: "com.apple.Sharing-Settings.extension?Services_RemoteLogin"),
        Entry(raw: "sharing-remote-mgmt", title: "Remote Management", subtitle: "System Settings › General › Sharing", symbol: "desktopcomputer", target: "com.apple.Sharing-Settings.extension?Services_ARDService"),
        Entry(raw: "sharing-internet", title: "Internet Sharing", subtitle: "System Settings › General › Sharing", symbol: "wifi.router", target: "com.apple.Sharing-Settings.extension?Internet"),
        Entry(raw: "sharing-printer", title: "Printer Sharing", subtitle: "System Settings › General › Sharing", symbol: "printer", target: "com.apple.Sharing-Settings.extension?Services_PrinterSharing"),
        Entry(raw: "sharing-bluetooth", title: "Bluetooth Sharing", subtitle: "System Settings › General › Sharing", symbol: "wave.3.right", target: "com.apple.Sharing-Settings.extension?Services_BluetoothSharing"),
        Entry(raw: "sharing-content-caching", title: "Content Caching", subtitle: "System Settings › General › Sharing", symbol: "externaldrive.connected.to.line.below", target: "com.apple.Sharing-Settings.extension?Services_ContentCaching"),
        Entry(raw: "sharing-hostname", title: "Local Hostname", subtitle: "System Settings › General › Sharing", symbol: "network", target: "com.apple.Sharing-Settings.extension?Hostname"),
        Entry(raw: "general-time-machine", title: "Time Machine", subtitle: "System Settings › General", symbol: "clock.arrow.circlepath", target: "com.apple.Time-Machine-Settings.extension"),
        Entry(raw: "general-transfer-reset", title: "Transfer or Reset", subtitle: "System Settings › General", symbol: "arrow.counterclockwise", target: "com.apple.Transfer-Reset-Settings.extension"),
        Entry(raw: "general-startup-disk", title: "Startup Disk", subtitle: "System Settings › General", symbol: "internaldrive.fill", target: "com.apple.Startup-Disk-Settings.extension"),
        Entry(raw: "general-profiles", title: "Device Management (Profiles)", subtitle: "System Settings › General", symbol: "gear.badge", target: "com.apple.Profiles-Settings.extension"),
    ]

    // MARK: - Privacy & Security Sub-Menus

    private static let privacySubMenus: [Entry] = [
        Entry(raw: "privacy-location", title: "Location Services", subtitle: "System Settings › Privacy & Security", symbol: "location", target: "com.apple.settings.PrivacySecurity.extension?Privacy_LocationServices"),
        Entry(raw: "privacy-contacts", title: "Contacts", subtitle: "System Settings › Privacy & Security", symbol: "person.crop.square", target: "com.apple.settings.PrivacySecurity.extension?Privacy_Contacts"),
        Entry(raw: "privacy-calendars", title: "Calendars", subtitle: "System Settings › Privacy & Security", symbol: "calendar", target: "com.apple.settings.PrivacySecurity.extension?Privacy_Calendars"),
        Entry(raw: "privacy-reminders", title: "Reminders", subtitle: "System Settings › Privacy & Security", symbol: "list.bullet", target: "com.apple.settings.PrivacySecurity.extension?Privacy_Reminders"),
        Entry(raw: "privacy-photos", title: "Photos", subtitle: "System Settings › Privacy & Security", symbol: "photo", target: "com.apple.settings.PrivacySecurity.extension?Privacy_Photos"),
        Entry(raw: "privacy-bluetooth", title: "Bluetooth Privacy", subtitle: "System Settings › Privacy & Security", symbol: "wave.3.right", target: "com.apple.settings.PrivacySecurity.extension?Privacy_Bluetooth"),
        Entry(raw: "privacy-microphone", title: "Microphone", subtitle: "System Settings › Privacy & Security", symbol: "mic", target: "com.apple.settings.PrivacySecurity.extension?Privacy_Microphone"),
        Entry(raw: "privacy-camera", title: "Camera", subtitle: "System Settings › Privacy & Security", symbol: "camera", target: "com.apple.settings.PrivacySecurity.extension?Privacy_Camera"),
        Entry(raw: "privacy-motion", title: "Motion & Fitness", subtitle: "System Settings › Privacy & Security", symbol: "figure.walk", target: "com.apple.settings.PrivacySecurity.extension?Privacy_Motion"),
        Entry(raw: "privacy-homekit", title: "HomeKit", subtitle: "System Settings › Privacy & Security", symbol: "homekit", target: "com.apple.settings.PrivacySecurity.extension?Privacy_HomeKit"),
        Entry(raw: "privacy-speech", title: "Speech Recognition", subtitle: "System Settings › Privacy & Security", symbol: "waveform", target: "com.apple.settings.PrivacySecurity.extension?Privacy_SpeechRecognition"),
        Entry(raw: "privacy-media", title: "Media & Apple Music", subtitle: "System Settings › Privacy & Security", symbol: "music.note", target: "com.apple.settings.PrivacySecurity.extension?Privacy_Media"),
        Entry(raw: "privacy-files-folders", title: "Files & Folders", subtitle: "System Settings › Privacy & Security", symbol: "folder", target: "com.apple.settings.PrivacySecurity.extension?Privacy_FilesAndFolders"),
        Entry(raw: "privacy-full-disk", title: "Full Disk Access", subtitle: "System Settings › Privacy & Security", symbol: "internaldrive", target: "com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"),
        Entry(raw: "privacy-focus", title: "Focus Privacy", subtitle: "System Settings › Privacy & Security", symbol: "moon", target: "com.apple.settings.PrivacySecurity.extension?Privacy_Focus"),
        Entry(raw: "privacy-accessibility", title: "Accessibility Permissions", subtitle: "System Settings › Privacy & Security", symbol: "figure.stand", target: "com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"),
        Entry(raw: "privacy-input-monitoring", title: "Input Monitoring", subtitle: "System Settings › Privacy & Security", symbol: "keyboard.badge.eye", target: "com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent"),
        Entry(raw: "privacy-screen-recording", title: "Screen & System Audio Recording", subtitle: "System Settings › Privacy & Security", symbol: "record.circle", target: "com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture"),
        Entry(raw: "privacy-remote-desktop", title: "Remote Desktop", subtitle: "System Settings › Privacy & Security", symbol: "desktopcomputer", target: "com.apple.settings.PrivacySecurity.extension?Privacy_RemoteDesktop"),
        Entry(raw: "privacy-passkeys", title: "Passkeys Access for Web Browsers", subtitle: "System Settings › Privacy & Security", symbol: "person.badge.key", target: "com.apple.settings.PrivacySecurity.extension?Privacy_PasskeyAccess"),
        Entry(raw: "privacy-automation", title: "Automation", subtitle: "System Settings › Privacy & Security", symbol: "gearshape.2", target: "com.apple.settings.PrivacySecurity.extension?Privacy_Automation"),
        Entry(raw: "privacy-app-management", title: "App Management", subtitle: "System Settings › Privacy & Security", symbol: "app.badge", target: "com.apple.settings.PrivacySecurity.extension?Privacy_AppBundles"),
        Entry(raw: "privacy-developer-tools", title: "Developer Tools", subtitle: "System Settings › Privacy & Security", symbol: "hammer", target: "com.apple.settings.PrivacySecurity.extension?Privacy_DevTools"),
        Entry(raw: "privacy-analytics", title: "Analytics & Improvements", subtitle: "System Settings › Privacy & Security", symbol: "chart.bar", target: "com.apple.settings.PrivacySecurity.extension?Privacy_Analytics"),
        Entry(raw: "privacy-advertising", title: "Apple Advertising", subtitle: "System Settings › Privacy & Security", symbol: "megaphone", target: "com.apple.settings.PrivacySecurity.extension?Privacy_Advertising"),
        Entry(raw: "privacy-filevault", title: "FileVault", subtitle: "System Settings › Privacy & Security", symbol: "lock.shield", target: "com.apple.settings.PrivacySecurity.extension?FileVault"),
        Entry(raw: "privacy-lockdown", title: "Lockdown Mode", subtitle: "System Settings › Privacy & Security", symbol: "shield.lefthalf.filled", target: "com.apple.settings.PrivacySecurity.extension?LockdownMode"),
    ]

    // MARK: - Accessibility Sub-Menus & Sub-Sub-Menus

    private static let accessibilitySubMenus: [Entry] = [
        Entry(raw: "ax-voiceover", title: "VoiceOver", subtitle: "System Settings › Accessibility", symbol: "voiceover", target: "com.apple.Accessibility-Settings.extension?AX_FEATURE_VOICEOVER"),
        Entry(raw: "ax-zoom", title: "Zoom", subtitle: "System Settings › Accessibility", symbol: "plus.magnifyingglass", target: "com.apple.Accessibility-Settings.extension?AX_FEATURE_ZOOM"),
        Entry(raw: "ax-hover-text", title: "Hover Text", subtitle: "System Settings › Accessibility", symbol: "textformat.size", target: "com.apple.Accessibility-Settings.extension?AX_FEATURE_HOVERTEXT"),
        Entry(raw: "ax-display", title: "Display (Accessibility)", subtitle: "System Settings › Accessibility", symbol: "display", target: "com.apple.Accessibility-Settings.extension?AX_FEATURE_DISPLAY"),
        Entry(raw: "ax-reduce-motion", title: "Reduce Motion", subtitle: "System Settings › Accessibility › Display", symbol: "circle.dotted", target: "com.apple.Accessibility-Settings.extension?AX_REDUCE_MOTION"),
        Entry(raw: "ax-reduce-transparency", title: "Reduce Transparency", subtitle: "System Settings › Accessibility › Display", symbol: "square.on.square", target: "com.apple.Accessibility-Settings.extension?AX_REDUCE_TRANSPARENCY"),
        Entry(raw: "ax-increase-contrast", title: "Increase Contrast", subtitle: "System Settings › Accessibility › Display", symbol: "circle.lefthalf.filled", target: "com.apple.Accessibility-Settings.extension?AX_INCREASE_CONTRAST"),
        Entry(raw: "ax-invert-colors", title: "Invert Colors", subtitle: "System Settings › Accessibility › Display", symbol: "circle.righthalf.filled", target: "com.apple.Accessibility-Settings.extension?AX_INVERT_COLOR"),
        Entry(raw: "ax-color-filters", title: "Color Filters", subtitle: "System Settings › Accessibility › Display", symbol: "paintpalette", target: "com.apple.Accessibility-Settings.extension?colorFilters"),
        Entry(raw: "ax-pointer-size", title: "Pointer Size & Color", subtitle: "System Settings › Accessibility › Display", symbol: "cursorarrow", target: "com.apple.Accessibility-Settings.extension?pointer"),
        Entry(raw: "ax-text-size", title: "Text Size", subtitle: "System Settings › Accessibility › Display", symbol: "textformat.size", target: "com.apple.Accessibility-Settings.extension?text"),
        Entry(raw: "ax-spoken-content", title: "Spoken Content", subtitle: "System Settings › Accessibility", symbol: "speaker.wave.3", target: "com.apple.Accessibility-Settings.extension?AX_FEATURE_SPOKENCONTENT"),
        Entry(raw: "ax-audio-descriptions", title: "Audio Descriptions", subtitle: "System Settings › Accessibility", symbol: "captions.bubble", target: "com.apple.Accessibility-Settings.extension?AX_FEATURE_DESCRIPTIONS"),
        Entry(raw: "ax-hearing-devices", title: "Hearing Devices", subtitle: "System Settings › Accessibility", symbol: "ear", target: "com.apple.Accessibility-Settings.extension?AX_FEATURE_HEARINGAIDS"),
        Entry(raw: "ax-audio", title: "Audio (Accessibility)", subtitle: "System Settings › Accessibility", symbol: "speaker.wave.2", target: "com.apple.Accessibility-Settings.extension?AX_FEATURE_AUDIO"),
        Entry(raw: "ax-background-sounds", title: "Background Sounds", subtitle: "System Settings › Accessibility › Audio", symbol: "waveform", target: "com.apple.Accessibility-Settings.extension?backgroundSounds"),
        Entry(raw: "ax-mono-audio", title: "Mono Audio", subtitle: "System Settings › Accessibility › Audio", symbol: "headphones", target: "com.apple.Accessibility-Settings.extension?AX_MONO_AUDIO"),
        Entry(raw: "ax-flash-screen", title: "Flash Screen for Alerts", subtitle: "System Settings › Accessibility › Audio", symbol: "bell.badge", target: "com.apple.Accessibility-Settings.extension?AX_FLASH_SCREEN"),
        Entry(raw: "ax-captions", title: "Captions", subtitle: "System Settings › Accessibility", symbol: "captions.bubble", target: "com.apple.Accessibility-Settings.extension?AX_FEATURE_CAPTIONS"),
        Entry(raw: "ax-live-captions", title: "Live Captions", subtitle: "System Settings › Accessibility", symbol: "waveform.and.mic", target: "com.apple.Accessibility-Settings.extension?AX_FEATURE_LIVECAPTIONS"),
        Entry(raw: "ax-voice-control", title: "Voice Control", subtitle: "System Settings › Accessibility", symbol: "mic.fill", target: "com.apple.Accessibility-Settings.extension?AX_FEATURE_VOICECONTROL"),
        Entry(raw: "ax-keyboard", title: "Keyboard (Accessibility)", subtitle: "System Settings › Accessibility", symbol: "keyboard", target: "com.apple.Accessibility-Settings.extension?AX_FEATURE_KEYBOARD"),
        Entry(raw: "ax-pointer-control", title: "Pointer Control", subtitle: "System Settings › Accessibility", symbol: "cursorarrow.click", target: "com.apple.Accessibility-Settings.extension?AX_FEATURE_POINTERCONTROL"),
        Entry(raw: "ax-switch-control", title: "Switch Control", subtitle: "System Settings › Accessibility", symbol: "switch.2", target: "com.apple.Accessibility-Settings.extension?AX_FEATURE_SWITCHCONTROL"),
        Entry(raw: "ax-live-speech", title: "Live Speech", subtitle: "System Settings › Accessibility", symbol: "text.bubble", target: "com.apple.Accessibility-Settings.extension?AX_FEATURE_LIVESPEECH"),
        Entry(raw: "ax-personal-voice", title: "Personal Voice", subtitle: "System Settings › Accessibility", symbol: "person.wave.2", target: "com.apple.Accessibility-Settings.extension?AX_FEATURE_PERSONALVOICE"),
        Entry(raw: "ax-vocal-shortcuts", title: "Vocal Shortcuts", subtitle: "System Settings › Accessibility", symbol: "waveform.circle", target: "com.apple.Accessibility-Settings.extension?AX_FEATURE_AVS"),
        Entry(raw: "ax-shortcut", title: "Accessibility Shortcut", subtitle: "System Settings › Accessibility", symbol: "accessibility", target: "com.apple.Accessibility-Settings.extension?AX_FEATURE_SHORTCUT"),
    ]

    // MARK: - Desktop & Dock, Displays, Keyboard

    private static let desktopDisplaysKeyboardSubMenus: [Entry] = [
        Entry(raw: "desktop-dock-widgets", title: "Widgets", subtitle: "System Settings › Desktop & Dock", symbol: "square.grid.2x2", target: "com.apple.Desktop-Settings.extension?Widgets"),
        Entry(raw: "desktop-dock-stage-manager", title: "Stage Manager", subtitle: "System Settings › Desktop & Dock", symbol: "squares.leading.rectangle", target: "com.apple.Desktop-Settings.extension?StageManager"),
        Entry(raw: "desktop-dock-mission-control", title: "Mission Control", subtitle: "System Settings › Desktop & Dock", symbol: "macwindow.on.rectangle", target: "com.apple.Desktop-Settings.extension?MissionControl"),
        Entry(raw: "desktop-dock-hot-corners", title: "Hot Corners", subtitle: "System Settings › Desktop & Dock", symbol: "rectangle.dashed", target: "com.apple.Desktop-Settings.extension?HotCorners"),
        Entry(raw: "desktop-dock-default-browser", title: "Default Web Browser", subtitle: "System Settings › Desktop & Dock", symbol: "safari", target: "com.apple.Desktop-Settings.extension?DefaultWebBrowser"),
        Entry(raw: "displays-arrangement", title: "Display Arrangement", subtitle: "System Settings › Displays", symbol: "display.2", target: "com.apple.Displays-Settings.extension?arrangementSection"),
        Entry(raw: "displays-night-shift", title: "Night Shift", subtitle: "System Settings › Displays", symbol: "moon.stars", target: "com.apple.Displays-Settings.extension?nightShiftSection"),
        Entry(raw: "displays-color-profile", title: "Color Profile", subtitle: "System Settings › Displays", symbol: "paintpalette", target: "com.apple.Displays-Settings.extension?profileSection"),
        Entry(raw: "displays-advanced", title: "Displays Advanced", subtitle: "System Settings › Displays", symbol: "slider.horizontal.3", target: "com.apple.Displays-Settings.extension?advancedSection"),
        Entry(raw: "keyboard-input-sources", title: "Input Sources", subtitle: "System Settings › Keyboard", symbol: "globe", target: "com.apple.Keyboard-Settings.extension?InputSources"),
        Entry(raw: "keyboard-text-replacements", title: "Text Replacements", subtitle: "System Settings › Keyboard", symbol: "text.quote", target: "com.apple.Keyboard-Settings.extension?TextReplacements"),
        Entry(raw: "keyboard-shortcuts", title: "Keyboard Shortcuts", subtitle: "System Settings › Keyboard", symbol: "command", target: "com.apple.Keyboard-Settings.extension?KeyboardShortcuts"),
        Entry(raw: "keyboard-modifier-keys", title: "Modifier Keys", subtitle: "System Settings › Keyboard › Keyboard Shortcuts", symbol: "option", target: "com.apple.Keyboard-Settings.extension?ModifierKeys"),
        Entry(raw: "keyboard-dictation", title: "Dictation", subtitle: "System Settings › Keyboard", symbol: "mic", target: "com.apple.Siri-Settings.extension?Dictation"),
    ]

    // MARK: - Network, Sound, Battery, Lock Screen, Users, iCloud, Screen Time

    private static let systemAndAccountSubMenus: [Entry] = [
        Entry(raw: "network-firewall", title: "Firewall", subtitle: "System Settings › Network", symbol: "flame", target: "com.apple.Network-Settings.extension?Firewall"),
        Entry(raw: "network-dns", title: "DNS", subtitle: "System Settings › Network", symbol: "server.rack", target: "com.apple.Network-Settings.extension?DNS"),
        Entry(raw: "network-proxies", title: "Proxies", subtitle: "System Settings › Network", symbol: "arrow.triangle.branch", target: "com.apple.Network-Settings.extension?Proxies"),
        Entry(raw: "network-tcpip", title: "TCP/IP", subtitle: "System Settings › Network", symbol: "network", target: "com.apple.Network-Settings.extension?TCP/IP"),
        Entry(raw: "sound-effects", title: "Sound Effects", subtitle: "System Settings › Sound", symbol: "bell.and.waves.left.and.right", target: "com.apple.Sound-Settings.extension?effects"),
        Entry(raw: "sound-output", title: "Sound Output", subtitle: "System Settings › Sound", symbol: "speaker.wave.2", target: "com.apple.Sound-Settings.extension?output"),
        Entry(raw: "sound-input", title: "Sound Input", subtitle: "System Settings › Sound", symbol: "mic", target: "com.apple.Sound-Settings.extension?input"),
        Entry(raw: "battery-health", title: "Battery Health", subtitle: "System Settings › Battery", symbol: "battery.100percent.bolt", target: "com.apple.Battery-Settings.extension?batteryhealth"),
        Entry(raw: "battery-options", title: "Battery Options", subtitle: "System Settings › Battery", symbol: "bolt", target: "com.apple.Battery-Settings.extension?options"),
        Entry(raw: "lock-screen-login-window", title: "Login Window Options", subtitle: "System Settings › Lock Screen", symbol: "person.crop.rectangle", target: "com.apple.Lock-Screen-Settings.extension?LoginWindow"),
        Entry(raw: "lock-screen-password", title: "Require Password to Wake", subtitle: "System Settings › Lock Screen", symbol: "lock.rotation", target: "com.apple.Lock-Screen-Settings.extension?Password"),
        Entry(raw: "lock-screen-display-off", title: "Turn off display when inactive", subtitle: "System Settings › Lock Screen", symbol: "display", target: "com.apple.Lock-Screen-Settings.extension?DisplayOff"),
        Entry(raw: "users-login-options", title: "Login Options", subtitle: "System Settings › Users & Groups", symbol: "person.badge.key", target: "com.apple.Users-Groups-Settings.extension?loginOptionsPref"),
        Entry(raw: "apple-account-icloud", title: "iCloud", subtitle: "System Settings › Apple Account", symbol: "icloud", target: "com.apple.systempreferences.AppleIDSettings:icloud"),
        Entry(raw: "screen-time-downtime", title: "Downtime", subtitle: "System Settings › Screen Time", symbol: "moon.zzz", target: "com.apple.Screen-Time-Settings.extension?path=downtime"),
        Entry(raw: "screen-time-app-limits", title: "App Limits", subtitle: "System Settings › Screen Time", symbol: "timer", target: "com.apple.Screen-Time-Settings.extension?path=app-usage"),
        Entry(raw: "screen-time-always-allowed", title: "Always Allowed", subtitle: "System Settings › Screen Time", symbol: "checkmark.circle", target: "com.apple.Screen-Time-Settings.extension?path=always-allowed"),
        Entry(raw: "screen-time-content-privacy", title: "Content & Privacy", subtitle: "System Settings › Screen Time", symbol: "hand.raised", target: "com.apple.Screen-Time-Settings.extension?path=content-and-privacy"),
        Entry(raw: "spotlight-privacy", title: "Spotlight Search Privacy", subtitle: "System Settings › Spotlight", symbol: "eye.slash", target: "com.apple.Spotlight-Settings.extension?privacy"),
    ]

    // MARK: - Popular Action Entries

    private static let popularActionEntries: [Entry] = [
        Entry(raw: "wallpaper-change", title: "Change the wallpaper", subtitle: "System Settings › Wallpaper", symbol: "photo.on.rectangle", target: "com.apple.Wallpaper-Settings.extension?changeTheWallpaper"),
        Entry(raw: "wallpaper-change-screensaver", title: "Change the screen saver", subtitle: "System Settings › Wallpaper", symbol: "sparkles.tv", target: "com.apple.Wallpaper-Settings.extension?changeTheScreenSaver"),
        Entry(raw: "wallpaper-clock-appearance", title: "Clock appearance", subtitle: "System Settings › Wallpaper", symbol: "clock", target: "com.apple.Wallpaper-Settings.extension?clockAppearance"),
        Entry(raw: "wallpaper-all-spaces", title: "Show wallpaper on all Spaces", subtitle: "System Settings › Wallpaper", symbol: "photo.on.rectangle", target: "com.apple.Wallpaper-Settings.extension?showAsWallpaper"),
        Entry(raw: "wallpaper-screensaver-all-spaces", title: "Show screen saver on all Spaces", subtitle: "System Settings › Wallpaper", symbol: "sparkles.tv", target: "com.apple.Wallpaper-Settings.extension?showAsScreenSaver"),
        Entry(raw: "wallpaper-screensaver-as-wallpaper", title: "Show screen saver as wallpaper on main display", subtitle: "System Settings › Wallpaper", symbol: "photo.on.rectangle", target: "com.apple.Wallpaper-Settings.extension?showAsWallpaper"),
        Entry(raw: "wallpaper-as-screensaver", title: "Show wallpaper as screen saver on main display", subtitle: "System Settings › Wallpaper", symbol: "sparkles.tv", target: "com.apple.Wallpaper-Settings.extension?showAsScreenSaver"),
        Entry(raw: "desktop-click-wallpaper", title: "Click wallpaper to show desktop", subtitle: "System Settings › Desktop & Dock", symbol: "macwindow", target: "com.apple.Desktop-Settings.extension?Desktop"),
        Entry(raw: "dock-auto-hide", title: "Automatically hide and show the Dock", subtitle: "System Settings › Desktop & Dock", symbol: "dock.rectangle", target: "com.apple.Desktop-Settings.extension?Dock"),
        Entry(raw: "menu-bar-auto-hide", title: "Automatically hide and show the menu bar", subtitle: "System Settings › Control Center", symbol: "menubar.rectangle", target: "com.apple.ControlCenter-Settings.extension"),
        Entry(raw: "software-update-check", title: "Check for Software Updates", subtitle: "System Settings › General › Software Update", symbol: "arrow.triangle.2.circlepath", target: "com.apple.Software-Update-Settings.extension"),
        Entry(raw: "touch-id-watch-unlock", title: "Allow Apple Watch to unlock your Mac", subtitle: "System Settings › Touch ID & Password", symbol: "applewatch", target: "com.apple.Touch-ID-Settings.extension"),
        Entry(raw: "touch-id-change-password", title: "Change user session password", subtitle: "System Settings › Touch ID & Password", symbol: "key.fill", target: "com.apple.Touch-ID-Settings.extension"),
        Entry(raw: "passwords-cleanup-codes", title: "Clean up verification codes", subtitle: "System Settings › Passwords", symbol: "key", target: "com.apple.Passwords-Settings.extension"),
        Entry(raw: "appearance-accent-color", title: "Accent color", subtitle: "System Settings › Appearance", symbol: "paintbrush", target: "com.apple.Appearance-Settings.extension?Main"),
        Entry(raw: "appearance-liquid-glass", title: "Liquid Glass", subtitle: "System Settings › Appearance", symbol: "paintbrush", target: "com.apple.Appearance-Settings.extension?Main"),
    ]

    // MARK: - Intents Bundle Mapping

    static let intentsBundles: [IntentsBundleMetadata] = [
        IntentsBundleMetadata(bundleName: "AboutSettingsIntents.appex", paneID: "com.apple.SystemProfiler.AboutExtension", parentTitle: "General › About", symbol: "info.circle"),
        IntentsBundleMetadata(bundleName: "AccessibilitySettingsSearchExtension.appex", paneID: "com.apple.Accessibility-Settings.extension", parentTitle: "Accessibility", symbol: "figure.stand"),
        IntentsBundleMetadata(bundleName: "AccessibilitySettingsWidgetExtension.appex", paneID: "com.apple.Accessibility-Settings.extension", parentTitle: "Accessibility", symbol: "figure.stand"),
        IntentsBundleMetadata(bundleName: "AccountsUISettingsAppIntents.appex", paneID: "com.apple.Internet-Accounts-Settings.extension", parentTitle: "Internet Accounts", symbol: "at"),
        IntentsBundleMetadata(bundleName: "AirDropHandoffIntentsExtension.appex", paneID: "com.apple.AirDrop-Handoff-Settings.extension", parentTitle: "General › AirDrop & Handoff", symbol: "airplayvideo"),
        IntentsBundleMetadata(bundleName: "AppearanceIntentsExtension.appex", paneID: "com.apple.Appearance-Settings.extension", parentTitle: "Appearance", symbol: "paintbrush"),
        IntentsBundleMetadata(bundleName: "AppleAccountIntents_macOS.appex", paneID: "com.apple.systempreferences.AppleIDSettings", parentTitle: "Apple Account", symbol: "person.crop.circle"),
        IntentsBundleMetadata(bundleName: "BatterySettingsIntentsExtension.appex", paneID: "com.apple.Battery-Settings.extension", parentTitle: "Battery", symbol: "battery.100percent"),
        IntentsBundleMetadata(bundleName: "BiometricsAndPasswordSettingsAppIntentsExtension.appex", paneID: "com.apple.Touch-ID-Settings.extension", parentTitle: "Touch ID & Password", symbol: "touchid"),
        IntentsBundleMetadata(bundleName: "BluetoothSettingsAppIntentsWidgetExtension.appex", paneID: "com.apple.BluetoothSettings", parentTitle: "Bluetooth", symbol: "wave.3.right"),
        IntentsBundleMetadata(bundleName: "CDsAndDvDsSettingsIntents.appex", paneID: "com.apple.CD-DVD-Settings.extension", parentTitle: "CDs & DVDs", symbol: "opticaldisc"),
        IntentsBundleMetadata(bundleName: "ControlCenterSettingsIntents.appex", paneID: "com.apple.ControlCenter-Settings.extension", parentTitle: "Control Center", symbol: "switch.2"),
        IntentsBundleMetadata(bundleName: "DateTimeIntentsExtension.appex", paneID: "com.apple.Date-Time-Settings.extension", parentTitle: "General › Date & Time", symbol: "clock"),
        IntentsBundleMetadata(bundleName: "DesktopSettingsIntents.appex", paneID: "com.apple.Desktop-Settings.extension", parentTitle: "Desktop & Dock", symbol: "macwindow"),
        IntentsBundleMetadata(bundleName: "DisplaysSettingsIntentsExtension.appex", paneID: "com.apple.Displays-Settings.extension", parentTitle: "Displays", symbol: "display"),
        IntentsBundleMetadata(bundleName: "DoNotDisturbAppIntents.appex", paneID: "com.apple.Focus-Settings.extension", parentTitle: "Focus", symbol: "moon"),
        IntentsBundleMetadata(bundleName: "FamilyIntents.appex", paneID: "com.apple.Family-Settings.extension", parentTitle: "Family", symbol: "figure.2.and.child.holdinghands"),
        IntentsBundleMetadata(bundleName: "GameCenterSettingsDeviceExpertExtension.appex", paneID: "com.apple.Game-Center-Settings.extension", parentTitle: "Game Center", symbol: "gamecontroller"),
        IntentsBundleMetadata(bundleName: "GameCenterSettingsSearchExtension.appex", paneID: "com.apple.Game-Center-Settings.extension", parentTitle: "Game Center", symbol: "gamecontroller"),
        IntentsBundleMetadata(bundleName: "GameControllerSettingsIntents.appex", paneID: "com.apple.Game-Controller-Settings.extension", parentTitle: "Game Controllers", symbol: "gamecontroller.fill"),
        IntentsBundleMetadata(bundleName: "GenerativePartnerSettingsExtension.appex", paneID: "com.apple.Siri-Settings.extension", parentTitle: "Apple Intelligence & Siri", symbol: "sparkles"),
        IntentsBundleMetadata(bundleName: "InternationalSettingsExtension.appex", paneID: "com.apple.Localization-Settings.extension", parentTitle: "General › Language & Region", symbol: "globe"),
        IntentsBundleMetadata(bundleName: "KeyboardSettingsIntents.appex", paneID: "com.apple.Keyboard-Settings.extension", parentTitle: "Keyboard", symbol: "keyboard"),
        IntentsBundleMetadata(bundleName: "LockScreenIntentsExtension.appex", paneID: "com.apple.Lock-Screen-Settings.extension", parentTitle: "Lock Screen", symbol: "lock"),
        IntentsBundleMetadata(bundleName: "LoginItemsIntentsExtension.appex", paneID: "com.apple.LoginItems-Settings.extension", parentTitle: "General › Login Items & Extensions", symbol: "list.bullet.rectangle"),
        IntentsBundleMetadata(bundleName: "MouseIntentsExtension.appex", paneID: "com.apple.Mouse-Settings.extension", parentTitle: "Mouse", symbol: "computermouse"),
        IntentsBundleMetadata(bundleName: "NetworkSettingsIntents.appex", paneID: "com.apple.Network-Settings.extension", parentTitle: "Network", symbol: "network"),
        IntentsBundleMetadata(bundleName: "NewDeviceOutreachIntents_macOS.appex", paneID: "com.apple.Coverage-Settings.extension", parentTitle: "General › AppleCare & Warranty", symbol: "checkmark.shield"),
        IntentsBundleMetadata(bundleName: "NotificationsSettingsIntents.appex", paneID: "com.apple.Notifications-Settings.extension", parentTitle: "Notifications", symbol: "bell"),
        IntentsBundleMetadata(bundleName: "PasswordSettingsAppIntentsExtension.appex", paneID: "com.apple.Passwords-Settings.extension", parentTitle: "Passwords", symbol: "key"),
        IntentsBundleMetadata(bundleName: "PrinterScannerIntentsExtension.appex", paneID: "com.apple.Print-Scan-Settings.extension", parentTitle: "Printers & Scanners", symbol: "printer"),
        IntentsBundleMetadata(bundleName: "ProfilesSettingsIntents.appex", paneID: "com.apple.Profiles-Settings.extension", parentTitle: "General › Device Management", symbol: "gear.badge"),
        IntentsBundleMetadata(bundleName: "ScreenTimeAppIntentsExtension.appex", paneID: "com.apple.Screen-Time-Settings.extension", parentTitle: "Screen Time", symbol: "hourglass"),
        IntentsBundleMetadata(bundleName: "SecurityPrivacyIntentsExtension.appex", paneID: "com.apple.settings.PrivacySecurity.extension", parentTitle: "Privacy & Security", symbol: "hand.raised"),
        IntentsBundleMetadata(bundleName: "SharingIntents.appex", paneID: "com.apple.Sharing-Settings.extension", parentTitle: "General › Sharing", symbol: "square.and.arrow.up"),
        IntentsBundleMetadata(bundleName: "SiriSetupSettingsIntents.appex", paneID: "com.apple.Siri-Settings.extension", parentTitle: "Apple Intelligence & Siri", symbol: "sparkles"),
        IntentsBundleMetadata(bundleName: "SoftwareUpdateSettingsExtensionIntents.appex", paneID: "com.apple.Software-Update-Settings.extension", parentTitle: "General › Software Update", symbol: "arrow.triangle.2.circlepath"),
        IntentsBundleMetadata(bundleName: "SoundIntentsExtension.appex", paneID: "com.apple.Sound-Settings.extension", parentTitle: "Sound", symbol: "speaker.wave.2"),
        IntentsBundleMetadata(bundleName: "SpotlightSettingsIntentsExtension.appex", paneID: "com.apple.Spotlight-Settings.extension", parentTitle: "Spotlight", symbol: "magnifyingglass"),
        IntentsBundleMetadata(bundleName: "StartupDiskWidgetExtension.appex", paneID: "com.apple.Startup-Disk-Settings.extension", parentTitle: "General › Startup Disk", symbol: "internaldrive.fill"),
        IntentsBundleMetadata(bundleName: "StorageSettingsIntentsExtension.appex", paneID: "com.apple.settings.Storage", parentTitle: "General › Storage", symbol: "internaldrive"),
        IntentsBundleMetadata(bundleName: "TimeMachineSettingsIntents.appex", paneID: "com.apple.Time-Machine-Settings.extension", parentTitle: "General › Time Machine", symbol: "clock.arrow.circlepath"),
        IntentsBundleMetadata(bundleName: "TrackpadIntentsExtension.appex", paneID: "com.apple.Trackpad-Settings.extension", parentTitle: "Trackpad", symbol: "rectangle.and.hand.point.up.left"),
        IntentsBundleMetadata(bundleName: "TransferResetIntentsExtension.appex", paneID: "com.apple.Transfer-Reset-Settings.extension", parentTitle: "General › Transfer or Reset", symbol: "arrow.counterclockwise"),
        IntentsBundleMetadata(bundleName: "TransparencySettingsIntents.appex", paneID: "com.apple.systempreferences.AppleIDSettings", parentTitle: "Apple Account", symbol: "person.crop.circle"),
        IntentsBundleMetadata(bundleName: "UsersGroupsIntentsExtension.appex", paneID: "com.apple.Users-Groups-Settings.extension", parentTitle: "Users & Groups", symbol: "person.2"),
        IntentsBundleMetadata(bundleName: "VPNAppIntentWidgetExtension.appex", paneID: "com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension", parentTitle: "VPN", symbol: "network.badge.shield.half.filled"),
        IntentsBundleMetadata(bundleName: "VpnSettingsIntents.appex", paneID: "com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension", parentTitle: "VPN", symbol: "network.badge.shield.half.filled"),
        IntentsBundleMetadata(bundleName: "WallpaperSettingsIntents.appex", paneID: "com.apple.Wallpaper-Settings.extension", parentTitle: "Wallpaper", symbol: "photo.on.rectangle"),
        IntentsBundleMetadata(bundleName: "WiFiMacSettingsIntents.appex", paneID: "com.apple.wifi-settings-extension", parentTitle: "Wi-Fi", symbol: "wifi"),
    ]
}
