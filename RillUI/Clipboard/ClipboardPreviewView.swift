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
                ClipboardImagePreview(
                    fileURL: imagesDirectoryURL.appendingPathComponent(fileName)
                )
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

    @ViewBuilder
    private func codePreview(for item: ClipboardItem) -> some View {
        ClipboardCodePreview(
            code: item.textContent ?? "",
            language: item.metadata.codeLanguage,
            lineCount: item.metadata.lineCount,
            characterCount: item.metadata.characterCount
        )
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

    @ViewBuilder
    private func filesPreview(for item: ClipboardItem) -> some View {
        ClipboardFilesPreview(paths: item.metadata.fileURLs ?? [])
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
        ClipboardMetaPill(text: text)
    }

    private func formatByteSize(_ bytes: Int) -> String {
        formatClipboardByteSize(bytes)
    }
}

private struct ClipboardMetaPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(Color.primary.opacity(0.06), in: Capsule())
    }
}

private func formatClipboardByteSize(_ bytes: Int) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(bytes))
}

private struct ClipboardFilesPreview: View {
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

private enum ClipboardCodeHighlighter {
    private static let maxHighlightedLength = 20_000

    static func highlight(_ code: String, language: String?) -> AttributedString {
        var attributed = AttributedString(code)
        attributed.foregroundColor = .primary

        guard code.utf16.count <= maxHighlightedLength, !code.isEmpty else {
            return attributed
        }

        let nsRange = NSRange(code.startIndex..<code.endIndex, in: code)
        let normalizedLanguage = language?.lowercased()

        // Apply from lowest to highest precedence so strings and comments win over tokens inside them.
        applyPattern(#"\b\d+(?:\.\d+)?\b"#, color: .orange, to: &attributed, in: code, range: nsRange)

        if let keywordPattern = keywordRegexPattern(for: normalizedLanguage) {
            applyPattern(keywordPattern, color: .purple, to: &attributed, in: code, range: nsRange)
        }

        if normalizedLanguage == "json" {
            applyPattern(#""([^"\\]|\\.)*"\s*(?=:)"#, color: .blue, to: &attributed, in: code, range: nsRange)
        } else if normalizedLanguage == "html" {
            applyPattern(#"</?[A-Za-z][A-Za-z0-9-]*"#, color: .blue, to: &attributed, in: code, range: nsRange)
        }

        applyPattern(#""([^"\\]|\\.)*"|'([^'\\]|\\.)*'|`([^`\\]|\\.)*`"#, color: .green, to: &attributed, in: code, range: nsRange)

        if normalizedLanguage == "python" || normalizedLanguage == "shell" {
            applyPattern(#"#[^\n]*"#, color: .secondary, to: &attributed, in: code, range: nsRange)
        } else if normalizedLanguage == "html" {
            applyPattern(#"<!--[\s\S]*?-->"#, color: .secondary, to: &attributed, in: code, range: nsRange)
        } else if normalizedLanguage == "sql" {
            applyPattern(#"--[^\n]*"#, color: .secondary, to: &attributed, in: code, range: nsRange)
        } else {
            applyPattern(#"//[^\n]*|/\*[\s\S]*?\*/"#, color: .secondary, to: &attributed, in: code, range: nsRange)
        }

        return attributed
    }

    private static func keywordRegexPattern(for language: String?) -> String? {
        switch language {
        case "json":
            return #"\b(?:true|false|null)\b"#
        case "swift":
            return #"\b(?:import|struct|class|enum|protocol|extension|func|let|var|return|if|else|guard|switch|case|default|for|while|in|async|await|throws|try|catch|public|private|internal|fileprivate|static|final|actor|some|any|true|false|nil|self|Self)\b"#
        case "python":
            return #"\b(?:import|from|as|def|class|return|if|elif|else|for|while|in|with|try|except|finally|raise|async|await|pass|break|continue|lambda|True|False|None|and|or|not|is)\b"#
        case "javascript":
            return #"\b(?:import|export|from|default|const|let|var|function|return|if|else|switch|case|for|while|async|await|try|catch|throw|new|class|extends|true|false|null|undefined)\b"#
        case "sql":
            return #"(?i)\b(?:SELECT|FROM|WHERE|JOIN|LEFT|RIGHT|INNER|OUTER|ON|GROUP|BY|ORDER|HAVING|LIMIT|INSERT|INTO|VALUES|UPDATE|SET|DELETE|CREATE|TABLE|AS|AND|OR|NOT|NULL|DISTINCT)\b"#
        case "shell":
            return #"\b(?:if|then|else|elif|fi|for|do|done|while|case|esac|in|function|export|local|return|exit|echo|cd|git|curl)\b"#
        default:
            return #"\b(?:import|func|def|const|let|var|return|if|else|for|while|class|struct|true|false|null|nil)\b"#
        }
    }

    private static func applyPattern(
        _ pattern: String,
        color: Color,
        to attributed: inout AttributedString,
        in source: String,
        range: NSRange
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        for match in regex.matches(in: source, range: range) {
            guard let stringRange = Range(match.range, in: source),
                  let attrStart = AttributedString.Index(stringRange.lowerBound, within: attributed),
                  let attrEnd = AttributedString.Index(stringRange.upperBound, within: attributed) else {
                continue
            }
            attributed[attrStart..<attrEnd].foregroundColor = color
        }
    }
}

private struct ClipboardCodePreview: View {
    let code: String
    let language: String?
    let lineCount: Int?
    let characterCount: Int?

    var body: some View {
        let lines = code.split(separator: "\n", omittingEmptySubsequences: false)
        let resolvedLineCount = lineCount ?? lines.count
        let gutterWidth = max(24, CGFloat(String(resolvedLineCount).count) * 8 + 10)
        let lineNumbersText = (1...max(1, lines.count)).map(String.init).joined(separator: "\n")
        let highlighted = ClipboardCodeHighlighter.highlight(code, language: language)

        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: language?.lowercased() == "json" ? "curlybraces" : "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(language ?? "Code")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text(resolvedLineCount == 1 ? "1 line" : "\(resolvedLineCount) lines")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)

                if let characterCount {
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text("\(characterCount) chars")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.03))

            Divider()
                .opacity(0.35)

            ScrollView([.horizontal, .vertical]) {
                HStack(alignment: .top, spacing: 0) {
                    Text(lineNumbersText)
                        .font(.system(size: 12.5, design: .monospaced))
                        .lineSpacing(3)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.trailing)
                        .frame(width: gutterWidth, alignment: .trailing)
                        .padding(.vertical, 10)
                        .padding(.trailing, 8)
                        .padding(.leading, 6)

                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 0.5)

                    Text(highlighted)
                        .font(.system(size: 12.5, design: .monospaced))
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
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
