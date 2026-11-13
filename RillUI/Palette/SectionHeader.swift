import RillDomain
import SwiftUI

/// Compact section label with a trailing hairline rule. No filled container,
/// so the label can never read as a rounded chip.
struct SectionHeader: View {
    let section: RillDomain.Section

    var body: some View {
        HStack(spacing: 8) {
            Text(section.localizedTitle)
                .font(.system(size: 11.5, weight: .semibold))
                .tracking(0.65)
                .foregroundStyle(.secondary)
                .fixedSize()

            Rectangle()
                .fill(.primary.opacity(0.08))
                .frame(height: 0.5)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}

extension RillDomain.Section {
    /// Localised display name. User-facing text stays out of Domain.
    var localizedTitle: String {
        switch self {
        case .currency: String(localized: "Currency")
        case .systemSettings: String(localized: "System Settings")
        case .favorites: String(localized: "Favorites")
        case .suggestions: String(localized: "Suggestions")
        case .commands: String(localized: "Commands")
        case .applications: String(localized: "Applications")
        case .files: String(localized: "Files")
        case .fallback: String(localized: "Other")
        }
    }
}
