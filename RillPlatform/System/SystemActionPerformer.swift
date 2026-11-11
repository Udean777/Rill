import AppKit
import RillDomain

/// Performs domain actions with AppKit. The only type that knows how a
/// descriptor becomes a real launch.
public final class SystemActionPerformer: ActionPerforming {
    public init() {}

    public nonisolated func perform(_ action: ActionDescriptor) async throws {
        try await MainActor.run {
            try Self.performOnMain(action)
        }
    }

    @MainActor
    private static func performOnMain(_ action: ActionDescriptor) throws {
        switch action {
        case .openApplication(let bundleID):
            guard
                let url = NSWorkspace.shared.urlForApplication(
                    withBundleIdentifier: bundleID
                )
            else {
                throw SystemActionError.applicationNotFound
            }
            try open(url)

        case .openURL(let url), .openFile(let url):
            try open(url)
        }
    }

    @MainActor
    private static func open(_ url: URL) throws {
        guard NSWorkspace.shared.open(url) else {
            throw SystemActionError.openFailed
        }
    }
}

private enum SystemActionError: Error {
    case applicationNotFound
    case openFailed
}
