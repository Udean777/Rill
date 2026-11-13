import AppKit
import RillDomain
import RillPlatform

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var environment: AppEnvironment?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Repeated here alongside Info.plist (LSUIElement) to clear any stale
        // activation-policy override from a previous launch.
        ActivationPolicyController.shared.ensureAccessory()

        let environment = AppEnvironment.live()
        self.environment = environment
        environment.start()
    }
}
