import RillDomain
import SwiftUI

struct AboutSettingsTab: View {
    @Bindable var viewModel: SettingsViewModel

    private static let repositoryURL = URL(string: "https://github.com/Udean777/Rill")

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                AppLogoView(size: 64, cornerRadius: 14)
                    .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 2)

                Text("Rill")
                    .font(.system(size: 18, weight: .bold))

                Text("Fast, native macOS launcher")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)

            SettingsCard(title: "Rill") {
                HStack {
                    Text("Version")
                        .font(.system(size: 13))
                    Spacer()
                    Text(appVersion)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                SettingsCardDivider()

                HStack {
                    Text("Build")
                        .font(.system(size: 13))
                    Spacer()
                    Text(appBuild)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                SettingsCardDivider()

                HStack {
                    Text("Bundle")
                        .font(.system(size: 13))
                    Spacer()
                    Text(Bundle.main.bundleIdentifier ?? "com.ssajudn.Rill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                SettingsCardDivider()

                UpdatesRow(viewModel: viewModel)
            }

            SettingsCard(title: "Source") {
                HStack {
                    Text("Repository")
                        .font(.system(size: 13))
                    Spacer()
                    if let repositoryURL = Self.repositoryURL {
                        Link("Open on GitHub", destination: repositoryURL)
                            .font(.system(size: 13))
                    }
                }
            }

            SettingsCard(title: "Open Source") {
                ForEach(Credits.all) { credit in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(credit.name)
                                .font(.system(size: 13))
                            Text(credit.detail)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 12)

                        if let websiteURL = URL(string: credit.website) {
                            Link("Website", destination: websiteURL)
                                .font(.system(size: 12))
                        }
                        if let githubURL = URL(string: credit.github) {
                            Link("GitHub", destination: githubURL)
                                .font(.system(size: 12))
                        }
                    }
                }
            }

            SettingsCard(title: "Permissions") {
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
                                viewModel.openAccessibilitySettings()
                            }
                        }
                    }
                }

                SettingsCardDivider()

                HStack {
                    Spacer()
                    Button("Refresh") {
                        viewModel.refreshStatus()
                    }
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

private struct UpdatesRow: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Updates")
                    .font(.system(size: 13))
                if let subtitle = statusSubtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            switch viewModel.updateState {
            case .checking:
                ProgressView()
                    .controlSize(.small)
            case .downloading(let progress):
                if let progress {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            case .installing:
                ProgressView()
                    .controlSize(.small)
            case .available:
                Button("Update Now") {
                    viewModel.installUpdate()
                }
            case .readyToQuit:
                Button("Restart Rill") {
                    viewModel.restartToUpdate()
                }
            case .idle, .upToDate, .failed:
                Button("Check for Updates") {
                    viewModel.checkForUpdates()
                }
            }
        }
    }

    private var statusSubtitle: String? {
        switch viewModel.updateState {
        case .idle:
            nil
        case .checking:
            String(localized: "Checking GitHub Releases…")
        case .upToDate:
            String(localized: "You’re up to date.")
        case .available(let version):
            String(localized: "Version \(version) is available.")
        case .downloading:
            String(localized: "Downloading update…")
        case .installing:
            String(localized: "Installing update…")
        case .readyToQuit(let version):
            String(localized: "Version \(version) installed. Restart to apply.")
        case .failed(let message):
            message
        }
    }
}

/// Third-party and framework credits shown in Settings → About.
private struct Credit: Identifiable {
    let name: String
    let detail: String
    let website: String
    let github: String

    var id: String { name }
}

private enum Credits {
    static let all: [Credit] = [
        Credit(
            name: "Swift, SwiftUI, Foundation",
            detail: String(localized: "Apple frameworks Rill is built on."),
            website: "https://developer.apple.com/swift",
            github: "https://github.com/swiftlang/swift"
        ),
        Credit(
            name: "Swift Testing",
            detail: String(localized: "Test framework for the test suite."),
            website: "https://swift.org/swift-testing",
            github: "https://github.com/swiftlang/swift-testing"
        ),
        Credit(
            name: "Frankfurter",
            detail: String(localized: "Exchange rates for currency conversion."),
            website: "https://frankfurter.dev",
            github: "https://github.com/lineofflight/frankfurter"
        ),
        Credit(
            name: "Raycast",
            detail: String(localized: "Prior art for the palette interaction model."),
            website: "https://raycast.com",
            github: "https://github.com/raycast"
        )
    ]
}
