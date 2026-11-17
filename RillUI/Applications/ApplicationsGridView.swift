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
        .sheet(isPresented: $isShowingAddCustom) {
            addCustomSheet
        }
        .popover(isPresented: $isShowingHiddenApps) {
            hiddenAppsPopover
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Spacer()

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

            Spacer()

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
        }
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 90, maximum: 140), spacing: 18),
            count: viewModel.columns
        )
    }

    private var pagedGrid: some View {
        VStack {
            LazyVGrid(columns: gridColumns, spacing: 22) {
                ForEach(viewModel.pagedNodes) { node in
                    ApplicationGridTile(
                        node: node,
                        isSelected: viewModel.selectedID == node.id,
                        isDropTargeted: dropTargetID == node.id,
                        onTap: { handleNodeTap(node) },
                        onHideApp: { viewModel.hideApplication(appID: $0) },
                        onRemoveCustom: { viewModel.removeCustomItem(id: $0) },
                        onGroupWithNewFolder: {
                            if let sibling = viewModel.pagedNodes.first(where: { $0.id != node.id }) {
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
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Spacer(minLength: 0)
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.18),
            value: viewModel.currentPage
        )
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

            ForEach(0..<viewModel.pageCount, id: \.self) { index in
                Circle()
                    .fill(index == viewModel.currentPage ? Color.primary : Color.primary.opacity(0.25))
                    .frame(width: 7, height: 7)
                    .onTapGesture {
                        viewModel.currentPage = index
                    }
            }

            Button {
                viewModel.changePage(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .disabled(viewModel.currentPage >= viewModel.pageCount - 1)
        }
        .foregroundStyle(.secondary)
        .padding(.bottom, 4)
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
