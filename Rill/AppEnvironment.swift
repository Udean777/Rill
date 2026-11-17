import AppKit
import os
import RillData
import RillDomain
import RillPlatform
import RillUI

/// The single composition root: constructs every concrete adapter once.
@MainActor
final class AppEnvironment {
    let paletteWindowController: PaletteWindowController
    let applicationsWindowController: ApplicationsWindowController
    let settingsWindowController: SettingsWindowController
    let onboardingWindowController: OnboardingWindowController
    let hotkeyManager: CarbonHotkeyManager
    let preferencesStore: PreferencesStoring
    private let clipboardStore: JSONClipboardStore
    // Retained for its lifetime — deallocation stops recording usage.
    private let usageTracker: AppUsageTracker
    // Retained for its lifetime — deallocation stops observing pasteboard.
    private let clipboardWatcher: PasteboardWatcher
    // Retained for its lifetime — deallocation removes the status item from the bar.
    private let statusBarController: StatusBarController
    private let trackpadPinchMonitor: TrackpadPinchMonitor
    private let applicationCatalog: ApplicationCatalog
    private let systemSettingsCatalog: SystemSettingsCatalog
    private let settingsViewModel: SettingsViewModel
    private let updateManager: UpdateManager

    var currentHotkeyToken: HotkeyToken?
    var currentClipboardHotkeyToken: HotkeyToken?
    var currentApplicationsHotkeyToken: HotkeyToken?

    init(
        paletteWindowController: PaletteWindowController,
        applicationsWindowController: ApplicationsWindowController,
        settingsWindowController: SettingsWindowController,
        onboardingWindowController: OnboardingWindowController,
        hotkeyManager: CarbonHotkeyManager,
        preferencesStore: PreferencesStoring,
        clipboardStore: JSONClipboardStore,
        usageTracker: AppUsageTracker,
        clipboardWatcher: PasteboardWatcher,
        statusBarController: StatusBarController,
        trackpadPinchMonitor: TrackpadPinchMonitor,
        applicationCatalog: ApplicationCatalog,
        systemSettingsCatalog: SystemSettingsCatalog,
        settingsViewModel: SettingsViewModel,
        updateManager: UpdateManager
    ) {
        self.paletteWindowController = paletteWindowController
        self.applicationsWindowController = applicationsWindowController
        self.settingsWindowController = settingsWindowController
        self.onboardingWindowController = onboardingWindowController
        self.hotkeyManager = hotkeyManager
        self.preferencesStore = preferencesStore
        self.clipboardStore = clipboardStore
        self.usageTracker = usageTracker
        self.clipboardWatcher = clipboardWatcher
        self.statusBarController = statusBarController
        self.trackpadPinchMonitor = trackpadPinchMonitor
        self.applicationCatalog = applicationCatalog
        self.systemSettingsCatalog = systemSettingsCatalog
        self.settingsViewModel = settingsViewModel
        self.updateManager = updateManager
    }

    static func live() -> AppEnvironment {
        let usageStore = JSONUsageStore()
        let clipboardStore = JSONClipboardStore()
        let clock = SystemClock()
        let preferencesStore = UserDefaultsPreferencesStore()
        let launchAtLogin = LaunchAtLogin()
        let currencyRateFetcher = FrankfurterRateFetcher(clock: clock)
        let localeProvider = SystemLocaleProvider()
        let applicationCatalog = ApplicationCatalog()
        let systemSettingsCatalog = SystemSettingsCatalog()
        let applicationsLayoutStore = JSONApplicationsLayoutStore()

        let searchUseCase = makeSearchUseCase(
            preferencesStore: preferencesStore,
            applications: applicationCatalog,
            files: SpotlightFileSearch(),
            usage: usageStore,
            clock: clock,
            rates: currencyRateFetcher,
            locale: localeProvider,
            systemSettings: systemSettingsCatalog
        )
        let executeUseCase = ExecuteResultUseCase(
            performer: SystemActionPerformer(),
            usage: usageStore,
            clock: clock
        )

        let palette = makePalette(searchUseCase: searchUseCase)
        let paletteViewModel = palette.viewModel
        let paletteWindowController = palette.windowController

        let grid = makeApplicationsGrid(
            loadUseCase: makeLoadApplicationsGridUseCase(
                preferencesStore: preferencesStore,
                applications: applicationCatalog,
                layoutStore: applicationsLayoutStore
            ),
            layoutStore: applicationsLayoutStore
        )
        let gridViewModel = grid.viewModel
        let applicationsWindowController = grid.windowController

        let clipboard = makeClipboard(
            preferencesStore: preferencesStore,
            clipboardStore: clipboardStore,
            clock: clock
        )
        wireClipboardCallbacks(
            clipboardViewModel: clipboard.viewModel,
            windowController: paletteWindowController,
            paletteViewModel: paletteViewModel,
            clipboardStore: clipboardStore,
            preferencesStore: preferencesStore,
            pasteClipboardUseCase: clipboard.pasteClipboardUseCase,
            imagesDirectoryURL: clipboard.imagesDirectoryURL
        )
        paletteViewModel.clipboardViewModel = clipboard.viewModel

        let trackpadPinchMonitor = TrackpadPinchMonitor()
        let hotkeyManager = CarbonHotkeyManager { [weak paletteWindowController] in
            paletteWindowController?.toggle()
        }

        let settingsViewModel = SettingsViewModel(preferencesStore: preferencesStore)
        let settingsWindowController = SettingsWindowController(viewModel: settingsViewModel)

        let onboardingWindowController = OnboardingWindowController(
            viewModel: settingsViewModel,
            onCompletion: { showPalette in
                Task {
                    var prefs = await preferencesStore.load()
                    guard !prefs.hasCompletedOnboarding else { return }
                    prefs.hasCompletedOnboarding = true
                    await preferencesStore.save(prefs)
                }
                if showPalette {
                    paletteWindowController.show()
                }
            }
        )

        settingsViewModel.onShowWelcome = { [weak onboardingWindowController] in
            onboardingWindowController?.show()
        }

        // ⌘, from the palette (design.md §5.2).
        paletteWindowController.onOpenSettings = { [weak settingsWindowController] in
            settingsWindowController?.show()
        }
        paletteViewModel.onOpenSettings = { [weak settingsWindowController] in
            settingsWindowController?.show()
        }

        wirePaletteCallbacks(
            viewModel: paletteViewModel,
            windowController: paletteWindowController,
            applicationsWindowController: applicationsWindowController,
            settingsWindowController: settingsWindowController,
            executeUseCase: executeUseCase,
            usageStore: usageStore,
            clock: clock
        )
        wireApplicationsGridCallbacks(
            viewModel: gridViewModel,
            windowController: applicationsWindowController,
            executeUseCase: executeUseCase
        )

        let updateManager = UpdateManager(clock: clock)
        wireUpdateCallbacks(
            updateManager: updateManager,
            settingsViewModel: settingsViewModel
        )

        let env = AppEnvironment(
            paletteWindowController: paletteWindowController,
            applicationsWindowController: applicationsWindowController,
            settingsWindowController: settingsWindowController,
            onboardingWindowController: onboardingWindowController,
            hotkeyManager: hotkeyManager,
            preferencesStore: preferencesStore,
            clipboardStore: clipboardStore,
            usageTracker: AppUsageTracker(usage: usageStore, clock: clock),
            clipboardWatcher: clipboard.watcher,
            statusBarController: StatusBarController(
                onShowPalette: { paletteWindowController.show() },
                onOpenSettings: { settingsWindowController.show() },
                onCheckForUpdates: {
                    Task {
                        await updateManager.checkForUpdates(isUserInitiated: true)
                    }
                }
            ),
            trackpadPinchMonitor: trackpadPinchMonitor,
            applicationCatalog: applicationCatalog,
            systemSettingsCatalog: systemSettingsCatalog,
            settingsViewModel: settingsViewModel,
            updateManager: updateManager
        )
        env.configureSettings(
            settingsViewModel: settingsViewModel,
            paletteViewModel: paletteViewModel,
            clipboardViewModel: clipboard.viewModel,
            applicationsGridViewModel: gridViewModel,
            applicationsLayoutStore: applicationsLayoutStore,
            launchAtLogin: launchAtLogin,
            usageStore: usageStore,
            clipboardStore: clipboardStore
        )
        return env
    }

    func start() {
        usageTracker.start()
        clipboardWatcher.start()
        paletteWindowController.prewarm()
        applicationsWindowController.prewarm()

        Task {
            let prefs = await preferencesStore.load()
            apply(preferences: prefs)
            settingsViewModel.hotkeys.isPrimaryRegistered = await updateHotkey(prefs.hotkey)
            settingsViewModel.hotkeys.isClipboardRegistered = await updateClipboardHotkey(prefs.clipboardHotkey)
            if prefs.applicationsLauncherEnabled {
                settingsViewModel.hotkeys.isApplicationsRegistered = await updateApplicationsHotkey(
                    prefs.applicationsHotkey
                )
            }
            if !prefs.hasCompletedOnboarding {
                onboardingWindowController.show()
            }
        }

        // Prewarm catalogs and run a silent update check off the startup critical path.
        Task(priority: .utility) { [applicationCatalog, systemSettingsCatalog, weak updateManager] in
            _ = await applicationCatalog.applications()
            _ = await systemSettingsCatalog.settings()
            try? await Task.sleep(for: .seconds(5))
            await updateManager?.checkIfDue()
        }
    }

    /// Mirrors preferences that live outside the domain onto their owners.
    func apply(preferences: Preferences) {
        statusBarController.setEnabled(preferences.statusBarEnabled)
        paletteWindowController.apply(preferences: preferences)
        applicationsWindowController.apply(preferences: preferences)

        let historyLimit = preferences.clipboardHistoryLimit
        Task { await clipboardStore.setLimit(historyLimit) }

        let pinchAllowed = preferences.applicationsLauncherEnabled
            && preferences.applicationsPinchGestureEnabled
            && SystemActionPerformer.isSystemFourFingerPinchDisabled()
        if pinchAllowed {
            trackpadPinchMonitor.updateSensitivity(preferences.applicationsPinchSensitivity)
            trackpadPinchMonitor.start(sensitivity: preferences.applicationsPinchSensitivity) { [weak self] direction in
                guard let self else { return }
                switch direction {
                case .pinchIn:
                    self.paletteWindowController.hide(animated: false)
                    self.applicationsWindowController.show()
                case .pinchOut:
                    self.applicationsWindowController.hide()
                }
            }
        } else {
            trackpadPinchMonitor.stop()
        }

        Task {
            if preferences.applicationsLauncherEnabled {
                if currentApplicationsHotkeyToken == nil {
                    settingsViewModel.hotkeys.isApplicationsRegistered = await updateApplicationsHotkey(
                        preferences.applicationsHotkey
                    )
                }
            } else {
                await unregisterApplicationsHotkey()
                applicationsWindowController.hide(animated: false)
            }
        }
    }
}

struct SystemClock: RillDomain.Clock {
    var now: Date { Date() }
}
