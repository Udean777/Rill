import Foundation

/// Resolves Rill's Application Support subdirectory once for file-backed stores.
enum AppSupportDirectory {
    static var rill: URL {
        let base =
            FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("Rill", isDirectory: true)
    }

    static func file(_ name: String) -> URL {
        rill.appendingPathComponent(name, isDirectory: false)
    }

    static func directory(_ name: String) -> URL {
        rill.appendingPathComponent(name, isDirectory: true)
    }
}
