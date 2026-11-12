import AppKit
import RillDomain

/// Records every app activation as usage, so suggested apps reflect real use.
///
/// Only observes; it never activates anything, so the palette's focus model
/// (design.md §5.3) is untouched.
@MainActor
public final class AppUsageTracker {
    private let usage: UsageStoring
    private let clock: Clock
    private let ownBundleID = Bundle.main.bundleIdentifier
    private var observation: Task<Void, Never>?
    private var lastRecordedBundleID: String?

    public init(usage: UsageStoring, clock: Clock) {
        self.usage = usage
        self.clock = clock
    }

    public func start() {
        guard observation == nil else { return }
        observation = Task { [weak self] in
            let notifications = NSWorkspace.shared.notificationCenter.notifications(
                named: NSWorkspace.didActivateApplicationNotification
            )
            for await notification in notifications {
                guard let self else { return }
                self.record(notification)
            }
        }
    }

    deinit {
        observation?.cancel()
    }

    private func record(_ notification: Notification) {
        guard
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication,
            let bundleID = application.bundleIdentifier,
            bundleID != ownBundleID
        else { return }

        // Repeated notifications for the app that is already frontmost are not
        // another use; skip them so switching back and forth is the only count.
        guard bundleID != lastRecordedBundleID else { return }
        lastRecordedBundleID = bundleID

        let id = SearchResult.ID(source: "application", raw: bundleID)
        let now = clock.now
        Task { [usage] in
            await usage.record(id, at: now)
        }
    }
}
