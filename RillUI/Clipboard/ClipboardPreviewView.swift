import RillDomain
import SwiftUI

/// Rich inspector for a selected clipboard item: text, code, color, image, link, files.
public struct ClipboardPreviewView: View {
    let item: ClipboardItem?
    let imagesDirectoryURL: URL

    public init(item: ClipboardItem?, imagesDirectoryURL: URL) {
        self.item = item
        self.imagesDirectoryURL = imagesDirectoryURL
    }

    public var body: some View {
        Group {
            if let item {
                VStack(alignment: .leading, spacing: 10) {
                    contentArea(for: item)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    Divider()
                        .opacity(0.4)

                    footerMetadata(for: item)
                }
                .padding(12)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("No item selected")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.primary.opacity(0.02))
    }

    @ViewBuilder
    private func contentArea(for item: ClipboardItem) -> some View {
        switch item.contentType {
        case .color:
            colorPreview(for: item)
        case .image:
            imagePreview(for: item)
        case .code:
            ClipboardCodePreview(
                code: item.textContent ?? "",
                language: item.metadata.codeLanguage,
                lineCount: item.metadata.lineCount,
                characterCount: item.metadata.characterCount
            )
        case .link:
            linkPreview(for: item)
        case .files:
            ClipboardFilesPreview(paths: item.metadata.fileURLs ?? [])
        case .text:
            ClipboardTextPreview(
                text: item.textContent ?? "",
                characterCount: item.metadata.characterCount,
                wordCount: item.metadata.wordCount,
                lineCount: item.metadata.lineCount
            )
        }
    }

    // MARK: - Color Preview

    private func colorPreview(for item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let hex = item.metadata.colorHex ?? item.textContent ?? "#000000"
            let color = Color(hex: hex)

            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 6) {
                if let hex = item.metadata.colorHex {
                    colorDetailRow(label: "HEX", value: hex)
                }
                if let rgb = item.metadata.colorRGB {
                    colorDetailRow(label: "RGB", value: rgb)
                }
                if let hsl = item.metadata.colorHSL {
                    colorDetailRow(label: "HSL", value: hsl)
                }
            }
        }
    }

    private func colorDetailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Image Preview

    private func imagePreview(for item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let fileName = item.metadata.imageFileName {
                ClipboardImagePreview(
                    fileURL: imagesDirectoryURL.appendingPathComponent(fileName)
                )
            }

            HStack(spacing: 8) {
                if let dims = item.metadata.imageDimensions {
                    ClipboardMetaPill(text: "\(dims.width) × \(dims.height) px")
                }
                if let bytes = item.metadata.byteSize {
                    ClipboardMetaPill(text: formatClipboardByteSize(bytes))
                }
            }
        }
    }

    // MARK: - Link Preview

    private func linkPreview(for item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "link")
                    .font(.system(size: 13))
                    .foregroundStyle(.blue)

                if let url = URL(string: item.textContent ?? ""), let host = url.host {
                    Text(host)
                        .font(.system(size: 14.5, weight: .semibold))
                }
            }

            Text(item.textContent ?? "")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    // MARK: - Footer

    private func footerMetadata(for item: ClipboardItem) -> some View {
        HStack(spacing: 6) {
            if let app = item.sourceApp {
                Image(systemName: "app.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(app.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("•")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Text(item.copiedAt, style: .relative)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()

            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }
        }
    }
}

#Preview("Code Snippet") {
    ClipboardPreviewView(
        item: ClipboardItem(
            contentType: .code,
            textContent: """
            import SwiftUI

            // Sample view
            struct GreetingView: View {
                let count = 42
                var body: some View {
                    Text("Hello, Rill")
                }
            }
            """,
            metadata: ClipboardMetadata(characterCount: 158, lineCount: 9, codeLanguage: "Swift"),
            sourceApp: ClipboardSourceApp(name: "Xcode", bundleID: "com.apple.dt.Xcode"),
            copiedAt: Date()
        ),
        imagesDirectoryURL: URL(fileURLWithPath: "/tmp")
    )
    .frame(width: 380, height: 340)
}

#Preview("Plain Text") {
    ClipboardPreviewView(
        item: ClipboardItem(
            contentType: .text,
            textContent: "Catatan rapat hari ini: pastikan preview clipboard menyesuaikan jenis item.",
            metadata: ClipboardMetadata(characterCount: 73, wordCount: 10, lineCount: 1),
            sourceApp: ClipboardSourceApp(name: "Notes", bundleID: "com.apple.Notes"),
            copiedAt: Date()
        ),
        imagesDirectoryURL: URL(fileURLWithPath: "/tmp")
    )
    .frame(width: 380, height: 340)
}

#Preview("Single File") {
    ClipboardPreviewView(
        item: ClipboardItem(
            contentType: .files,
            textContent: "Architecture.pdf",
            metadata: ClipboardMetadata(fileURLs: ["/Users/example/Documents/Architecture.pdf"]),
            sourceApp: ClipboardSourceApp(name: "Finder", bundleID: "com.apple.finder"),
            copiedAt: Date()
        ),
        imagesDirectoryURL: URL(fileURLWithPath: "/tmp")
    )
    .frame(width: 380, height: 340)
}

#Preview("Image File") {
    ClipboardPreviewView(
        item: ClipboardItem(
            contentType: .files,
            textContent: "banner.webp",
            metadata: ClipboardMetadata(fileURLs: ["/Users/example/Desktop/banner.webp"]),
            sourceApp: ClipboardSourceApp(name: "Finder", bundleID: "com.apple.finder"),
            copiedAt: Date()
        ),
        imagesDirectoryURL: URL(fileURLWithPath: "/tmp")
    )
    .frame(width: 380, height: 340)
}
