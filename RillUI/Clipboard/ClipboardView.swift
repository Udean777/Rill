import AppKit
import RillDomain
import SwiftUI

/// Master-detail split view for the Clipboard History mode.
public struct ClipboardView: View {
    @Bindable private var viewModel: ClipboardViewModel
    @FocusState private var isSearchFocused: Bool

    public init(viewModel: ClipboardViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            filterBar
            Divider()
                .opacity(0.4)

            HStack(spacing: 0) {
                masterList
                    .frame(width: 300)

                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 0.5)

                ClipboardPreviewView(
                    item: viewModel.selectedItem,
                    imagesDirectoryURL: viewModel.imagesDirectoryURL
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)

            Divider()
                .opacity(0.4)

            actionBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isSearchFocused = true
            viewModel.show()
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 8) {
            Button {
                _ = viewModel.handleEscape()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.accentColor)

            TextField(String(localized: "Search clipboard history..."), text: queryBinding)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($isSearchFocused)

            if !viewModel.query.isEmpty {
                Button {
                    viewModel.updateQuery("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
    }

    private var queryBinding: Binding<String> {
        Binding(
            get: { viewModel.query },
            set: { viewModel.updateQuery($0) }
        )
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(ClipboardFilter.allCases) { filter in
                    Button {
                        viewModel.selectFilter(filter)
                    } label: {
                        Text(LocalizedStringKey(filter.rawValue))
                            .font(.system(size: 12, weight: viewModel.activeFilter == filter ? .semibold : .regular))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3.5)
                            .background(
                                viewModel.activeFilter == filter
                                    ? Color.accentColor.opacity(0.18)
                                    : Color.primary.opacity(0.04),
                                in: Capsule()
                            )
                            .foregroundStyle(viewModel.activeFilter == filter ? Color.accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
    }

    // MARK: - Master List

    private var masterList: some View {
        Group {
            if viewModel.items.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundStyle(.tertiary)
                    Text("No matching history")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(viewModel.items) { item in
                                clipboardRow(for: item)
                                    .id(item.id)
                            }
                        }
                        .padding(6)
                    }
                    .onChange(of: viewModel.selectedItemID) { _, newID in
                        if let newID {
                            proxy.scrollTo(newID, anchor: nil)
                        }
                    }
                }
            }
        }
    }

    private func clipboardRow(for item: ClipboardItem) -> some View {
        let isSelected = viewModel.selectedItemID == item.id

        return HStack(spacing: 8) {
            typeIcon(for: item)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(rowTitle(for: item))
                    .font(.system(size: 13.5, weight: isSelected ? .medium : .regular))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    if let app = item.sourceApp {
                        Text(app.name)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                        Text("•")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    Text(item.copiedAt, style: .relative)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isSelected
                        ? Color.accentColor.opacity(0.14)
                        : Color.clear
                )
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedItemID = item.id
        }
    }

    private func rowTitle(for item: ClipboardItem) -> String {
        switch item.contentType {
        case .color:
            return item.metadata.colorHex ?? item.textContent ?? "Color"
        case .image:
            if let dims = item.metadata.imageDimensions {
                return "Image (\(dims.width) × \(dims.height))"
            }
            return "Image"
        case .files:
            return item.textContent ?? "Files"
        case .link:
            if let url = URL(string: item.textContent ?? ""), let host = url.host {
                return host
            }
            return item.textContent ?? "Link"
        case .code:
            return item.textContent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Code"
        case .text:
            return item.textContent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Text"
        }
    }

    @ViewBuilder
    private func typeIcon(for item: ClipboardItem) -> some View {
        switch item.contentType {
        case .color:
            Circle()
                .fill(Color(hex: item.metadata.colorHex ?? "#000000"))
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 0.5))
        case .image:
            Image(systemName: "photo")
                .font(.system(size: 11))
                .foregroundStyle(.purple)
        case .code:
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 10))
                .foregroundStyle(.green)
        case .link:
            Image(systemName: "link")
                .font(.system(size: 11))
                .foregroundStyle(.blue)
        case .files:
            Image(systemName: "doc.on.doc")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
        case .text:
            Image(systemName: "text.alignleft")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            actionHint("↵", label: "Paste")
            actionHint("⌥↵", label: "Plain Text")
            actionHint("⌘C", label: "Copy")
            actionHint("⌘P", label: "Pin")
            actionHint("⌘⌫", label: "Delete")
            Spacer()
            actionHint("Esc", label: "Back")
        }
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(Color.primary.opacity(0.015))
    }

    private func actionHint(_ key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 3.5))

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

private extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch clean.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
