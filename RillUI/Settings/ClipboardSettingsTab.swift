import RillDomain
import SwiftUI

struct ClipboardSettingsTab: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(spacing: 16) {
            SettingsCard(title: "Permissions") {
                PermissionsCardContent(viewModel: viewModel)
            }

            SettingsCard(title: "Recording") {
                SettingsToggleRow(
                    "Record clipboard history",
                    subtitle: "Capture copied text, code, colors, and images into Rill.",
                    isOn: viewModel.binding(for: \.clipboardHistoryEnabled)
                )

                SettingsCardDivider()

                SettingsToggleRow(
                    "Direct paste into active app",
                    subtitle: "Requires Accessibility permission. If disabled, Enter copies to clipboard.",
                    isOn: viewModel.binding(for: \.clipboardDirectPaste)
                )

                SettingsCardDivider()

                SettingsToggleRow(
                    "Store copied images",
                    subtitle: "Saves previews to disk under Application Support.",
                    isOn: viewModel.binding(for: \.clipboardSaveImages)
                )

                SettingsCardDivider()

                HStack {
                    Text("History retention limit")
                        .font(.system(size: 13))
                    Spacer()
                    Picker("", selection: viewModel.binding(for: \.clipboardHistoryLimit)) {
                        ForEach(Preferences.clipboardHistoryLimitChoices, id: \.self) { limit in
                            Text("\(limit) items").tag(limit)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 110)
                }
            }

            SettingsCard(title: "Shortcut") {
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

            SettingsCard(title: "Data Management") {
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
