import RillDomain
import SwiftUI

/// One palette row: icon, title, optional subtitle and its ⌘N hint.
struct ResultRow: View {
    let result: SearchResult
    let shortcutNumber: Int?
    let isSelected: Bool
    let isPinned: Bool
    let action: () -> Void
    let onTogglePin: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            icon
                .frame(width: 18, height: 18)
                .foregroundStyle(usesAccentIcon ? Color.accentColor : Color.primary)

            HStack(spacing: 8) {
                Text(result.title)
                    .font(.system(
                        size: isConversion ? 15 : 14,
                        weight: isConversion ? .semibold : (isSelected ? .medium : .regular)
                    ))
                    .lineLimit(1)

                if let subtitle = result.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            if let shortcutNumber {
                Text("⌘\(shortcutNumber)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .foregroundStyle(.primary)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isSelected
                        ? Color.accentColor.opacity(0.14)
                        : (isHovered ? Color.primary.opacity(0.06)
                            : (isConversion ? Color.accentColor.opacity(0.08) : Color.clear))
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.85) : .clear, lineWidth: 1)
        }
        .animation(.spring(response: 0.18, dampingFraction: 0.85), value: isSelected)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(isPinned ? "Unpin" : "Pin") {
                onTogglePin()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Currency rows get a heavier weight and accent tint so a live conversion
    /// is not lost among file results.
    private var isConversion: Bool {
        result.kind == .currency
    }

    /// System Settings rows are actions on the system, not documents. An accent
    /// icon marks them without competing with the currency headline.
    private var usesAccentIcon: Bool {
        isConversion || result.kind == .systemSettings
    }

    @ViewBuilder
    private var icon: some View {
        switch result.icon {
        case .systemSymbol(let name):
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        case .fileURL(let url):
            Image(nsImage: IconCache.shared.image(for: url))
                .resizable()
                .scaledToFit()
        }
    }

    private var accessibilityLabel: String {
        var components = [result.title]
        if let subtitle = result.subtitle {
            components.append(subtitle)
        }
        components.append(result.section.localizedTitle)
        if isPinned {
            components.append("Pinned")
        }
        if let shortcutNumber {
            components.append("Command \(shortcutNumber)")
        }
        return components.joined(separator: ", ")
    }
}
