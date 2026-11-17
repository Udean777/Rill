import Observation
import RillDomain

/// Update-checker state and the actions the About tab triggers.
@MainActor
@Observable
public final class UpdateStatus {
    public var state: UpdateState = .idle

    @ObservationIgnored public var onCheckForUpdates: (() -> Void)?
    @ObservationIgnored public var onInstallUpdate: (() -> Void)?
    @ObservationIgnored public var onRestartToUpdate: (() -> Void)?

    public func checkForUpdates() {
        onCheckForUpdates?()
    }

    public func installUpdate() {
        onInstallUpdate?()
    }

    public func restartToUpdate() {
        onRestartToUpdate?()
    }
}
