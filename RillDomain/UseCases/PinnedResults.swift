import Foundation

/// Rebuilds pinned rows: live catalogue data for apps and commands, the stored
/// path for files.
enum PinnedResults {
    static func rebuild(
        from pins: [PinnedResult],
        applications: [SearchResult],
        commands: [SearchResult]
    ) -> [SearchResult] {
        let applicationsByID = Dictionary(
            uniqueKeysWithValues: applications.map { ($0.id, $0) }
        )
        let commandsByID = Dictionary(uniqueKeysWithValues: commands.map { ($0.id, $0) })

        return pins.compactMap { pin in
            if let fileURL = pin.fileURL {
                return SearchResult(
                    id: pin.id,
                    title: pin.title,
                    subtitle: pin.subtitle,
                    icon: .fileURL(fileURL),
                    section: .favorites,
                    kind: .file,
                    primaryAction: .openFile(fileURL)
                )
            }
            let live = applicationsByID[pin.id] ?? commandsByID[pin.id]
            return live?.withSection(.favorites)
        }
    }
}
