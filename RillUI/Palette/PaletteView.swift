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
            Divider()
            resultList
            if viewModel.isRootQuery, let commands = viewModel.commandSection {
                Divider()
                CommandChipRow(
                    results: commands.results,
                    selectedResultID: viewModel.selectedResultID,
                    action: { viewModel.selectAndActivate($0) }
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .onAppear { isSearchFocused = viewModel.isVisible }
        .onChange(of: viewModel.isVisible) { _, isVisible in
            isSearchFocused = isVisible
        }
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField(String(localized: "Search"), text: queryBinding)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($isSearchFocused)
                .accessibilityLabel(String(localized: "Search query"))
                .accessibilityIdentifier("SearchField")
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

    private var resultList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(visibleSections) { ranked in
                        VStack(spacing: 1) {
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

                            if ranked.section == .applications, viewModel.hasMultipleApplicationPages {
                                pager
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: viewModel.selectedResultID) { _, selectedResultID in
                guard let selectedResultID else { return }
                withAnimation(.easeOut(duration: 0.08)) {
                    proxy.scrollTo(selectedResultID, anchor: .center)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(String(localized: "Search Results"))
        }
    }

    /// Root layout keeps commands in the chip row, not in the scrolling list.
    private var visibleSections: [RankedSection] {
        viewModel.isRootQuery
            ? viewModel.displaySections.filter { $0.section != .commands }
            : viewModel.displaySections
    }

    private var pager: some View {
        HStack(spacing: 10) {
            Spacer()

            Button {
                viewModel.changeApplicationsPage(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.applicationsPage == 0)
            .accessibilityLabel(String(localized: "Previous page"))

            Text("\(viewModel.applicationsPage + 1) / \(viewModel.applicationPageCount)")
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Button {
                viewModel.changeApplicationsPage(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.applicationsPage >= viewModel.applicationPageCount - 1)
            .accessibilityLabel(String(localized: "Next page"))

            Spacer()
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.vertical, 3)
        .accessibilityElement(children: .contain)
        .accessibilityValue(
            String(
                localized: "Page \(viewModel.applicationsPage + 1) of \(viewModel.applicationPageCount)"
            )
        )
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
