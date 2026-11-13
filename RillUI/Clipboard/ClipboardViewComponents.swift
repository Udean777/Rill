import AppKit
import QuickLookThumbnailing
import RillDomain
import SwiftUI
import UniformTypeIdentifiers

extension Color {
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

struct ClipboardFileDetails: Identifiable, Sendable, Equatable {
    var id: String { url.path }
    let url: URL
    let name: String
    let parentPath: String
    let fileExtension: String
    let kindDescription: String?
    let byteSize: Int?
    let isDirectory: Bool
    let exists: Bool
    let isPermissionDenied: Bool
    let isImage: Bool
}

actor ClipboardFileInspector {
    static let shared = ClipboardFileInspector()

    func inspect(paths: [String]) -> [ClipboardFileDetails] {
        paths.map { inspect(path: $0) }
    }

    func inspect(path: String) -> ClipboardFileDetails {
        let url = URL(fileURLWithPath: path)
        let exists = FileManager.default.fileExists(atPath: url.path)
        let ext = url.pathExtension
        let isImage = Self.isImageExtension(ext)
        let parentPath = (url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath

        guard exists else {
            let permissionDenied = Self.isPermissionError(for: url)
            return ClipboardFileDetails(
                url: url,
                name: url.lastPathComponent,
                parentPath: parentPath,
                fileExtension: ext,
                kindDescription: nil,
                byteSize: nil,
                isDirectory: false,
                exists: false,
                isPermissionDenied: permissionDenied,
                isImage: isImage
            )
        }

        let keys: Set<URLResourceKey> = [
            .fileSizeKey,
            .localizedTypeDescriptionKey,
            .isDirectoryKey,
        ]
        let values = try? url.resourceValues(forKeys: keys)
        let isDirectory = values?.isDirectory ?? false

        return ClipboardFileDetails(
            url: url,
            name: url.lastPathComponent,
            parentPath: parentPath,
            fileExtension: ext,
            kindDescription: values?.localizedTypeDescription,
            byteSize: isDirectory ? nil : values?.fileSize,
            isDirectory: isDirectory,
            exists: true,
            isPermissionDenied: false,
            isImage: !isDirectory && isImage
        )
    }

    private static func isPermissionError(for url: URL) -> Bool {
        do {
            _ = try url.checkResourceIsReachable()
            return false
        } catch let error as CocoaError {
            return error.code == .fileReadNoPermission
        } catch let error as NSError {
            return error.domain == NSPOSIXErrorDomain
                && (error.code == Int(EPERM) || error.code == Int(EACCES))
        }
    }

    private static func isImageExtension(_ fileExtension: String) -> Bool {
        if ClipboardFileKind.isImageExtension(fileExtension) {
            return true
        }
        guard !fileExtension.isEmpty,
              let utType = UTType(filenameExtension: fileExtension) else {
            return false
        }
        return utType.conforms(to: .image)
    }
}

private actor ClipboardImageLoader {
    static let shared = ClipboardImageLoader()

    func load(at url: URL, maxPixelDimension: CGFloat = 800) async -> (image: NSImage, dimensions: ImageDimensions?)? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        if let direct = NSImage(contentsOf: url), direct.size.width > 0, direct.size.height > 0 {
            let dimensions = extractDimensions(from: direct)
            return (direct, dimensions)
        }

        // Fall back to QuickLook for formats NSImage does not decode directly (e.g. SVG, AVIF, JXL, RAW).
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: maxPixelDimension, height: maxPixelDimension),
            scale: 2.0,
            representationTypes: .thumbnail
        )
        guard let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) else {
            return nil
        }
        let thumbnail = representation.nsImage
        let dimensions = extractDimensions(from: thumbnail)
        return (thumbnail, dimensions)
    }

    private func extractDimensions(from image: NSImage) -> ImageDimensions? {
        if let rep = image.representations.first, rep.pixelsWide > 0, rep.pixelsHigh > 0 {
            return ImageDimensions(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        let width = Int(image.size.width.rounded())
        let height = Int(image.size.height.rounded())
        guard width > 0, height > 0 else { return nil }
        return ImageDimensions(width: width, height: height)
    }
}

struct ClipboardImagePreview: View {
    private enum LoadState {
        case loading
        case loaded(NSImage)
        case unavailable
    }

    let fileURL: URL
    var maxHeight: CGFloat = 220
    var onDimensionsLoaded: ((ImageDimensions) -> Void)?

    @State private var state: LoadState = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.03))
                    .frame(maxWidth: .infinity)
                    .frame(height: min(maxHeight, 120))
                    .overlay {
                        ProgressView()
                            .controlSize(.small)
                    }
            case .loaded(let image):
                ZStack {
                    Color.primary.opacity(0.03)
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(4)
                }
                .frame(maxWidth: .infinity, maxHeight: maxHeight, alignment: .center)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
            case .unavailable:
                VStack(spacing: 6) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                    Text("Preview unavailable")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: min(maxHeight, 110))
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            }
        }
        .task(id: fileURL) {
            state = .loading
            if let result = await ClipboardImageLoader.shared.load(at: fileURL) {
                state = .loaded(result.image)
                if let dimensions = result.dimensions {
                    onDimensionsLoaded?(dimensions)
                }
            } else {
                state = .unavailable
            }
        }
    }
}

struct ClipboardRowView: View {
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            typeIcon
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(rowTitle)
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
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
        }
        .contentShape(Rectangle())
    }

    private var rowTitle: String {
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
    private var typeIcon: some View {
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
}
