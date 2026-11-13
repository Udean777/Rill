import AppKit
import Foundation
import RillDomain

extension UpdateManager {
    func performBackgroundInstall(dmgPath: String, targetVersion: String) async {
        let appPath = Bundle.main.bundlePath
        let script = UpdateInstallerSupport.installScript(
            appPath: appPath,
            dmgPath: dmgPath,
            expectedVersion: targetVersion
        )

        var installSucceeded = await Self.runShellScript(script)

        // If user permissions failed on /Applications, retry with AppleScript admin privileges.
        if !installSucceeded {
            installSucceeded = Self.runShellScriptAsAdmin(script)
        }

        try? FileManager.default.removeItem(atPath: dmgPath)

        if installSucceeded {
            state = .readyToQuit(version: targetVersion)
        } else {
            let message = String(localized: "Installation failed. Please try again or download manually.")
            state = .failed(message)
            showAlert(
                title: String(localized: "Update Failed"),
                message: message
            )
        }
    }

    /// Terminates Rill and, when `relaunch` is `true`, spawns a detached helper
    /// that waits for this PID to exit before opening the updated bundle.
    public func quitAfterUpdate(relaunch: Bool = true) {
        if relaunch {
            let appPath = Bundle.main.bundlePath
            let pid = ProcessInfo.processInfo.processIdentifier
            let quotedApp = UpdateInstallerSupport.shellSingleQuoted(appPath)
            let command = """
            while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.1; done; \
            /usr/bin/open -n \(quotedApp)
            """
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", command]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
        }
        NSApplication.shared.terminate(nil)
    }

    public func openReleasePage() {
        guard let url = releaseNotesURL
            ?? URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases/latest")
        else { return }
        NSWorkspace.shared.open(url)
    }

    private static func runShellScript(_ script: String) async -> Bool {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", script]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { finished in
                continuation.resume(returning: finished.terminationStatus == 0)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }

    private static func runShellScriptAsAdmin(_ script: String) -> Bool {
        let escaped = script
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"
        var errorInfo: NSDictionary?
        let appleScript = NSAppleScript(source: source)
        return appleScript?.executeAndReturnError(&errorInfo) != nil
    }
}
