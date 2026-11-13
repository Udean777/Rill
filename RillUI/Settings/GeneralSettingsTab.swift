import RillDomain
import SwiftUI

struct GeneralSettingsTab: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(spacing: 16) {
            SettingsCard(title: "Activation") {
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

                SettingsCardDivider()

                SettingsToggleRow(
                    "Show menu bar icon",
                    subtitle: "The palette itself never appears in the Dock or ⌘Tab.",
                    isOn: viewModel.binding(for: \.statusBarEnabled)
                )

                SettingsCardDivider()

                VStack(alignment: .leading, spacing: 4) {
                    SettingsToggleRow(
                        "Launch at Login",
                        isOn: Binding(
                            get: { viewModel.isLaunchAtLoginEnabled },
                            set: { viewModel.toggleLaunchAtLogin($0) }
                        )
                    )
                    if let error = viewModel.launchAtLoginError {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }
            }

            SettingsCard(title: "Palette") {
                SettingsToggleRow(
                    "Show keyboard hints",
                    subtitle: "The shortcut reminder next to the command chips.",
                    isOn: viewModel.binding(for: \.showKeyboardHints)
                )
            }

            SettingsCard(title: "Reset") {
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
}
