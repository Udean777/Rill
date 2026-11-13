import AppKit
import RillDomain

/// Performs domain actions with AppKit. The only type that knows how a
/// descriptor becomes a real launch.
public final class SystemActionPerformer: ActionPerforming {
    public init() {}

    public nonisolated func perform(_ action: ActionDescriptor) async throws {
        switch action {
        case .openApplication(let bundleID):
            try await Self.openApplication(bundleID: bundleID)

        case .openURL(let url), .openFile(let url):
            try await Self.open(url)

        case .copyToPasteboard(let text):
            await MainActor.run {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
            }

        case .openSettings, .openClipboardHistory:
            // The app layer intercepts this before dispatch; reaching the
            // performer means the routing is broken, so fail loudly.
            throw SystemActionError.unsupportedAction
        }
    }

    private static func openApplication(bundleID: String) async throws {
        // Fast path: already-running apps activate directly via WindowServer,
        // avoiding LaunchServices URL resolution and open IPC.
        let activated = await MainActor.run {
            activateRunningApplication(bundleID: bundleID)
        }
        if activated {
            return
        }

        guard
            let url = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleID
            )
        else {
            throw SystemActionError.applicationNotFound
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    @MainActor
    private static func activateRunningApplication(bundleID: String) -> Bool {
        guard
            let running = NSRunningApplication
                .runningApplications(withBundleIdentifier: bundleID)
                .first(where: { !$0.isTerminated })
        else {
            return false
        }
        if running.isHidden {
            running.unhide()
        }
        return running.activate()
    }

    private static func open(_ url: URL) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        _ = try await NSWorkspace.shared.open(url, configuration: configuration)
    }

    @MainActor
    public static func revealInFinder(_ url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(url.deletingLastPathComponent())
        }
    }

    @MainActor
    public static func openAccessibilitySettings() async {
        if !AXIsProcessTrusted() {
            let bundleID = Bundle.main.bundleIdentifier ?? "com.ssajudn.Rill"
            await TCCResetRunner.shared.reset(service: "Accessibility", bundleID: bundleID)
            try? await Task.sleep(for: .milliseconds(100))
        }
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    @MainActor
    public static func hasFullDiskAccess() -> Bool {
        let systemTCC = "/Library/Application Support/com.apple.TCC/TCC.db"
        if let handle = FileHandle(forReadingAtPath: systemTCC) {
            try? handle.close()
            return true
        }
        return false
    }

    @MainActor
    public static func openFullDiskAccessSettings() async {
        if !hasFullDiskAccess() {
            let bundleID = Bundle.main.bundleIdentifier ?? "com.ssajudn.Rill"
            await TCCResetRunner.shared.reset(service: "SystemPolicyAllFiles", bundleID: bundleID)
            try? await Task.sleep(for: .milliseconds(100))
        }
        _ = try? Data(contentsOf: URL(fileURLWithPath: "/Library/Application Support/com.apple.TCC/TCC.db"))
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    @MainActor
    public static func revealApplicationInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    @MainActor
    public static func requestProtectedFolderAccess() async {
        let directories: [FileManager.SearchPathDirectory] = [
            .desktopDirectory,
            .downloadsDirectory,
            .documentDirectory,
        ]
        for directory in directories {
            guard let url = FileManager.default.urls(for: directory, in: .userDomainMask).first else {
                continue
            }
            _ = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        }
    }
}

private actor TCCResetRunner {
    static let shared = TCCResetRunner()

    func reset(service: String, bundleID: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", service, bundleID]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}

private enum SystemActionError: Error {
    case applicationNotFound
    case openFailed
    case unsupportedAction
}
