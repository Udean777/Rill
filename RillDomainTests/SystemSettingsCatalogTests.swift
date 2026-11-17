import Foundation
import Testing

import RillData
import RillDomain

@Suite("SystemSettingsCatalog")
struct SystemSettingsCatalogTests {
    @Test func `every pane and sub-menu is its own system preferences URL`() async {
        let settings = await SystemSettingsCatalog().settings()

        #expect(settings.count >= 1000)
        #expect(Set(settings.map(\.id)).count == settings.count)
        #expect(Set(settings.map { $0.title.lowercased() }).count == settings.count)

        let titles = Set(settings.map(\.title))
        let expectedTitles = [
            "Change the wallpaper",
            "Change the screen saver",
            "Clock appearance",
            "Show wallpaper on all Spaces",
            "Click wallpaper to show desktop",
            "Automatically hide and show the Dock",
            "Automatically hide and show the menu bar",
            "Check for Software Updates",
            "Turn off display when inactive",
            "Accent color",
            "Liquid Glass",
            "Battery",
            "Full Disk Access",
            "Reduce Motion",
            "Hot Corners",
            "Night Shift",
            "Storage",
        ]
        for expected in expectedTitles {
            #expect(titles.contains(expected))
        }

        for row in settings {
            #expect(row.section == .systemSettings)
            #expect(row.kind == .systemSettings)
            #expect(!row.title.isEmpty)

            guard case .openURL(let url) = row.primaryAction else {
                Issue.record("\(row.title) does not open a URL")
                continue
            }
            // A pane whose identifier failed to parse would still produce a URL
            // with the bare scheme; require an identifier behind it.
            #expect(url.absoluteString.hasPrefix("x-apple.systempreferences:com.apple."))
        }
    }
}
