import RillDomain
import SwiftUI

struct SettingsCard<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: () -> Content

    var body: some View {
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
}

struct SettingsCardDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 0.5)
    }
}

/// A label with a trailing control: side by side when the row has room,
/// stacked when a narrow window would squeeze the text into a ragged column.
struct SettingsResponsiveRow<Content: View, Accessory: View>: View {
    @ViewBuilder let content: () -> Content
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                content()
                Spacer(minLength: 8)
                accessory()
            }

            VStack(alignment: .leading, spacing: 8) {
                content()
                accessory()
            }
        }
    }
}

struct AppLogoView: View {
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        Image("AppLogo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
    }
}

struct SettingsToggleRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    @Binding var isOn: Bool

    init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                Spacer()
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PermissionStatusRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let isGranted: Bool
    let actionTitle: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        SettingsResponsiveRow {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)

                    Text(isGranted ? String(localized: "Granted") : String(localized: "Not Granted"))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(isGranted ? Color.green : Color.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(
                            (isGranted ? Color.green : Color.orange).opacity(0.12),
                            in: Capsule()
                        )
                }

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } accessory: {
            Button(actionTitle, action: action)
                .controlSize(.small)
        }
    }
}

struct PermissionsCardContent: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                PermissionStatusRow(
                    title: "Full Disk Access",
                    subtitle: "Prevents Desktop, Downloads & Documents popups when previewing clipboard files.",
                    isGranted: viewModel.permissions.isFullDiskAccessGranted,
                    actionTitle: "Open Settings",
                    action: { viewModel.permissions.openFullDiskAccessSettings() }
                )

                if !viewModel.permissions.isFullDiskAccessGranted {
                    SettingsResponsiveRow {
                        Text("If Rill is not listed, click Reveal App and drag Rill.app into Full Disk Access.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } accessory: {
                        Button("Reveal App") {
                            viewModel.permissions.revealApplicationInFinder()
                        }
                        .controlSize(.mini)
                    }
                }
            }

            if !viewModel.permissions.isFullDiskAccessGranted {
                SettingsCardDivider()

                SettingsResponsiveRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Protected Folders")
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)
                        Text("Authorize Desktop, Downloads, and Documents upfront without Full Disk Access.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } accessory: {
                    Button(viewModel.permissions.isRequestingFolderAccess ? "Requesting…" : "Grant Folders") {
                        viewModel.permissions.requestProtectedFolderAccess()
                    }
                    .controlSize(.small)
                    .disabled(viewModel.permissions.isRequestingFolderAccess)
                }
            }

            SettingsCardDivider()

            PermissionStatusRow(
                title: "Accessibility",
                subtitle: "Enables direct ⌘V paste into the active application.",
                isGranted: viewModel.permissions.isAccessibilityGranted,
                actionTitle: "Open Settings",
                action: { viewModel.permissions.openAccessibilitySettings() }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.refreshStatusAndReapplyPreferences()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            viewModel.refreshStatusAndReapplyPreferences()
        }
    }
}
