import AppKit
import RillDomain
import RillPlatform

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var environment: AppEnvironment?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Declared in Info.plist too (LSUIElement); repeated here so a stale
        // activation-policy override from a previous launch cannot leave a
        // Dock tile behind.
        NSApp.setActivationPolicy(.accessory)

        let environment = AppEnvironment.live()
        self.environment = environment
        environment.start()
    }
}
