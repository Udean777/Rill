import AppKit
import RillDomain
import SwiftUI

/// One fixed row of command chips under the result list (root layout only).
struct CommandChipRow: View {
    let results: [SearchResult]
    let selectedResultID: SearchResult.ID?
    let action: (SearchResult) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(results) { result in
                chip(for: result)
            }
            Spacer(minLength: 0)
        }
    }

    private func chip(for result: SearchResult) -> some View {
        let isSelected = result.id == selectedResultID

        return Button {
            action(result)
        } label: {
            HStack(spacing: 5) {
                icon(result.icon)

                Text(result.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .frame(height: 24)
            .foregroundStyle(.primary)
            // Same tint + border selection as rows: text stays above 4.5:1
            // and the border carries the state at 3:1.
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isSelected
                            ? Color.accentColor.opacity(0.16)
                            : Color.primary.opacity(0.06)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        isSelected ? Color.accentColor.opacity(0.85) : .clear,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(result.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func icon(_ ref: RillDomain.IconRef) -> some View {
        switch ref {
        case .systemSymbol(let name):
            Image(systemName: name)
                .font(.system(size: 11))
        case .fileURL(let url):
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)
        }
    }
}
