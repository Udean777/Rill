import RillDomain
import SwiftUI

/// Sticky section title above a group of rows.
struct SectionHeader: View {
    let section: RillDomain.Section

    var body: some View {
        Text(section.localizedTitle)
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 4)
            .background(.regularMaterial)
    }
}

extension RillDomain.Section {
    /// Localised display name. User-facing text stays out of Domain.
    var localizedTitle: String {
        switch self {
        case .favorites: String(localized: "Favorites")
        case .suggestions: String(localized: "Suggestions")
        case .commands: String(localized: "Commands")
        case .applications: String(localized: "Applications")
        case .files: String(localized: "Files")
        case .fallback: String(localized: "Other")
        }
    }
}
