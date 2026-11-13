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
        .task {
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
                                ClipboardRowView(
                                    item: item,
                                    isSelected: viewModel.selectedItemID == item.id
                                )
                                .id(item.id)
                                .onTapGesture {
                                    viewModel.selectedItemID = item.id
                                }
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
