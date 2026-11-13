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
    let settingsWindowController: SettingsWindowController
    let onboardingWindowController: OnboardingWindowController
    let hotkeyManager: CarbonHotkeyManager
    let preferencesStore: PreferencesStoring
    // Retained for its lifetime — deallocation stops recording usage.
    private let usageTracker: AppUsageTracker
    // Retained for its lifetime — deallocation stops observing pasteboard.
    private let clipboardWatcher: PasteboardWatcher
    // Retained for its lifetime — deallocation removes the status item from the bar.
    private let statusBarController: StatusBarController
    private let settingsViewModel: SettingsViewModel
    private let updateManager: UpdateManager

    var currentHotkeyToken: HotkeyToken?
    var currentClipboardHotkeyToken: HotkeyToken?

    init(
        paletteWindowController: PaletteWindowController,
        settingsWindowController: SettingsWindowController,
        onboardingWindowController: OnboardingWindowController,
        hotkeyManager: CarbonHotkeyManager,
        preferencesStore: PreferencesStoring,
        usageTracker: AppUsageTracker,
        clipboardWatcher: PasteboardWatcher,
        statusBarController: StatusBarController,
        settingsViewModel: SettingsViewModel,
        updateManager: UpdateManager
    ) {
        self.paletteWindowController = paletteWindowController
        self.settingsWindowController = settingsWindowController
        self.onboardingWindowController = onboardingWindowController
        self.hotkeyManager = hotkeyManager
        self.preferencesStore = preferencesStore
        self.usageTracker = usageTracker
        self.clipboardWatcher = clipboardWatcher
        self.statusBarController = statusBarController
        self.settingsViewModel = settingsViewModel
        self.updateManager = updateManager
    }

    static func live() -> AppEnvironment {
        let usageStore = JSONUsageStore()
        let clipboardStore = JSONClipboardStore()
        let clock = SystemClock()
        let preferencesStore = UserDefaultsPreferencesStore()
        let fileSearch = SpotlightFileSearch()
        let launchAtLogin = LaunchAtLogin()
        let currencyRateFetcher = FrankfurterRateFetcher(clock: clock)
        let localeProvider = SystemLocaleProvider()

        let searchUseCase = SearchUseCase(
            commands: CommandRegistry(),
            applications: ApplicationCatalog(),
            files: fileSearch,
            usage: usageStore,
            clock: clock,
            preferences: {
                await preferencesStore.load()
            },
            currencyRates: currencyRateFetcher,
            locale: localeProvider,
            systemSettings: SystemSettingsCatalog()
        )
        let executeUseCase = ExecuteResultUseCase(
            performer: SystemActionPerformer(),
            usage: usageStore,
            clock: clock
        )

        let searchClipboardUseCase = SearchClipboardUseCase(store: clipboardStore)
        let recordClipboardUseCase = RecordClipboardItemUseCase(store: clipboardStore)
        let pasteboardWriter = SystemPasteboardWriter()
        let directPaster = AccessibilityDirectPaster()
        let pasteClipboardUseCase = PasteClipboardItemUseCase(
            writer: pasteboardWriter,
            directPaster: directPaster
        )

        let imagesDirectoryURL = JSONClipboardStore.defaultImagesDirectoryURL()
        let clipboardWatcher = PasteboardWatcher(
            imagesDirectoryURL: imagesDirectoryURL,
            clock: clock,
            onItemCopied: { raw in
                let prefs = await preferencesStore.load()
                guard prefs.clipboardHistoryEnabled else { return }
                if raw.imageFileName != nil && !prefs.clipboardSaveImages {
                    return
                }
                await recordClipboardUseCase(raw)
            }
        )
        pasteboardWriter.onWillWrite = { [weak clipboardWatcher] count in
            clipboardWatcher?.ignoreNextChange(count: count)
        }

        let viewModel = PaletteViewModel(searchUseCase: searchUseCase)
        let windowController = PaletteWindowController(viewModel: viewModel)

        let clipboardViewModel = ClipboardViewModel(
            searchUseCase: searchClipboardUseCase,
            imagesDirectoryURL: imagesDirectoryURL
        )

        wireClipboardCallbacks(
            clipboardViewModel: clipboardViewModel,
            windowController: windowController,
            paletteViewModel: viewModel,
            clipboardStore: clipboardStore,
            preferencesStore: preferencesStore,
            pasteClipboardUseCase: pasteClipboardUseCase,
            imagesDirectoryURL: imagesDirectoryURL
        )

        viewModel.clipboardViewModel = clipboardViewModel

        var environmentRef: AppEnvironment?

        let hotkeyManager = CarbonHotkeyManager { [weak windowController] in
            windowController?.toggle()
        }

        let settingsActions = SettingsActions(
            onHotkeyChanged: { newHotkey in
                await environmentRef?.updateHotkey(newHotkey) ?? false
            },
            onClipboardHotkeyChanged: { newHotkey in
                await environmentRef?.updateClipboardHotkey(newHotkey) ?? false
            },
            onPreferencesChanged: { preferences in
                environmentRef?.apply(preferences: preferences)
            },
            getLaunchAtLogin: {
                launchAtLogin.isEnabled
            },
            setLaunchAtLogin: { enabled in
                try launchAtLogin.setEnabled(enabled)
            },
            checkAccessibility: {
                AXIsProcessTrusted()
            },
            resetUsage: {
                await usageStore.reset()
                viewModel.updateQuery(viewModel.query)
            },
            clearPins: {
                await usageStore.clearPins()
                viewModel.updateQuery(viewModel.query)
            },
            clearClipboardHistory: {
                await clipboardStore.clearHistory(keepingPinned: true)
                clipboardViewModel.refresh()
            },
            revealUsageFile: {
                SystemActionPerformer.revealInFinder(JSONUsageStore.defaultFileURL())
            },
            openAccessibilitySettings: {
                await SystemActionPerformer.openAccessibilitySettings()
            },
            checkFullDiskAccess: {
                SystemActionPerformer.hasFullDiskAccess()
            },
            openFullDiskAccessSettings: {
                await SystemActionPerformer.openFullDiskAccessSettings()
            },
            requestProtectedFolderAccess: {
                await SystemActionPerformer.requestProtectedFolderAccess()
            },
            revealApplicationInFinder: {
                SystemActionPerformer.revealApplicationInFinder()
            }
        )
        let settingsViewModel = SettingsViewModel(
            preferencesStore: preferencesStore,
            actions: settingsActions
        )

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
                    windowController.show()
                }
            }
        )

        settingsViewModel.onShowWelcome = { [weak onboardingWindowController] in
            onboardingWindowController?.show()
        }

        // ⌘, from the palette (design.md §5.2).
        windowController.onOpenSettings = { [weak settingsWindowController] in
            settingsWindowController?.show()
        }
        viewModel.onOpenSettings = { [weak settingsWindowController] in
            settingsWindowController?.show()
        }

        wirePaletteCallbacks(
            viewModel: viewModel,
            windowController: windowController,
            settingsWindowController: settingsWindowController,
            executeUseCase: executeUseCase,
            usageStore: usageStore,
            clock: clock
        )

        let updateManager = UpdateManager(clock: clock)
        wireUpdateCallbacks(
            updateManager: updateManager,
            settingsViewModel: settingsViewModel
        )

        let env = AppEnvironment(
            paletteWindowController: windowController,
            settingsWindowController: settingsWindowController,
            onboardingWindowController: onboardingWindowController,
            hotkeyManager: hotkeyManager,
            preferencesStore: preferencesStore,
            usageTracker: AppUsageTracker(usage: usageStore, clock: clock),
            clipboardWatcher: clipboardWatcher,
            statusBarController: StatusBarController(
                onShowPalette: { windowController.show() },
                onOpenSettings: { settingsWindowController.show() },
                onCheckForUpdates: {
                    Task {
                        await updateManager.checkForUpdates(isUserInitiated: true)
                    }
                }
            ),
            settingsViewModel: settingsViewModel,
            updateManager: updateManager
        )
        environmentRef = env
        return env
    }

    func start() {
        usageTracker.start()
        clipboardWatcher.start()
        paletteWindowController.prewarm()

        Task {
            let prefs = await preferencesStore.load()
            apply(preferences: prefs)
            settingsViewModel.isHotkeyRegistered = await updateHotkey(prefs.hotkey)
            settingsViewModel.isClipboardHotkeyRegistered = await updateClipboardHotkey(prefs.clipboardHotkey)
            if !prefs.hasCompletedOnboarding {
                onboardingWindowController.show()
            }
        }

        // Run a silent update check off the startup critical path (throttled to 24h).
        Task(priority: .utility) { [weak updateManager] in
            try? await Task.sleep(for: .seconds(5))
            await updateManager?.checkIfDue()
        }
    }

    /// Mirrors preferences that live outside the domain onto their owners.
    func apply(preferences: Preferences) {
        statusBarController.setEnabled(preferences.statusBarEnabled)
        paletteWindowController.apply(preferences: preferences)
    }
}

struct SystemClock: RillDomain.Clock {
    var now: Date { Date() }
}
