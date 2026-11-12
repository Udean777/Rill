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
    let hotkeyManager: CarbonHotkeyManager
    let preferencesStore: PreferencesStoring
    // Retained for its lifetime — deallocation removes the status item from the bar.
    private let statusBarController: StatusBarController

    private var currentHotkeyToken: HotkeyToken?

    init(
        paletteWindowController: PaletteWindowController,
        settingsWindowController: SettingsWindowController,
        hotkeyManager: CarbonHotkeyManager,
        preferencesStore: PreferencesStoring,
        statusBarController: StatusBarController
    ) {
        self.paletteWindowController = paletteWindowController
        self.settingsWindowController = settingsWindowController
        self.hotkeyManager = hotkeyManager
        self.preferencesStore = preferencesStore
        self.statusBarController = statusBarController
    }

    static func live() -> AppEnvironment {
        let usageStore = JSONUsageStore()
        let clock = SystemClock()
        let preferencesStore = UserDefaultsPreferencesStore()
        let fileSearch = SpotlightFileSearch()
        let launchAtLogin = LaunchAtLogin()

        let searchUseCase = SearchUseCase(
            commands: CommandRegistry(),
            applications: ApplicationCatalog(),
            files: fileSearch,
            usage: usageStore,
            clock: clock,
            isFilesEnabled: {
                let prefs = await preferencesStore.load()
                return prefs.fileSearchEnabled
            }
        )
        let executeUseCase = ExecuteResultUseCase(
            performer: SystemActionPerformer(),
            usage: usageStore,
            clock: clock
        )

        let viewModel = PaletteViewModel(searchUseCase: searchUseCase)
        let windowController = PaletteWindowController(viewModel: viewModel)

        var environmentRef: AppEnvironment?

        let hotkeyManager = CarbonHotkeyManager { [weak windowController] in
            windowController?.toggle()
        }

        let settingsViewModel = SettingsViewModel(
            preferencesStore: preferencesStore,
            onHotkeyChanged: { newHotkey in
                await environmentRef?.updateHotkey(newHotkey)
            },
            getLaunchAtLogin: {
                launchAtLogin.isEnabled
            },
            setLaunchAtLogin: { enabled in
                try launchAtLogin.setEnabled(enabled)
            },
            checkAccessibility: {
                AXIsProcessTrusted()
            }
        )

        let settingsWindowController = SettingsWindowController(viewModel: settingsViewModel)

        let log = Logger(subsystem: "com.ssajudn.Rill", category: "actions")
        viewModel.onExecute = { [weak windowController, weak viewModel, weak settingsWindowController] result in
            if result.id.raw == "rill.preferences" {
                windowController?.hide()
                viewModel?.reset()
                settingsWindowController?.show()
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

        let env = AppEnvironment(
            paletteWindowController: windowController,
            settingsWindowController: settingsWindowController,
            hotkeyManager: hotkeyManager,
            preferencesStore: preferencesStore,
            statusBarController: StatusBarController(
                onShowPalette: { windowController.show() },
                onOpenSettings: { settingsWindowController.show() }
            )
        )
        environmentRef = env
        return env
    }

    func start() {
        paletteWindowController.prewarm()

        Task {
            let prefs = await preferencesStore.load()
            await registerHotkey(prefs.hotkey)
        }
    }

    func updateHotkey(_ hotkey: Hotkey) async {
        if let currentHotkeyToken {
            await hotkeyManager.unregister(currentHotkeyToken)
            self.currentHotkeyToken = nil
        }
        await registerHotkey(hotkey)
    }

    private func registerHotkey(_ hotkey: Hotkey) async {
        do {
            let token = try await hotkeyManager.register(hotkey)
            self.currentHotkeyToken = token
        } catch {
            // CarbonHotkeyManager logged the failure
        }
    }
}

private struct SystemClock: RillDomain.Clock {
    var now: Date { Date() }
}
