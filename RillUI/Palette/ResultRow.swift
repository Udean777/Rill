import AppKit
import RillDomain
import SwiftUI

/// One palette row: icon, title, optional subtitle and its ⌘N hint.
struct ResultRow: View {
    let result: SearchResult
    let shortcutNumber: Int?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            icon
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(result.title)
                    .font(.body)
                    .lineLimit(1)

                if let subtitle = result.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if let shortcutNumber {
                Text("⌘\(shortcutNumber)")
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .foregroundStyle(isSelected ? .white : .primary)
        .background(
            isSelected ? Color.accentColor : .clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
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
                .frame(width: 18, height: 18)
        case .fileURL(let url):
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .scaledToFit()
        }
    }

    private var accessibilityLabel: String {
        [result.title, result.subtitle]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
