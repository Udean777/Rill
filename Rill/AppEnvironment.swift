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

    private var currentHotkeyToken: HotkeyToken?
    private var currentClipboardHotkeyToken: HotkeyToken?

    init(
        paletteWindowController: PaletteWindowController,
        settingsWindowController: SettingsWindowController,
        onboardingWindowController: OnboardingWindowController,
        hotkeyManager: CarbonHotkeyManager,
        preferencesStore: PreferencesStoring,
        usageTracker: AppUsageTracker,
        clipboardWatcher: PasteboardWatcher,
        statusBarController: StatusBarController,
        settingsViewModel: SettingsViewModel
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
            locale: localeProvider
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

        let clipboardWatcher = PasteboardWatcher(
            imagesDirectoryURL: JSONClipboardStore.defaultImagesDirectoryURL(),
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
            imagesDirectoryURL: JSONClipboardStore.defaultImagesDirectoryURL()
        )

        clipboardViewModel.onPaste = { [weak windowController, weak viewModel] item, asPlainText in
            windowController?.hide()
            viewModel?.reset()
            Task {
                let prefs = await preferencesStore.load()
                do {
                    try await pasteClipboardUseCase(
                        item: item,
                        asPlainText: asPlainText,
                        imageDirectory: JSONClipboardStore.defaultImagesDirectoryURL(),
                        triggerDirectPaste: prefs.clipboardDirectPaste
                    )
                } catch {
                    NSSound.beep()
                }
            }
        }

        clipboardViewModel.onCopy = { [weak windowController, weak viewModel] item in
            windowController?.hide()
            viewModel?.reset()
            Task {
                do {
                    try await pasteClipboardUseCase(
                        item: item,
                        asPlainText: false,
                        imageDirectory: JSONClipboardStore.defaultImagesDirectoryURL(),
                        triggerDirectPaste: false
                    )
                } catch {
                    NSSound.beep()
                }
            }
        }

        clipboardViewModel.onTogglePin = { item in
            Task {
                await clipboardStore.togglePin(id: item.id)
            }
        }

        clipboardViewModel.onDelete = { item in
            Task {
                await clipboardStore.delete(id: item.id)
            }
        }

        clipboardViewModel.onClearHistory = {
            Task {
                await clipboardStore.clearHistory(keepingPinned: true)
            }
        }

        clipboardViewModel.onExit = { [weak viewModel] in
            viewModel?.exitClipboardHistory()
        }

        viewModel.clipboardViewModel = clipboardViewModel

        var environmentRef: AppEnvironment?

        let hotkeyManager = CarbonHotkeyManager { [weak windowController] in
            windowController?.toggle()
        }

        let settingsViewModel = SettingsViewModel(
            preferencesStore: preferencesStore,
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
                let url = JSONUsageStore.defaultFileURL()
                if FileManager.default.fileExists(atPath: url.path) {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } else {
                    NSWorkspace.shared.open(url.deletingLastPathComponent())
                }
            }
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

        let log = Logger(subsystem: "com.ssajudn.Rill", category: "actions")
        viewModel.onExecute = { [weak windowController, weak viewModel, weak settingsWindowController] result in
            if case .openSettings = result.primaryAction {
                windowController?.hide()
                viewModel?.reset()
                settingsWindowController?.show()
                return
            }

            if case .openClipboardHistory = result.primaryAction {
                viewModel?.openClipboardHistory()
                return
            }

            // Hide first, then act (design.md §4.6): the palette must not wait.
            windowController?.hide()
            viewModel?.reset()
            Task {
                do {
                    try await executeUseCase(result)
                } catch {
                    log.error("action failed: \(String(describing: error), privacy: .public)")
                    NSSound.beep()
                }
            }
        }

        viewModel.onTogglePin = { [weak viewModel] result in
            guard let viewModel else { return }
            let isPinned = result.section == .favorites
            Task {
                await usageStore.setPinned(result, isPinned: !isPinned, at: clock.now)
                viewModel.refresh()
            }
        }

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
                onOpenSettings: { settingsWindowController.show() }
            ),
            settingsViewModel: settingsViewModel
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
            settingsViewModel.isHotkeyRegistered = await registerHotkey(prefs.hotkey)
            settingsViewModel.isClipboardHotkeyRegistered = await registerClipboardHotkey(prefs.clipboardHotkey)
            if !prefs.hasCompletedOnboarding {
                onboardingWindowController.show()
            }
        }
    }

    /// Mirrors preferences that live outside the domain onto their owners.
    func apply(preferences: Preferences) {
        statusBarController.setEnabled(preferences.statusBarEnabled)
        paletteWindowController.apply(preferences: preferences)
    }

    /// - Returns: `false` when the new shortcut is taken; the old one stays live.
    func updateHotkey(_ hotkey: Hotkey) async -> Bool {
        do {
            // Register first: a failed registration must not leave the user
            // without any hotkey.
            let token = try await hotkeyManager.register(hotkey)
            if let currentHotkeyToken {
                await hotkeyManager.unregister(currentHotkeyToken)
            }
            currentHotkeyToken = token
            return true
        } catch {
            return false
        }
    }

    private func registerHotkey(_ hotkey: Hotkey) async -> Bool {
        do {
            let token = try await hotkeyManager.register(hotkey)
            self.currentHotkeyToken = token
            return true
        } catch {
            // CarbonHotkeyManager logged the failure
            return false
        }
    }

    func updateClipboardHotkey(_ hotkey: Hotkey) async -> Bool {
        do {
            let token = try await hotkeyManager.register(hotkey) { [weak paletteWindowController] in
                paletteWindowController?.toggleClipboardHistory()
            }
            if let currentClipboardHotkeyToken {
                await hotkeyManager.unregister(currentClipboardHotkeyToken)
            }
            currentClipboardHotkeyToken = token
            return true
        } catch {
            return false
        }
    }

    private func registerClipboardHotkey(_ hotkey: Hotkey) async -> Bool {
        do {
            let token = try await hotkeyManager.register(hotkey) { [weak paletteWindowController] in
                paletteWindowController?.toggleClipboardHistory()
            }
            self.currentClipboardHotkeyToken = token
            return true
        } catch {
            return false
        }
    }
}

private struct SystemClock: RillDomain.Clock {
    var now: Date { Date() }
}
