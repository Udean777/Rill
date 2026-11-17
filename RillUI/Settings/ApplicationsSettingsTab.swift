import RillDomain
import SwiftUI

struct ApplicationsSettingsTab: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var isConfirmingReset = false

    var body: some View {
        VStack(spacing: 16) {
            SettingsCard(title: "Applications Grid") {
                SettingsToggleRow(
                    "Enable Applications Grid",
                    subtitle: "Floating Launchpad-style overlay with custom order, folders, and hidden apps.",
                    isOn: viewModel.preferences.binding(for: \.applicationsLauncherEnabled)
                )

                if viewModel.preferences.values.applicationsLauncherEnabled {
                    SettingsCardDivider()

                    SettingsResponsiveRow {
                        Text("Global Hotkey")
                            .font(.system(size: 13))
                    } accessory: {
                        HotkeyRecorderView(
                            hotkey: Binding(
                                get: { viewModel.preferences.values.applicationsHotkey },
                                set: { newHotkey in
                                    Task { await viewModel.hotkeys.updateApplications(newHotkey) }
                                }
                            )
                        )
                        .frame(width: 140, height: 28)
                    }

                    if let error = viewModel.hotkeys.applicationsError {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    } else if !viewModel.hotkeys.isApplicationsRegistered {
                        Text("This shortcut is already used by another app.")
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }
            }

            if viewModel.preferences.values.applicationsLauncherEnabled {
                SettingsCard(title: "Trackpad Gesture") {
                    SettingsToggleRow(
                        "4-finger pinch gesture",
                        subtitle: "Pinch in with 4 fingers to open, pinch out to close.",
                        isOn: viewModel.preferences.binding(for: \.applicationsPinchGestureEnabled)
                    )

                    if viewModel.preferences.values.applicationsPinchGestureEnabled {
                        SettingsCardDivider()

                        trackpadSystemStatusGuide

                        if viewModel.permissions.isSystemFourFingerPinchDisabled {
                            SettingsCardDivider()

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Pinch sensitivity")
                                        .font(.system(size: 13))
                                    Spacer()
                                    Text(sensitivityLabel)
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(.secondary)
                                }
                                Slider(
                                    value: viewModel.preferences.binding(for: \.applicationsPinchSensitivity),
                                    in: 0.10...0.45,
                                    step: 0.03
                                )
                            }
                        }
                    }
                }

                SettingsCard(title: "Grid Layout") {
                    HStack {
                        Text("Columns")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: viewModel.preferences.binding(for: \.applicationsGridColumns)) {
                            ForEach(Preferences.applicationsGridColumnChoices, id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 80)
                    }

                    SettingsCardDivider()

                    HStack {
                        Text("Rows per page")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: viewModel.preferences.binding(for: \.applicationsGridRows)) {
                            ForEach(Preferences.applicationsGridRowChoices, id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 80)
                    }

                    SettingsCardDivider()

                    SettingsResponsiveRow {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Custom layout & folders")
                                .font(.system(size: 13))
                            Text("Restore default alphabetical order, remove folders, and unhide all apps.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } accessory: {
                        Button("Reset Layout", role: .destructive) {
                            isConfirmingReset = true
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
        .confirmationDialog(
            "Reset Applications Layout?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset Layout", role: .destructive) {
                viewModel.resetApplicationsLayoutAction()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All folders, custom items, hidden apps, and custom ordering will be cleared.")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.refreshStatusAndReapplyPreferences()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            viewModel.refreshStatusAndReapplyPreferences()
        }
    }

    private var trackpadSystemStatusGuide: some View {
        let isReady = viewModel.permissions.isSystemFourFingerPinchDisabled
        return VStack(alignment: .leading, spacing: 8) {
            SettingsResponsiveRow {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("macOS Launchpad Gesture")
                            .font(.system(size: 13))
                        Text(isReady ? String(localized: "Ready") : String(localized: "Action Required"))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(isReady ? Color.green : Color.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(
                                (isReady ? Color.green : Color.orange).opacity(0.12),
                                in: Capsule()
                            )
                    }
                    Text(
                        isReady
                            ? String(localized: "System Launchpad pinch is disabled. Rill's 4-finger pinch is active.")
                            : String(localized: "4-finger pinch stays inactive until the built-in macOS Launchpad gesture is turned off.")
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            } accessory: {
                Button("Open Trackpad Settings…") {
                    viewModel.permissions.openTrackpadMoreGesturesSettings()
                }
                .controlSize(.small)
            }

            if !isReady {
                VStack(alignment: .leading, spacing: 3) {
                    Text("1. Click Open Trackpad Settings… above.")
                    Text("2. Select the More Gestures tab.")
                    Text("3. Turn off Apps / Launchpad (pinch with thumb and three fingers).")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)
            }
        }
    }

    private var sensitivityLabel: String {
        let value = viewModel.preferences.values.applicationsPinchSensitivity
        if value <= 0.16 { return String(localized: "High") }
        if value <= 0.28 { return String(localized: "Medium") }
        return String(localized: "Low")
    }
}
