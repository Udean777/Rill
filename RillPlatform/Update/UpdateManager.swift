import AppKit
import Foundation
import os
import RillDomain

/// Coordinates GitHub Releases version checking, DMG downloading, and in-place installation.
@MainActor
public final class UpdateManager {
    private static let lastCheckKey = "Rill.Update.LastCheckTimestamp"
    private static let automaticCheckInterval: TimeInterval = 24 * 60 * 60

    public var state: UpdateState = .idle {
        didSet {
            onStateChanged?(state)
        }
    }
    public var isChecking = false
    public var isDownloading = false
    public var hasUpdate = false
    public var latestVersion = ""
    public var releaseNotesURL: URL?
    public var dmgDownloadURL: URL?
    public var downloadProgress: Double?
    public var lastCheckedDate: Date?

    public var onStateChanged: ((UpdateState) -> Void)?

    let repoOwner = "Udean777"
    let repoName = "Rill"
    let log = Logger(subsystem: "com.ssajudn.Rill", category: "update")

    var downloadSession: URLSession?
    var downloadExpectedBytes: Int64?

    private let userDefaults: UserDefaults

    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Runs a silent background check if at least 24 hours have passed since the last check.
    public func checkIfDue() async {
        let lastCheck = userDefaults.double(forKey: Self.lastCheckKey)
        if lastCheck > 0, Date().timeIntervalSince1970 - lastCheck < Self.automaticCheckInterval {
            return
        }
        await checkForUpdates(isUserInitiated: false)
    }

    /// Checks GitHub Releases for a newer version of Rill.
    public func checkForUpdates(isUserInitiated: Bool = false) async {
        guard !isChecking else { return }
        if case .downloading = state { return }
        if case .installing = state { return }

        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else {
            return
        }

        isChecking = true
        state = .checking

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 15.0
        )
        request.setValue("Rill-App", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        defer {
            isChecking = false
            let now = Date()
            lastCheckedDate = now
            userDefaults.set(now.timeIntervalSince1970, forKey: Self.lastCheckKey)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let message = String(localized: "Unable to reach GitHub Releases.")
                state = .failed(message)
                if isUserInitiated {
                    showAlert(
                        title: String(localized: "Update Check Failed"),
                        message: message
                    )
                }
                return
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let cleanRemote = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))

            if Version.isNewer(cleanRemote, than: currentVersion) {
                hasUpdate = true
                latestVersion = cleanRemote
                releaseNotesURL = URL(string: release.htmlUrl)

                if let dmgAsset = release.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") }),
                   let dmgURL = URL(string: dmgAsset.browserDownloadUrl) {
                    dmgDownloadURL = dmgURL
                    downloadExpectedBytes = dmgAsset.size
                } else {
                    dmgDownloadURL = URL(string: release.htmlUrl)
                    downloadExpectedBytes = nil
                }

                state = .available(version: cleanRemote)
                showUpdateAvailableDialog(version: cleanRemote)
            } else {
                hasUpdate = false
                latestVersion = ""
                releaseNotesURL = nil
                dmgDownloadURL = nil
                downloadExpectedBytes = nil
                state = .upToDate

                if isUserInitiated {
                    showAlert(
                        title: String(localized: "You’re Up to Date"),
                        message: String(localized: "Rill \(currentVersion) is currently the newest version available.")
                    )
                }
            }
        } catch {
            log.error("update check failed: \(error.localizedDescription, privacy: .public)")
            state = .failed(error.localizedDescription)
            if isUserInitiated {
                showAlert(
                    title: String(localized: "Update Check Failed"),
                    message: error.localizedDescription
                )
            }
        }
    }
}
