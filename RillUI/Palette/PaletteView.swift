import RillDomain
import SwiftUI

/// The palette: a search field over sectioned, keyboard-navigable results.
public struct PaletteView: View {
    @Bindable private var viewModel: PaletteViewModel
    @FocusState private var isSearchFocused: Bool

    public init(viewModel: PaletteViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchField
            resultList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .onAppear { isSearchFocused = viewModel.isVisible }
        .onChange(of: viewModel.isVisible) { _, isVisible in
            isSearchFocused = isVisible
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(String(localized: "Search"), text: queryBinding)
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .focused($isSearchFocused)
                .accessibilityLabel(String(localized: "Search"))
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
    }

    private var queryBinding: Binding<String> {
        Binding(
            get: { viewModel.query },
            set: { viewModel.updateQuery($0) }
        )
    }

    private var resultList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2, pinnedViews: [.sectionHeaders]) {
                    ForEach(viewModel.sections) { ranked in
                        Section {
                            ForEach(ranked.results) { result in
                                ResultRow(
                                    result: result,
                                    shortcutNumber: viewModel.shortcutNumber(for: result.id),
                                    isSelected: viewModel.selectedResultID == result.id,
                                    action: { viewModel.selectAndActivate(result) }
                                )
                                .id(result.id)
                            }
                        } header: {
                            SectionHeader(section: ranked.section)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .onChange(of: viewModel.selectedResultID) { _, selectedResultID in
                guard let selectedResultID else { return }
                withAnimation(.easeOut(duration: 0.08)) {
                    proxy.scrollTo(selectedResultID, anchor: .center)
                }
            }
        }
    }
}

#Preview {
    let commands = PreviewCommands()
    let applications = PreviewApplications()
    let search = SearchUseCase(
        commands: commands,
        applications: applications,
        usage: PreviewUsageStore(),
        clock: PreviewClock()
    )
    PaletteView(viewModel: PaletteViewModel(searchUseCase: search))
        .frame(width: 680, height: 420)
}

private struct PreviewCommands: CommandProviding {
    var commands: [SearchResult] {
        [
            SearchResult(
                id: .init(source: "command", raw: "open-settings"),
                title: "Open Settings",
                subtitle: "System Settings",
                icon: .systemSymbol("gearshape"),
                section: .commands,
                kind: .command,
                primaryAction: .openFile(URL(fileURLWithPath: "/"))
            )
        ]
    }
}

private struct PreviewUsageStore: UsageStoring {
    func snapshot() async -> UsageSnapshot {
        .empty
    }

    func record(_ id: SearchResult.ID, at date: Date) async {}
}

private struct PreviewClock: RillDomain.Clock {
    var now: Date { Date(timeIntervalSince1970: 0) }
}

private struct PreviewApplications: ApplicationCataloguing {
    func applications() async -> [SearchResult] {
        [
            SearchResult(
                id: .init(source: "application", raw: "preview"),
                title: "Preview App",
                subtitle: "/Applications",
                icon: .systemSymbol("app"),
                section: .applications,
                kind: .application,
                primaryAction: .openFile(URL(fileURLWithPath: "/"))
            )
        ]
    }
}
