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
}

private enum SystemActionError: Error {
    case applicationNotFound
    case openFailed
    case unsupportedAction
}
