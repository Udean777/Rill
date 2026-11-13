import SwiftUI

/// Settings configuration view (see design.md §5.5).
/// Styled after Raycast preferences and macOS System Settings inset grouped cards.
public struct SettingsView: View {
    @Bindable public var viewModel: SettingsViewModel
    @State private var selectedTab: SettingsTab = .general

    private enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case search = "Search"
        case clipboard = "Clipboard"
        case data = "Data"
        case about = "About"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: "gearshape"
            case .search: "magnifyingglass"
            case .clipboard: "doc.on.clipboard"
            case .data: "externaldrive"
            case .about: "info.circle"
            }
        }
    }

    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 150)

            Rectangle()
                .fill(.primary.opacity(0.08))
                .frame(width: 0.5)

            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 560, height: 420)
        .task {
            await viewModel.load()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
                            .frame(width: 18)

                        Text(LocalizedStringKey(tab.rawValue))
                            .font(.system(size: 13, weight: selectedTab == tab ? .medium : .regular))
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor.opacity(0.14))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 14)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
    }

    private var detailContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                switch selectedTab {
                case .general:
                    GeneralSettingsTab(viewModel: viewModel)
                case .search:
                    SearchSettingsTab(viewModel: viewModel)
                case .clipboard:
                    ClipboardSettingsTab(viewModel: viewModel)
                case .data:
                    DataSettingsTab(viewModel: viewModel)
                case .about:
                    AboutSettingsTab(viewModel: viewModel)
                }
            }
            .padding(16)
        }
    }
}
