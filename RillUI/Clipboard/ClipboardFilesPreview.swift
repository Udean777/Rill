import AppKit
import RillDomain
import SwiftUI

/// File payload preview: a single item, or a list with an image spotlight.
struct ClipboardFilesPreview: View {
    let paths: [String]

    @State private var files: [ClipboardFileDetails] = []
    @State private var selectedImagePath: String?
    @State private var loadedDimensions: [String: ImageDimensions] = [:]

    var body: some View {
        Group {
            if paths.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "doc")
                        .font(.system(size: 22))
                        .foregroundStyle(.tertiary)
                    Text("No files recorded")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if files.count == 1, let file = files.first {
                singleFilePreview(file)
            } else if !files.isEmpty {
                multiFilePreview
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: paths) {
            loadedDimensions = [:]
            let inspected = await ClipboardFileInspector.shared.inspect(paths: paths)
            files = inspected
            selectedImagePath = inspected.first(where: { $0.isImage && $0.exists })?.id
                ?? inspected.first(where: \.isImage)?.id
        }
    }

    @ViewBuilder
    private func singleFilePreview(_ file: ClipboardFileDetails) -> some View {
        if file.isImage {
            VStack(alignment: .leading, spacing: 10) {
                if file.exists {
                    ClipboardImagePreview(
                        fileURL: file.url,
                        maxHeight: 195,
                        onDimensionsLoaded: { dimensions in
                            loadedDimensions[file.id] = dimensions
                        }
                    )
                } else {
                    missingFileBanner(for: file)
                }

                fileMetadataPills(for: file)

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(file.parentPath)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(nsImage: IconCache.shared.image(for: file.url))
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .textSelection(.enabled)

                        fileMetadataPills(for: file)
                    }

                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Location")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(file.parentPath)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                if !file.exists {
                    missingFileBanner(for: file)
                }
            }
        }
    }

    private var multiFilePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(files.count == 1 ? "1 file" : "\(files.count) files")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                let imageCount = files.filter(\.isImage).count
                if imageCount > 0 {
                    ClipboardMetaPill(text: imageCount == 1 ? "1 image" : "\(imageCount) images")
                }

                Spacer()
            }

            if let activeImage = activeImageFile {
                VStack(alignment: .leading, spacing: 4) {
                    if activeImage.exists {
                        ClipboardImagePreview(
                            fileURL: activeImage.url,
                            maxHeight: 135,
                            onDimensionsLoaded: { dimensions in
                                loadedDimensions[activeImage.id] = dimensions
                            }
                        )
                    } else {
                        missingFileBanner(for: activeImage)
                    }

                    HStack(spacing: 6) {
                        Text(activeImage.name)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        if let dims = loadedDimensions[activeImage.id] {
                            Text("\(dims.width) × \(dims.height) px")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(files) { file in
                        multiFileRow(file)
                    }
                }
            }
        }
    }

    private var activeImageFile: ClipboardFileDetails? {
        if let selectedImagePath,
           let matched = files.first(where: { $0.id == selectedImagePath && $0.isImage }) {
            return matched
        }
        return files.first(where: \.isImage)
    }

    @ViewBuilder
    private func multiFileRow(_ file: ClipboardFileDetails) -> some View {
        let isSelectedImage = file.isImage && file.id == activeImageFile?.id
        let rowContent = HStack(spacing: 8) {
            Image(nsImage: IconCache.shared.image(for: file.url))
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .font(.system(size: 12.5, weight: isSelectedImage ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(file.parentPath)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 4)

            if !file.exists {
                Text(file.isPermissionDenied ? "Permission required" : "Missing")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.orange)
            } else if let byteSize = file.byteSize {
                Text(formatClipboardByteSize(byteSize))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            isSelectedImage ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.03),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .contentShape(Rectangle())

        if file.isImage {
            Button {
                selectedImagePath = file.id
            } label: {
                rowContent
            }
            .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    private func fileMetadataPills(for file: ClipboardFileDetails) -> some View {
        HStack(spacing: 6) {
            if let dims = loadedDimensions[file.id] {
                ClipboardMetaPill(text: "\(dims.width) × \(dims.height) px")
            }
            if let byteSize = file.byteSize {
                ClipboardMetaPill(text: formatClipboardByteSize(byteSize))
            }
            if !file.fileExtension.isEmpty {
                ClipboardMetaPill(text: file.fileExtension.uppercased())
            } else if let kind = file.kindDescription, !kind.isEmpty {
                ClipboardMetaPill(text: kind)
            }
        }
    }

    private func missingFileBanner(for file: ClipboardFileDetails) -> some View {
        HStack(spacing: 6) {
            Image(systemName: file.isPermissionDenied ? "lock.shield" : "exclamationmark.triangle")
                .font(.system(size: 12))
                .foregroundStyle(.orange)
            Text(file.isPermissionDenied ? "Folder permission required to preview" : "File not found on disk")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }
}
