import RillDomain
import SwiftUI

/// Renders a single icon tile (application, custom link, or folder) in the
/// floating Applications grid.
struct ApplicationGridTile: View {
    let node: ApplicationsGridNode
    let isSelected: Bool
    let isDropTargeted: Bool
    let onTap: () -> Void
    let onHideApp: (String) -> Void
    let onRemoveCustom: (UUID) -> Void
    let onGroupWithNewFolder: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 10) {
            iconView
                .frame(width: 76, height: 76)
                .shadow(color: .black.opacity(0.22), radius: 8, y: 4)

            Text(node.title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 34, alignment: .top)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    isDropTargeted
                        ? Color.accentColor.opacity(0.24)
                        : (isSelected
                            ? Color.accentColor.opacity(0.18)
                            : (isHovered ? Color.primary.opacity(0.08) : Color.clear))
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isDropTargeted || isSelected ? Color.accentColor.opacity(0.85) : .clear,
                    lineWidth: 1.5
                )
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { isHovered = $0 }
        .contextMenu {
            contextMenuItems
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(node.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var iconView: some View {
        switch node {
        case .item(let item):
            GridItemIconView(icon: item.icon)
        case .folder(_, _, let items):
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(28), spacing: 5), count: 2),
                spacing: 5
            ) {
                ForEach(Array(items.prefix(4))) { item in
                    GridItemIconView(icon: item.icon)
                        .frame(width: 28, height: 28)
                }
            }
            .padding(8)
            .frame(width: 76, height: 76)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button("Open") {
            onTap()
        }
        if case .item(let item) = node {
            if let appID = item.appID {
                Button("Hide from Grid") {
                    onHideApp(appID)
                }
            }
            if let customID = item.customID {
                Button("Remove Custom Item", role: .destructive) {
                    onRemoveCustom(customID)
                }
            }
            Button("Move to New Folder…") {
                onGroupWithNewFolder()
            }
        }
    }
}

struct GridItemIconView: View {
    let icon: RillDomain.IconRef

    var body: some View {
        switch icon {
        case .systemSymbol(let name):
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .padding(10)
                .foregroundStyle(.tint)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        case .fileURL(let url):
            Image(nsImage: IconCache.shared.image(for: url))
                .resizable()
                .scaledToFit()
        }
    }
}
