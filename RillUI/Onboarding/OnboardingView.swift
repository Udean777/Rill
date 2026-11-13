import RillDomain
import SwiftUI

/// First-run welcome window (see design.md §5.6).
/// Designed with Things 3 spatial rhythm (8/16/24), single-accent focus,
/// and the hotkey recorder as the central hero element.
public struct OnboardingView: View {
    @Bindable public var viewModel: SettingsViewModel
    public let onFinish: () -> Void

    public init(viewModel: SettingsViewModel, onFinish: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onFinish = onFinish
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hotkeyHeroCard

                    permissionsCard

                    hintsSection
                }
                .padding(.vertical, 2)
            }

            footerSection
        }
        .padding(28)
        .frame(
            minWidth: 540,
            idealWidth: 580,
            maxWidth: .infinity,
            minHeight: 520,
            idealHeight: 600,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(spacing: 16) {
            AppLogoView(size: 48, cornerRadius: 11)
            .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to Rill")
                    .font(.system(size: 22, weight: .semibold))

                Text("Fast, keyboard-driven launcher for applications, files, and commands.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var hotkeyHeroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GLOBAL HOTKEY")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)

            HStack {
                Text("Press shortcut anywhere to invoke")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)

                Spacer()

                HotkeyRecorderView(
                    hotkey: Binding(
                        get: { viewModel.preferences.hotkey },
                        set: { viewModel.updateHotkey($0) }
                    )
                )
                .frame(width: 150, height: 30)
            }

            if let error = viewModel.hotkeyError {
                warning(error)
            } else if !viewModel.isHotkeyRegistered {
                warning(
                    String(
                        localized: "This shortcut is already used by another app. Record a different one."
                    )
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .quaternarySystemFill))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }

    private var permissionsCard: some View {
        SettingsCard(title: "Permissions") {
            PermissionsCardContent(viewModel: viewModel)
        }
    }

    private var hintsSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "keyboard")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Text("Type to search   ·   ↵ open   ·   esc close")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private var footerSection: some View {
        HStack(alignment: .center) {
            Text("Rill never steals focus from the app you are working in.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

            Button("Get Started") {
                onFinish()
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.regular)
        }
    }

    private func warning(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.red)
    }
}
