import AppKit
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
            codePreview(for: item)
        case .link:
            linkPreview(for: item)
        case .files:
            filesPreview(for: item)
        case .text:
            textPreview(for: item)
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
                let fileURL = imagesDirectoryURL.appendingPathComponent(fileName)
                if let nsImage = NSImage(contentsOf: fileURL) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                }
            }

            HStack(spacing: 8) {
                if let dims = item.metadata.imageDimensions {
                    metaPill("\(dims.width) × \(dims.height) px")
                }
                if let bytes = item.metadata.byteSize {
                    metaPill(formatByteSize(bytes))
                }
            }
        }
    }

    // MARK: - Code Preview

    private func codePreview(for item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let lang = item.metadata.codeLanguage {
                    metaPill(lang)
                }
                if let lines = item.metadata.lineCount {
                    metaPill("\(lines) lines")
                }
                Spacer()
            }

            ScrollView([.horizontal, .vertical]) {
                Text(item.textContent ?? "")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(10)
            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
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

    // MARK: - Files Preview

    private func filesPreview(for item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let files = item.metadata.fileURLs {
                Text("\(files.count) files")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(files, id: \.self) { path in
                            HStack(spacing: 8) {
                                Image(systemName: "doc")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                Text(URL(fileURLWithPath: path).lastPathComponent)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Text Preview

    private func textPreview(for item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let chars = item.metadata.characterCount {
                    metaPill("\(chars) chars")
                }
                if let words = item.metadata.wordCount {
                    metaPill("\(words) words")
                }
                if let lines = item.metadata.lineCount, lines > 1 {
                    metaPill("\(lines) lines")
                }
                Spacer()
            }

            ScrollView {
                Text(item.textContent ?? "")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
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

    private func metaPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(Color.primary.opacity(0.06), in: Capsule())
    }

    private func formatByteSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
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
