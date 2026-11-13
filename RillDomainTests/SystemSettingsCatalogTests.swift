import Foundation
import Testing

import RillData
import RillDomain

@Suite("SystemSettingsCatalog")
struct SystemSettingsCatalogTests {
    @Test func `every pane is its own system preferences URL`() {
        let settings = SystemSettingsCatalog().settings

        #expect(settings.count == 20)
        #expect(Set(settings.map(\.id)).count == settings.count)
        #expect(Set(settings.map(\.title)).count == settings.count)

        for row in settings {
            #expect(row.section == .systemSettings)
            #expect(row.kind == .systemSettings)

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
