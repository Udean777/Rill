import AppKit
import RillData
import RillDomain
import RillPlatform
import RillUI

extension AppEnvironment {
    static func makeSearchUseCase(
        preferencesStore: PreferencesStoring,
        applications: ApplicationCataloguing,
        files: FileSearching,
        usage: UsageStoring,
        clock: Clock,
        rates: CurrencyRateFetching,
        locale: LocaleProviding,
        systemSettings: SystemSettingsProviding
    ) -> SearchUseCase {
        SearchUseCase(
            commands: CommandRegistry(),
            applications: applications,
            files: files,
            usage: usage,
            clock: clock,
            preferences: {
                await preferencesStore.load()
            },
            currencyRates: rates,
            locale: locale,
            systemSettings: systemSettings
        )
    }

    static func makeLoadApplicationsGridUseCase(
        preferencesStore: PreferencesStoring,
        applications: ApplicationCataloguing,
        layoutStore: ApplicationsLayoutStoring
    ) -> LoadApplicationsGridUseCase {
        LoadApplicationsGridUseCase(
            applications: applications,
            layoutStore: layoutStore,
            preferences: {
                await preferencesStore.load()
            }
        )
    }

    static func makePalette(
        searchUseCase: SearchUseCase
    ) -> (viewModel: PaletteViewModel, windowController: PaletteWindowController) {
        let viewModel = PaletteViewModel(searchUseCase: searchUseCase)
        return (viewModel, PaletteWindowController(viewModel: viewModel))
    }

    static func makeApplicationsGrid(
        loadUseCase: LoadApplicationsGridUseCase,
        layoutStore: ApplicationsLayoutStoring
    ) -> (viewModel: ApplicationsGridViewModel, windowController: ApplicationsWindowController) {
        let viewModel = ApplicationsGridViewModel(
            loadUseCase: loadUseCase,
            layoutStore: layoutStore
        )
        return (viewModel, ApplicationsWindowController(viewModel: viewModel))
    }

    struct ClipboardComponents {
        let viewModel: ClipboardViewModel
        let watcher: PasteboardWatcher
        let imagesDirectoryURL: URL
        let pasteClipboardUseCase: PasteClipboardItemUseCase
    }

    static func makeClipboard(
        preferencesStore: PreferencesStoring,
        clipboardStore: JSONClipboardStore,
        clock: Clock
    ) -> ClipboardComponents {
        let searchUseCase = SearchClipboardUseCase(store: clipboardStore)
        let recordUseCase = RecordClipboardItemUseCase(store: clipboardStore)
        let pasteboardWriter = SystemPasteboardWriter()
        let pasteClipboardUseCase = PasteClipboardItemUseCase(
            writer: pasteboardWriter,
            directPaster: AccessibilityDirectPaster()
        )

        let imagesDirectoryURL = JSONClipboardStore.defaultImagesDirectoryURL()
        let watcher = PasteboardWatcher(
            imagesDirectoryURL: imagesDirectoryURL,
            clock: clock,
            onItemCopied: { raw in
                let prefs = await preferencesStore.load()
                guard prefs.clipboardHistoryEnabled else { return }
                if raw.imageFileName != nil && !prefs.clipboardSaveImages {
                    return
                }
                await recordUseCase(raw)
            }
        )
        pasteboardWriter.onWillWrite = { [weak watcher] count in
            watcher?.ignoreNextChange(count: count)
        }

        let viewModel = ClipboardViewModel(
            searchUseCase: searchUseCase,
            imagesDirectoryURL: imagesDirectoryURL
        )
        return ClipboardComponents(
            viewModel: viewModel,
            watcher: watcher,
            imagesDirectoryURL: imagesDirectoryURL,
            pasteClipboardUseCase: pasteClipboardUseCase
        )
    }

    /// Wires the Settings callbacks after construction, so they can hold the
    /// environment weakly instead of through a mutable reference.
    func configureSettings(
        settingsViewModel: SettingsViewModel,
        paletteViewModel: PaletteViewModel,
        clipboardViewModel: ClipboardViewModel,
        applicationsGridViewModel: ApplicationsGridViewModel,
        applicationsLayoutStore: JSONApplicationsLayoutStore,
        launchAtLogin: LaunchAtLogin,
        usageStore: JSONUsageStore,
        clipboardStore: JSONClipboardStore
    ) {
        settingsViewModel.configure(
            preferencesActions: SettingsPreferencesActions(
                onHotkeyChanged: { [weak self] newHotkey in
                    await self?.updateHotkey(newHotkey) ?? false
                },
                onClipboardHotkeyChanged: { [weak self] newHotkey in
                    await self?.updateClipboardHotkey(newHotkey) ?? false
                },
                onApplicationsHotkeyChanged: { [weak self] newHotkey in
                    await self?.updateApplicationsHotkey(newHotkey) ?? false
                },
                onPreferencesChanged: { [weak self] preferences in
                    self?.apply(preferences: preferences)
                }
            ),
            permissionsActions: SettingsPermissionsActions(
                getLaunchAtLogin: {
                    launchAtLogin.isEnabled
                },
                setLaunchAtLogin: { enabled in
                    try launchAtLogin.setEnabled(enabled)
                },
                checkAccessibility: {
                    AXIsProcessTrusted()
                },
                checkFullDiskAccess: {
                    SystemActionPerformer.hasFullDiskAccess()
                },
                openAccessibilitySettings: {
                    await SystemActionPerformer.openAccessibilitySettings()
                },
                openFullDiskAccessSettings: {
                    await SystemActionPerformer.openFullDiskAccessSettings()
                },
                requestProtectedFolderAccess: {
                    await SystemActionPerformer.requestProtectedFolderAccess()
                },
                revealApplicationInFinder: {
                    SystemActionPerformer.revealApplicationInFinder()
                },
                getInstalledBrowsers: {
                    SystemActionPerformer.installedBrowsers()
                },
                openTrackpadSettings: {
                    SystemActionPerformer.openTrackpadMoreGesturesSettings()
                },
                checkSystemFourFingerPinchDisabled: {
                    SystemActionPerformer.isSystemFourFingerPinchDisabled()
                }
            ),
            dataActions: SettingsDataActions(
                resetUsage: {
                    await usageStore.reset()
                    paletteViewModel.updateQuery(paletteViewModel.query)
                },
                clearPins: {
                    await usageStore.clearPins()
                    paletteViewModel.updateQuery(paletteViewModel.query)
                },
                clearClipboardHistory: {
                    await clipboardStore.clearHistory(keepingPinned: true)
                    clipboardViewModel.refresh()
                },
                revealUsageFile: {
                    SystemActionPerformer.revealInFinder(JSONUsageStore.defaultFileURL())
                },
                resetApplicationsLayout: {
                    await applicationsLayoutStore.reset()
                    await applicationsGridViewModel.reload()
                }
            )
        )
    }
}
