import Foundation
import RillDomain

/// The built-in command catalogue.
public struct CommandRegistry: CommandProviding {
    public let commands: [SearchResult]

    public init() {
        commands = Self.builtIns()
    }

    private static func builtIns() -> [SearchResult] {
        var results: [SearchResult] = []

        if let settingsURL = URL(string: "x-apple.systempreferences:") {
            results.append(
                SearchResult(
                    id: .init(source: "command", raw: "open-settings"),
                    title: String(localized: "Open Settings"),
                    subtitle: String(localized: "System Settings"),
                    icon: .systemSymbol("gearshape"),
                    section: .commands,
                    kind: .command,
                    primaryAction: .openURL(settingsURL)
                )
            )
        }

        results.append(
            SearchResult(
                id: .init(source: "command", raw: "open-home"),
                title: String(localized: "Open Home Folder"),
                icon: .systemSymbol("house"),
                section: .commands,
                kind: .command,
                primaryAction: .openFile(FileManager.default.homeDirectoryForCurrentUser)
            )
        )

        results.append(
            SearchResult(
                id: .init(source: "command", raw: "open-applications"),
                title: String(localized: "Open Applications"),
                icon: .systemSymbol("square.grid.2x2"),
                section: .commands,
                kind: .command,
                primaryAction: .openFile(URL(fileURLWithPath: "/Applications", isDirectory: true))
            )
        )

        return results
    }
}
