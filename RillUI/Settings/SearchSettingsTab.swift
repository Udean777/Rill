import RillDomain
import SwiftUI
import UniformTypeIdentifiers

struct SearchSettingsTab: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var isPickingCustomFolder = false
    @State private var isPickingExcludedFolder = false

    /// Sections the Results card can switch off. Files, Currency, Calculator,
    /// and Web Search already have their own toggles.
    private static let configurableSections: [RillDomain.Section] = [
        .favorites, .suggestions, .applications, .commands, .systemSettings,
    ]

    var body: some View {
        VStack(spacing: 16) {
            SettingsCard(title: "Files") {
                SettingsToggleRow(
                    "Enable File Search",
                    isOn: viewModel.preferences.binding(for: \.fileSearchEnabled)
                )

                if viewModel.preferences.values.fileSearchEnabled {
                    SettingsCardDivider()

                    SettingsToggleRow(
                        "Show files",
                        isOn: viewModel.preferences.binding(for: \.fileSearchIncludeFiles)
                    )

                    SettingsCardDivider()

                    SettingsToggleRow(
                        "Show folders",
                        isOn: viewModel.preferences.binding(for: \.fileSearchIncludeFolders)
                    )

                    SettingsCardDivider()

                    SettingsToggleRow(
                        "Show hidden files",
                        subtitle: "Include dot-files and invisible system items.",
                        isOn: viewModel.preferences.binding(for: \.fileSearchIncludeHidden)
                    )

                    SettingsCardDivider()

                    HStack {
                        Text("Search scope")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: viewModel.preferences.binding(for: \.fileSearchScope)) {
                            Text("Home folder").tag(FileSearchScope.homeDirectory)
                            Text("Entire Mac").tag(FileSearchScope.computer)
                            Text("Custom folders").tag(FileSearchScope.custom)
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }

                    if viewModel.preferences.values.fileSearchScope == .custom {
                        FolderPathList(
                            paths: viewModel.preferences.values.fileSearchCustomPaths,
                            emptyLabel: String(localized: "No custom folders selected (defaults to Home folder)."),
                            addLabel: String(localized: "Add Folder…"),
                            onAdd: { isPickingCustomFolder = true },
                            onRemove: { viewModel.preferences.removeFileSearchCustomPath($0) }
                        )
                    }

                    SettingsCardDivider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Excluded folders")
                            .font(.system(size: 13))
                        FolderPathList(
                            paths: viewModel.preferences.values.fileSearchExcludedPaths,
                            emptyLabel: String(localized: "No excluded folders."),
                            addLabel: String(localized: "Exclude Folder…"),
                            onAdd: { isPickingExcludedFolder = true },
                            onRemove: { viewModel.preferences.removeFileSearchExcludedPath($0) }
                        )
                    }
                }
            }

            SettingsCard(title: "Currency") {
                SettingsToggleRow(
                    "Convert currency amounts",
                    subtitle: "Type $20, €50 or 20 USD to convert to your local currency. Rates come from Frankfurter and need a network connection.",
                    isOn: viewModel.preferences.binding(for: \.currencyConversionEnabled)
                )
            }

            SettingsCard(title: "Results") {
                ForEach(Array(Self.configurableSections.enumerated()), id: \.element) { index, section in
                    if index > 0 {
                        SettingsCardDivider()
                    }
                    SettingsToggleRow(
                        LocalizedStringKey(section.localizedTitle),
                        isOn: Binding(
                            get: { !viewModel.preferences.values.hiddenSections.contains(section) },
                            set: { viewModel.preferences.updateSectionVisibility(section, isVisible: $0) }
                        )
                    )
                }

                SettingsCardDivider()

                SettingsToggleRow(
                    "Calculator",
                    isOn: viewModel.preferences.binding(for: \.calculatorEnabled)
                )

                SettingsCardDivider()

                SettingsToggleRow(
                    "Web Search",
                    isOn: viewModel.preferences.binding(for: \.webSearchEnabled)
                )

                if viewModel.preferences.values.webSearchEnabled {
                    SettingsCardDivider()

                    HStack {
                        Text("Default browser")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: viewModel.preferences.binding(for: \.defaultBrowserBundleID)) {
                            Text("System Default").tag(Optional<String>.none)
                            ForEach(viewModel.permissions.availableBrowsers) { browser in
                                Text(browser.name).tag(browser.bundleID)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 180)
                    }
                }

                Text("Sections you switch off never appear in the palette, even on an empty search field.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            SettingsCard(title: "Palette") {
                HStack {
                    Text("Suggested apps window")
                        .font(.system(size: 13))
                    Spacer()
                    Picker("", selection: viewModel.preferences.binding(for: \.suggestionWindowDays)) {
                        ForEach(Preferences.suggestionWindowChoices, id: \.self) { days in
                            Text(String(localized: "\(days) days")).tag(days)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }

                SettingsCardDivider()

                HStack {
                    Text("Applications per page")
                        .font(.system(size: 13))
                    Spacer()
                    Picker("", selection: viewModel.preferences.binding(for: \.applicationsPerPage)) {
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
        .fileImporter(
            isPresented: $isPickingCustomFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                for url in urls {
                    viewModel.preferences.addFileSearchCustomPath(url.path)
                }
            }
        }
        .fileImporter(
            isPresented: $isPickingExcludedFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                for url in urls {
                    viewModel.preferences.addFileSearchExcludedPath(url.path)
                }
            }
        }
    }
}

private struct FolderPathList: View {
    let paths: [String]
    let emptyLabel: String
    let addLabel: String
    let onAdd: () -> Void
    let onRemove: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if paths.isEmpty {
                Text(emptyLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(paths, id: \.self) { path in
                    HStack(spacing: 6) {
                        Text(path)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button {
                            onRemove(path)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Button(addLabel, action: onAdd)
                .controlSize(.small)
        }
    }
}
