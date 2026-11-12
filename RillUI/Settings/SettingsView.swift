import RillDomain
import SwiftUI

/// Settings configuration view (see design.md §5.5).
/// Styled after Raycast preferences and macOS System Settings inset grouped cards.
public struct SettingsView: View {
    @Bindable public var viewModel: SettingsViewModel
    @State private var selectedTab: SettingsTab = .general
    @State private var isConfirmingReset = false
    @State private var isConfirmingPinsClear = false

    private enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case search = "Search"
        case clipboard = "Clipboard"
        case data = "Data"
        case about = "About"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: "gearshape"
            case .search: "magnifyingglass"
            case .clipboard: "doc.on.clipboard"
            case .data: "externaldrive"
            case .about: "info.circle"
            }
        }
    }

    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 150)

            Rectangle()
                .fill(.primary.opacity(0.08))
                .frame(width: 0.5)

            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 560, height: 420)
        .task {
            await viewModel.load()
        }
        .confirmationDialog(
            "Reset usage history?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                viewModel.clearUsageHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Suggested apps, frecency ranking, and favorites are cleared. This cannot be undone.")
        }
        .confirmationDialog(
            "Clear pinned items?",
            isPresented: $isConfirmingPinsClear,
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) {
                viewModel.clearPinnedItems()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every favorite is unpinned. Usage history stays.")
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
                            .frame(width: 18)

                        Text(LocalizedStringKey(tab.rawValue))
                            .font(.system(size: 13, weight: selectedTab == tab ? .medium : .regular))
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor.opacity(0.14))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 14)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                switch selectedTab {
                case .general:
                    generalSection
                case .search:
                    searchSection
                case .clipboard:
                    clipboardSection
                case .data:
                    dataSection
                case .about:
                    aboutSection
                }
            }
            .padding(16)
        }
    }

    // MARK: - General Tab

    private var generalSection: some View {
        VStack(spacing: 16) {
            settingsCard(title: "Activation") {
                HStack {
                    Text("Global Hotkey")
                        .font(.system(size: 13))
                    Spacer()
                    HotkeyRecorderView(
                        hotkey: Binding(
                            get: { viewModel.preferences.hotkey },
                            set: { viewModel.updateHotkey($0) }
                        )
                    )
                    .frame(width: 140, height: 28)
                }

                if let error = viewModel.hotkeyError {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                } else if !viewModel.isHotkeyRegistered {
                    Text("This shortcut is already used by another app. Record a different one.")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }

                cardDivider

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Show menu bar icon")
                            .font(.system(size: 13))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { viewModel.preferences.statusBarEnabled },
                            set: { viewModel.updateStatusBarEnabled($0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                    Text("The palette itself never appears in the Dock or ⌘Tab.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                cardDivider

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Launch at Login")
                            .font(.system(size: 13))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { viewModel.isLaunchAtLoginEnabled },
                            set: { viewModel.toggleLaunchAtLogin($0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                    if let error = viewModel.launchAtLoginError {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }
            }

            settingsCard(title: "Palette") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Show keyboard hints")
                            .font(.system(size: 13))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { viewModel.preferences.showKeyboardHints },
                            set: { viewModel.updateShowKeyboardHints($0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                    Text("The shortcut reminder next to the command chips.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            settingsCard(title: "Reset") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Button("Reset to Defaults") {
                            viewModel.resetToDefaults()
                        }
                        Spacer()
                        Button("Show Welcome Window") {
                            viewModel.showWelcomeWindow()
                        }
                    }
                    Text("Reset restores the hotkey, menu bar icon, file search and layout. Favorites and usage history stay.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Search Tab

    private var searchSection: some View {
        VStack(spacing: 16) {
            settingsCard(title: "Files") {
                HStack {
                    Text("Enable File Search")
                        .font(.system(size: 13))
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { viewModel.preferences.fileSearchEnabled },
                        set: { viewModel.updateFileSearchEnabled($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                cardDivider

                HStack {
                    Text("Search scope")
                        .font(.system(size: 13))
                    Spacer()
                    Text("Home folder")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            settingsCard(title: "Palette") {
                HStack {
                    Text("Suggested apps window")
                        .font(.system(size: 13))
                    Spacer()
                    Picker("", selection: Binding(
                        get: { viewModel.preferences.suggestionWindowDays },
                        set: { viewModel.updateSuggestionWindowDays($0) }
                    )) {
                        ForEach(Preferences.suggestionWindowChoices, id: \.self) { days in
                            Text(String(localized: "\(days) days")).tag(days)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }

                cardDivider

                HStack {
                    Text("Applications per page")
                        .font(.system(size: 13))
                    Spacer()
                    Picker("", selection: Binding(
                        get: { viewModel.preferences.applicationsPerPage },
                        set: { viewModel.updateApplicationsPerPage($0) }
                    )) {
                        ForEach(Preferences.applicationsPerPageChoices, id: \.self) { count in
                            Text("\(count)").tag(count)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 80)
                }

                Text("Changes apply immediately; nothing needs a relaunch.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Clipboard Tab

    private var clipboardSection: some View {
        VStack(spacing: 16) {
            settingsCard(title: "Recording") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Record clipboard history")
                            .font(.system(size: 13))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { viewModel.preferences.clipboardHistoryEnabled },
                            set: { viewModel.updateClipboardHistoryEnabled($0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                    Text("Capture copied text, code, colors, and images into Rill.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                cardDivider

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Direct paste into active app")
                            .font(.system(size: 13))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { viewModel.preferences.clipboardDirectPaste },
                            set: { viewModel.updateClipboardDirectPaste($0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                    Text("Requires Accessibility permission. If disabled, Enter copies to clipboard.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                cardDivider

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Store copied images")
                            .font(.system(size: 13))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { viewModel.preferences.clipboardSaveImages },
                            set: { viewModel.updateClipboardSaveImages($0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                    Text("Saves previews to disk under Application Support.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                cardDivider

                HStack {
                    Text("History retention limit")
                        .font(.system(size: 13))
                    Spacer()
                    Picker("", selection: Binding(
                        get: { viewModel.preferences.clipboardHistoryLimit },
                        set: { viewModel.updateClipboardHistoryLimit($0) }
                    )) {
                        ForEach(Preferences.clipboardHistoryLimitChoices, id: \.self) { limit in
                            Text("\(limit) items").tag(limit)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 110)
                }
            }

            settingsCard(title: "Shortcut") {
                HStack {
                    Text("Open Clipboard History")
                        .font(.system(size: 13))
                    Spacer()
                    HotkeyRecorderView(
                        hotkey: Binding(
                            get: { viewModel.preferences.clipboardHotkey },
                            set: { newHotkey in
                                Task {
                                    await viewModel.updateClipboardHotkey(newHotkey)
                                }
                            }
                        )
                    )
                    .frame(width: 140, height: 28)
                }

                if let error = viewModel.clipboardHotkeyError {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                } else if !viewModel.isClipboardHotkeyRegistered {
                    Text("This shortcut is already used by another app. Record a different one.")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }

            settingsCard(title: "Data Management") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Clear Clipboard History")
                                .font(.system(size: 13))
                            Text("Deletes all unpinned clipboard items. Pinned items are kept.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Clear History") {
                            viewModel.clearClipboardHistoryAction()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Data Tab

    private var dataSection: some View {
        VStack(spacing: 16) {
            settingsCard(title: "Usage") {
                HStack {
                    Text("History")
                        .font(.system(size: 13))
                    Spacer()
                    Text("App opens and result executions")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                cardDivider

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Button("Reset Usage History") {
                            isConfirmingReset = true
                        }
                        Spacer()
                        Button("Reveal Data File") {
                            viewModel.revealUsageData()
                        }
                    }
                    Text("Resetting clears suggested apps, frecency ranking, and favorites.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            settingsCard(title: "Favorites") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Button("Clear Pinned Items") {
                            isConfirmingPinsClear = true
                        }
                        Spacer()
                    }
                    Text("Unpins everything. Frecency ranking and suggested apps are kept.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - About Tab

    private var aboutSection: some View {
        VStack(spacing: 16) {
            settingsCard(title: "Rill") {
                HStack {
                    Text("Version")
                        .font(.system(size: 13))
                    Spacer()
                    Text(appVersion)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                cardDivider

                HStack {
                    Text("Build")
                        .font(.system(size: 13))
                    Spacer()
                    Text(appBuild)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                cardDivider

                HStack {
                    Text("Bundle")
                        .font(.system(size: 13))
                    Spacer()
                    Text("com.ssajudn.Rill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            settingsCard(title: "Source") {
                HStack {
                    Text("Repository")
                        .font(.system(size: 13))
                    Spacer()
                    Button("Open on GitHub") {
                        openRepository()
                    }
                }
            }

            settingsCard(title: "Permissions") {
                HStack {
                    Text("Accessibility")
                        .font(.system(size: 13))
                    Spacer()
                    if viewModel.isAccessibilityGranted {
                        Text("Granted")
                            .font(.system(size: 13))
                            .foregroundStyle(.green)
                    } else {
                        HStack(spacing: 8) {
                            Text("Not Granted")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Button("Open System Settings") {
                                openAccessibilitySettings()
                            }
                        }
                    }
                }

                cardDivider

                HStack {
                    Spacer()
                    Button("Refresh") {
                        viewModel.refreshStatus()
                    }
                }
            }
        }
    }

    // MARK: - Card Component Helpers

    private func settingsCard<Content: View>(
        title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .quaternarySystemFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
        }
    }

    private var cardDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 0.5)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private func openRepository() {
        if let url = URL(string: "https://github.com/Udean777/Rill") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
