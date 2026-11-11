import AppKit
import os
import RillData
import RillDomain
import RillPlatform
import RillUI

/// The single composition root: constructs every concrete adapter once.
struct AppEnvironment {
    let paletteWindowController: PaletteWindowController
    let hotkeyManager: CarbonHotkeyManager

    static func live() -> AppEnvironment {
        let usageStore = JSONUsageStore()
        let clock = SystemClock()

        let searchUseCase = SearchUseCase(
            commands: CommandRegistry(),
            applications: ApplicationCatalog(),
            usage: usageStore,
            clock: clock
        )
        let executeUseCase = ExecuteResultUseCase(
            performer: SystemActionPerformer(),
            usage: usageStore,
            clock: clock
        )

        let viewModel = PaletteViewModel(searchUseCase: searchUseCase)
        let windowController = PaletteWindowController(viewModel: viewModel)
        let hotkeyManager = CarbonHotkeyManager { [weak windowController] in
            windowController?.toggle()
        }

        let log = Logger(subsystem: "com.ssajudn.Rill", category: "actions")
        viewModel.onExecute = { [weak windowController, weak viewModel] result in
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

        return AppEnvironment(
            paletteWindowController: windowController,
            hotkeyManager: hotkeyManager
        )
    }
}

private struct SystemClock: RillDomain.Clock {
    var now: Date { Date() }
}
