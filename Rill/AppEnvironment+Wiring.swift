import AppKit
import os
import RillData
import RillDomain
import RillPlatform
import RillUI

extension AppEnvironment {
    /// - Returns: `false` when the new shortcut is taken; the old one stays live.
    func updateHotkey(_ hotkey: Hotkey) async -> Bool {
        await replaceHotkey(hotkey, storingIn: \.currentHotkeyToken)
    }

    func updateClipboardHotkey(_ hotkey: Hotkey) async -> Bool {
        await replaceHotkey(
            hotkey,
            storingIn: \.currentClipboardHotkeyToken,
            onTrigger: { [weak paletteWindowController] in
                paletteWindowController?.toggleClipboardHistory()
            }
        )
    }

    private func replaceHotkey(
        _ hotkey: Hotkey,
        storingIn keyPath: ReferenceWritableKeyPath<AppEnvironment, HotkeyToken?>,
        onTrigger: (@MainActor () -> Void)? = nil
    ) async -> Bool {
        do {
            // Register first: a failed registration must not leave the user
            // without any hotkey.
            let token: HotkeyToken
            if let onTrigger {
                token = try await hotkeyManager.register(hotkey) {
                    onTrigger()
                }
            } else {
                token = try await hotkeyManager.register(hotkey)
            }
            if let previous = self[keyPath: keyPath] {
                await hotkeyManager.unregister(previous)
            }
            self[keyPath: keyPath] = token
            return true
        } catch {
            return false
        }
    }

    static func wirePaletteCallbacks(
        viewModel: PaletteViewModel,
        windowController: PaletteWindowController,
        settingsWindowController: SettingsWindowController,
        executeUseCase: ExecuteResultUseCase,
        usageStore: JSONUsageStore,
        clock: SystemClock
    ) {
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

            // Hide instantly, launch immediately, and defer query reset so
            // SwiftUI re-rendering does not compete with app activation.
            windowController?.hide(animated: false)
            Task {
                do {
                    try await executeUseCase(result)
                } catch {
                    log.error("action failed: \(String(describing: error), privacy: .public)")
                    NSSound.beep()
                }
            }
            Task { @MainActor in
                viewModel?.reset()
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
    }

    static func wireClipboardCallbacks(
        clipboardViewModel: ClipboardViewModel,
        windowController: PaletteWindowController,
        paletteViewModel: PaletteViewModel,
        clipboardStore: JSONClipboardStore,
        preferencesStore: UserDefaultsPreferencesStore,
        pasteClipboardUseCase: PasteClipboardItemUseCase,
        imagesDirectoryURL: URL
    ) {
        func performPaste(_ item: ClipboardItem, asPlainText: Bool, allowDirectPaste: Bool) {
            windowController.hide()
            paletteViewModel.reset()
            Task {
                let triggerDirectPaste: Bool
                if allowDirectPaste {
                    triggerDirectPaste = await preferencesStore.load().clipboardDirectPaste
                } else {
                    triggerDirectPaste = false
                }
                do {
                    try await pasteClipboardUseCase(
                        item: item,
                        asPlainText: asPlainText,
                        imageDirectory: imagesDirectoryURL,
                        triggerDirectPaste: triggerDirectPaste
                    )
                } catch {
                    NSSound.beep()
                }
            }
        }

        clipboardViewModel.onPaste = { item, asPlainText in
            performPaste(item, asPlainText: asPlainText, allowDirectPaste: true)
        }

        clipboardViewModel.onCopy = { item in
            performPaste(item, asPlainText: false, allowDirectPaste: false)
        }

        clipboardViewModel.onTogglePin = { item in
            Task { await clipboardStore.togglePin(id: item.id) }
        }

        clipboardViewModel.onDelete = { item in
            Task { await clipboardStore.delete(id: item.id) }
        }

        clipboardViewModel.onClearHistory = {
            Task { await clipboardStore.clearHistory(keepingPinned: true) }
        }

        clipboardViewModel.onExit = { [weak paletteViewModel] in
            paletteViewModel?.exitClipboardHistory()
        }
    }

    static func wireUpdateCallbacks(
        updateManager: UpdateManager,
        settingsViewModel: SettingsViewModel
    ) {
        updateManager.onStateChanged = { [weak settingsViewModel] newState in
            settingsViewModel?.updateState = newState
        }
        settingsViewModel.onCheckForUpdates = { [weak updateManager] in
            Task {
                await updateManager?.checkForUpdates(isUserInitiated: true)
            }
        }
        settingsViewModel.onInstallUpdate = { [weak updateManager] in
            updateManager?.downloadAndInstallUpdate()
        }
        settingsViewModel.onRestartToUpdate = { [weak updateManager] in
            updateManager?.quitAfterUpdate(relaunch: true)
        }
    }
}
