import AppKit
import RillDomain
import SwiftUI

/// One palette row: icon, title, optional subtitle and its ⌘N hint.
struct ResultRow: View {
    let result: SearchResult
    let shortcutNumber: Int?
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 9) {
            icon
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(result.title)
                    .font(.system(size: 13.5, weight: .medium))
                    .lineLimit(1)

                if let subtitle = result.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if let shortcutNumber {
                Text("⌘\(shortcutNumber)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .foregroundStyle(.primary)
        // Tint + accent border instead of a solid fill: keeps title contrast
        // above 4.5:1 while the 1 pt accent border carries the selection state.
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isSelected
                        ? Color.accentColor.opacity(0.16)
                        : (isHovered ? Color.primary.opacity(0.06) : Color.clear)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.85) : .clear, lineWidth: 1)
        }
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
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
        if let shortcutNumber {
            components.append("Command \(shortcutNumber)")
        }
        return components.joined(separator: ", ")
    }
}
