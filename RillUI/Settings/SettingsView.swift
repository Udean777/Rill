import SwiftUI
import RillDomain

/// Settings configuration view (see design.md §5.5).
public struct SettingsView: View {
    @Bindable public var viewModel: SettingsViewModel

    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section("General") {
                HStack {
                    Text("Global Hotkey")
                    Spacer()
                    HotkeyRecorderView(
                        hotkey: Binding(
                            get: { viewModel.preferences.hotkey },
                            set: { viewModel.updateHotkey($0) }
                        )
                    )
                    .frame(width: 140, height: 28)
                }

                Toggle("Enable File Search", isOn: Binding(
                    get: { viewModel.preferences.fileSearchEnabled },
                    set: { viewModel.updateFileSearchEnabled($0) }
                ))

                Toggle("Launch at Login", isOn: Binding(
                    get: { viewModel.isLaunchAtLoginEnabled },
                    set: { viewModel.toggleLaunchAtLogin($0) }
                ))

                if let error = viewModel.launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Permissions") {
                HStack {
                    Text("Accessibility")
                    Spacer()
                    if viewModel.isAccessibilityGranted {
                        Text("Granted")
                            .foregroundStyle(.green)
                    } else {
                        HStack {
                            Text("Not Granted")
                                .foregroundStyle(.secondary)
                            Button("Open Settings") {
                                openAccessibilitySettings()
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 250)
        .task {
            await viewModel.load()
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
