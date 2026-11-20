import RillDomain
import SwiftUI

/// Launchpad-style floating overlay showing customisable applications, folders,
/// search filtering, drag-and-drop ordering, and pagination.
public struct ApplicationsGridView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable private var viewModel: ApplicationsGridViewModel
    @FocusState private var isSearchFocused: Bool

    @State private var dropTargetID: String?
    @State private var isShowingAddCustom = false
    @State private var customTitle = ""
    @State private var customTarget = ""
    @State private var customIsWebURL = false
    @State private var folderRenameText = ""
    @State private var isShowingHiddenApps = false

    public init(viewModel: ApplicationsGridViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.32))
                .ignoresSafeArea()
                .onTapGesture {
                    if viewModel.openFolderID != nil {
                        viewModel.openFolderID = nil
                    } else {
                        viewModel.onRequestHide?()
                    }
                }

            VStack(spacing: 24) {
                topBar

                if viewModel.isFiltering {
                    filteredGrid
                } else {
                    pagedGrid
                }

                if !viewModel.isFiltering && viewModel.pageCount > 1 {
                    pageIndicator
                }
            }
            .padding(.horizontal, 72)
            .padding(.top, 46)
            .padding(.bottom, 34)

            if let folder = viewModel.openFolder {
                folderOverlay(folder: folder)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(viewModel.isVisible ? 1.0 : 1.04)
        .opacity(viewModel.isVisible ? 1.0 : 0.0)
        .animation(
            reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.88),
            value: viewModel.isVisible
        )
        .task(id: viewModel.isVisible) {
            isSearchFocused = viewModel.isVisible
        }
        .onChange(of: reduceMotion, initial: true) { _, newValue in
            viewModel.isReduceMotionEnabled = newValue
        }
        .sheet(isPresented: $isShowingAddCustom) {
            addCustomSheet
        }
        .popover(isPresented: $isShowingHiddenApps) {
            hiddenAppsPopover
        }
    }

    private var topBar: some View {
        ZStack {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField(String(localized: "Search Applications"), text: $viewModel.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($isSearchFocused)
                    .accessibilityLabel(String(localized: "Search Applications"))
            }
            .padding(.horizontal, 12)
            .frame(width: 280, height: 34)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 0.8)
            )

            HStack(spacing: 8) {
                if !viewModel.hiddenApplications.isEmpty {
                    Button {
                        isShowingHiddenApps = true
                    } label: {
                        Label("Hidden (\(viewModel.hiddenApplications.count))", systemImage: "eye.slash")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button {
                    customTitle = ""
                    customTarget = ""
                    customIsWebURL = false
                    isShowingAddCustom = true
                } label: {
                    Label("Add Custom", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 90, maximum: 140), spacing: 18),
            count: viewModel.columns
        )
    }

    /// One tile's design size. The whole page is scaled down to fit the screen,
    /// so rows × columns never pushes the page indicator off-screen.
    private static let tileWidth: CGFloat = 140
    private static let tileHeight: CGFloat = 140
    private static let columnSpacing: CGFloat = 18
    private static let rowSpacing: CGFloat = 22

    private var designSize: CGSize {
        CGSize(
            width: CGFloat(viewModel.columns) * Self.tileWidth
                + CGFloat(max(0, viewModel.columns - 1)) * Self.columnSpacing,
            height: CGFloat(viewModel.rows) * Self.tileHeight
                + CGFloat(max(0, viewModel.rows - 1)) * Self.rowSpacing
        )
    }

    /// Pages sit side by side and translate with the trackpad; only
    /// `InteractivePagerTrack` observes `swipeOffset`, so 120Hz drags cost a
    /// single layer transform without re-evaluating any tile views.
    private var pagedGrid: some View {
        GeometryReader { proxy in
            let design = designSize
            let scale = min(
                1,
                proxy.size.width / max(design.width, 1),
                proxy.size.height / max(design.height, 1)
            )
            let pageWidth = proxy.size.width

            InteractivePagerTrack(
                viewModel: viewModel,
                pageWidth: pageWidth,
                pageHeight: proxy.size.height
            ) {
                HStack(spacing: 0) {
                    ForEach(0..<viewModel.pageCount, id: \.self) { page in
                        pageGrid(page, design: design, scale: scale)
                            .frame(width: pageWidth, height: proxy.size.height)
                    }
                }
            }
        }
    }

    private func pageGrid(_ page: Int, design: CGSize, scale: CGFloat) -> some View {
        let nodes = Array(viewModel.nodes(on: page))
        let columns = viewModel.columns
        return VStack(spacing: Self.rowSpacing) {
            ForEach(0..<viewModel.rows, id: \.self) { row in
                HStack(spacing: Self.columnSpacing) {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = row * columns + column
                        if index < nodes.count {
                            tile(for: nodes[index])
                                .frame(width: Self.tileWidth, height: Self.tileHeight)
                        } else {
                            Color.clear
                                .frame(width: Self.tileWidth, height: Self.tileHeight)
                        }
                    }
                }
            }
        }
        .frame(width: design.width, height: design.height, alignment: .top)
        .scaleEffect(scale)
        .frame(width: design.width * scale, height: design.height * scale)
    }

    private func tile(for node: ApplicationsGridNode) -> some View {
        ApplicationGridTile(
            node: node,
            isSelected: viewModel.selectedID == node.id,
            isDropTargeted: dropTargetID == node.id,
            onTap: { handleNodeTap(node) },
            onHideApp: { viewModel.hideApplication(appID: $0) },
            onRemoveCustom: { viewModel.removeCustomItem(id: $0) },
            onGroupWithNewFolder: {
                if let sibling = viewModel.nodes(on: viewModel.currentPage).first(where: { $0.id != node.id }) {
                    viewModel.createFolder(
                        combining: node.id,
                        with: sibling.id,
                        name: String(localized: "New Folder")
                    )
                }
            }
        )
        .draggable(node.id)
        .dropDestination(for: String.self) { droppedIDs, _ in
            guard let sourceID = droppedIDs.first, sourceID != node.id else {
                return false
            }
            viewModel.moveNode(draggedID: sourceID, to: node.id)
            return true
        } isTargeted: { isTargeted in
            dropTargetID = isTargeted ? node.id : (dropTargetID == node.id ? nil : dropTargetID)
        }
    }

    private var filteredGrid: some View {
        let items = viewModel.filteredItems
        return Group {
            if items.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "square.grid.3x3")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No matching applications")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 18) {
                        ForEach(items) { item in
                            ApplicationGridTile(
                                node: .item(item),
                                isSelected: viewModel.selectedID == item.id,
                                isDropTargeted: false,
                                onTap: { viewModel.execute(item: item) },
                                onHideApp: { viewModel.hideApplication(appID: $0) },
                                onRemoveCustom: { viewModel.removeCustomItem(id: $0) },
                                onGroupWithNewFolder: {}
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.changePage(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .disabled(viewModel.currentPage == 0)
            .accessibilityLabel(String(localized: "Previous page"))

            HStack(spacing: 2) {
                ForEach(0..<viewModel.pageCount, id: \.self) { index in
                    Button {
                        viewModel.goToPage(index)
                    } label: {
                        Circle()
                            .fill(index == viewModel.currentPage ? Color.primary : Color.primary.opacity(0.25))
                            .frame(width: 7, height: 7)
                            .frame(width: 18, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Page \(index + 1)"))
                    .accessibilityAddTraits(index == viewModel.currentPage ? .isSelected : [])
                }
            }

            Button {
                viewModel.changePage(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .disabled(viewModel.currentPage >= viewModel.pageCount - 1)
            .accessibilityLabel(String(localized: "Next page"))
        }
        .foregroundStyle(.secondary)
        .padding(.bottom, 4)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func folderOverlay(folder: (id: UUID, name: String, items: [ApplicationGridItem])) -> some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.openFolderID = nil
                }

            VStack(spacing: 16) {
                HStack {
                    TextField(String(localized: "Folder Name"), text: $folderRenameText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .onAppear {
                            folderRenameText = folder.name
                        }
                        .onSubmit {
                            viewModel.renameFolder(folder.id, to: folderRenameText)
                        }

                    Button {
                        viewModel.renameFolder(folder.id, to: folderRenameText)
                        viewModel.openFolderID = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)

                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(minimum: 90, maximum: 130), spacing: 14), count: 4),
                        spacing: 14
                    ) {
                        ForEach(folder.items) { item in
                            ApplicationGridTile(
                                node: .item(item),
                                isSelected: viewModel.selectedID == item.id,
                                isDropTargeted: false,
                                onTap: { viewModel.execute(item: item) },
                                onHideApp: { viewModel.hideApplication(appID: $0) },
                                onRemoveCustom: { viewModel.removeCustomItem(id: $0) },
                                onGroupWithNewFolder: {}
                            )
                            .contextMenu {
                                Button("Open") {
                                    viewModel.execute(item: item)
                                }
                                Button("Remove from Folder") {
                                    viewModel.removeItem(item.id, fromFolder: folder.id)
                                }
                            }
                        }
                    }
                    .padding(6)
                }
            }
            .padding(24)
            .frame(width: 560, height: 400)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 24, y: 10)
        }
    }

    private var addCustomSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Custom Item")
                .font(.system(size: 16, weight: .semibold))

            Picker("Type", selection: $customIsWebURL) {
                Text("App or Folder Path").tag(false)
                Text("Web URL").tag(true)
            }
            .pickerStyle(.segmented)

            TextField(String(localized: "Title (e.g. GitHub, Projects)"), text: $customTitle)
                .textFieldStyle(.roundedBorder)

            TextField(
                customIsWebURL
                    ? String(localized: "URL (e.g. https://github.com)")
                    : String(localized: "Path (e.g. /Users/you/Projects)"),
                text: $customTarget
            )
            .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel") {
                    isShowingAddCustom = false
                }
                Button("Add") {
                    viewModel.addCustomItem(
                        title: customTitle,
                        target: customTarget,
                        isWebURL: customIsWebURL
                    )
                    isShowingAddCustom = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    customTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || customTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private var hiddenAppsPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hidden Applications")
                .font(.system(size: 13, weight: .semibold))

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.hiddenApplications) { item in
                        HStack {
                            Text(item.title)
                                .font(.system(size: 12.5))
                            Spacer()
                            if let appID = item.appID {
                                Button("Unhide") {
                                    viewModel.unhideApplication(appID: appID)
                                }
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .padding(14)
        .frame(width: 260)
    }

    private func handleNodeTap(_ node: ApplicationsGridNode) {
        switch node {
        case .item(let item):
            viewModel.execute(item: item)
        case .folder(let id, _, _):
            viewModel.openFolderID = id
            viewModel.selectedID = viewModel.openFolder?.items.first?.id
        }
    }
}

/// Isolates observation of `currentPage` and `swipeOffset` so interactive
/// trackpad drags translate the page strip without re-evaluating tile bodies.
private struct InteractivePagerTrack<Content: View>: View {
    let viewModel: ApplicationsGridViewModel
    let pageWidth: CGFloat
    let pageHeight: CGFloat
    let content: Content

    init(
        viewModel: ApplicationsGridViewModel,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.viewModel = viewModel
        self.pageWidth = pageWidth
        self.pageHeight = pageHeight
        self.content = content()
    }

    var body: some View {
        content
            .offset(x: -CGFloat(viewModel.currentPage) * pageWidth + viewModel.swipeOffset)
            .frame(width: pageWidth, height: pageHeight, alignment: .leading)
            .clipped()
    }
}
