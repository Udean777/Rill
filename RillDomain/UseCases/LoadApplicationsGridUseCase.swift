import Foundation

/// Combines installed applications from `ApplicationCataloguing` with the user's
/// persisted `ApplicationsLayout` (custom order, folders, hidden apps, and
/// custom links).
public struct LoadApplicationsGridUseCase: Sendable {
    public struct Output: Sendable, Equatable {
        public let nodes: [ApplicationsGridNode]
        public let hiddenApplications: [ApplicationGridItem]

        public init(
            nodes: [ApplicationsGridNode],
            hiddenApplications: [ApplicationGridItem]
        ) {
            self.nodes = nodes
            self.hiddenApplications = hiddenApplications
        }
    }

    private let applications: ApplicationCataloguing
    private let layoutStore: ApplicationsLayoutStoring
    private let preferences: (@Sendable () async -> Preferences)?

    public init(
        applications: ApplicationCataloguing,
        layoutStore: ApplicationsLayoutStoring,
        preferences: (@Sendable () async -> Preferences)? = nil
    ) {
        self.applications = applications
        self.layoutStore = layoutStore
        self.preferences = preferences
    }

    public func callAsFunction() async -> Output {
        async let fetchedApps = applications.applications()
        async let fetchedLayout = layoutStore.load()
        async let fetchedPreferences = preferences?() ?? .default

        let (allApps, layout, currentPreferences) = await (
            fetchedApps, fetchedLayout, fetchedPreferences
        )

        var appsByID: [String: ApplicationGridItem] = [:]
        appsByID.reserveCapacity(allApps.count)
        for result in allApps {
            let appID = result.id.raw
            appsByID[appID] = ApplicationGridItem(
                id: "app:\(appID)",
                appID: appID,
                title: result.title,
                subtitle: result.subtitle,
                icon: result.icon,
                action: result.primaryAction
            )
        }

        let hidden = layout.hiddenAppIDs.compactMap { appsByID[$0] }.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }

        var placedAppIDs = Set<String>()
        var nodes: [ApplicationsGridNode] = []

        for entry in layout.entries {
            switch entry {
            case .app(let appID):
                guard !layout.hiddenAppIDs.contains(appID),
                      let item = appsByID[appID],
                      placedAppIDs.insert(appID).inserted else {
                    continue
                }
                nodes.append(.item(item))

            case .custom(let customEntry):
                nodes.append(
                    .item(
                        makeCustomItem(
                            customEntry,
                            defaultBrowserBundleID: currentPreferences.defaultBrowserBundleID
                        )
                    )
                )

            case .folder(let folder):
                var folderItems: [ApplicationGridItem] = []
                for ref in folder.items {
                    switch ref {
                    case .app(let appID):
                        guard !layout.hiddenAppIDs.contains(appID),
                              let item = appsByID[appID],
                              placedAppIDs.insert(appID).inserted else {
                            continue
                        }
                        folderItems.append(item)
                    case .custom(let customEntry):
                        folderItems.append(
                            makeCustomItem(
                                customEntry,
                                defaultBrowserBundleID: currentPreferences.defaultBrowserBundleID
                            )
                        )
                    }
                }
                if !folderItems.isEmpty {
                    nodes.append(.folder(id: folder.id, name: folder.name, items: folderItems))
                }
            }
        }

        // Append newly installed apps that are not yet in the saved layout.
        for result in allApps {
            let appID = result.id.raw
            guard !layout.hiddenAppIDs.contains(appID),
                  !placedAppIDs.contains(appID),
                  let item = appsByID[appID] else {
                continue
            }
            nodes.append(.item(item))
        }

        return Output(nodes: nodes, hiddenApplications: hidden)
    }

    private func makeCustomItem(
        _ entry: CustomApplicationEntry,
        defaultBrowserBundleID: String?
    ) -> ApplicationGridItem {
        ApplicationsLayoutMapper.item(
            for: entry,
            defaultBrowserBundleID: defaultBrowserBundleID
        )
    }
}
