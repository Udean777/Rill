import AppKit
import Foundation

extension UpdateManager {
    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "Close"))
        alert.runModal()
    }

    func showUpdateAvailableDialog(version: String) {
        let alert = NSAlert()
        alert.messageText = String(localized: "Rill \(version) is Available")
        alert.informativeText = String(localized: "Would you like to download and install this update now?")
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "Update Now"))
        alert.addButton(withTitle: String(localized: "Release Notes"))
        alert.addButton(withTitle: String(localized: "Later"))

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            downloadAndInstallUpdate()
        case .alertSecondButtonReturn:
            openReleasePage()
        default:
            break
        }
    }
}
