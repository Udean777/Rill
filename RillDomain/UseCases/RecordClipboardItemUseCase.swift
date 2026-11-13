import Foundation

/// Processes incoming clipboard entries, classifies rich content types,
/// generates metadata, and persists the item.
public struct RecordClipboardItemUseCase: Sendable {
    private let store: ClipboardStoring

    public init(store: ClipboardStoring) {
        self.store = store
    }

    public func callAsFunction(_ raw: RawClipboardEntry) async {
        guard let item = classify(raw) else { return }
        await store.save(item)
    }

    public func classify(_ raw: RawClipboardEntry) -> ClipboardItem? {
        if let imageFileName = raw.imageFileName, let dimensions = raw.imageDimensions {
            return ClipboardItem(
                id: ClipboardItem.ID(),
                contentType: .image,
                textContent: raw.textContent,
                richTextContent: raw.richTextContent,
                metadata: ClipboardMetadata(
                    imageDimensions: dimensions,
                    imageFileName: imageFileName,
                    byteSize: raw.byteSize
                ),
                sourceApp: raw.sourceApp,
                copiedAt: raw.copiedAt
            )
        }

        if let fileURLs = raw.fileURLs, !fileURLs.isEmpty {
            let fileCount = fileURLs.count
            let summary = fileCount == 1
                ? (URL(fileURLWithPath: fileURLs[0]).lastPathComponent)
                : "\(fileCount) files"
            return ClipboardItem(
                id: ClipboardItem.ID(),
                contentType: .files,
                textContent: summary,
                metadata: ClipboardMetadata(
                    fileURLs: fileURLs,
                    byteSize: raw.byteSize
                ),
                sourceApp: raw.sourceApp,
                copiedAt: raw.copiedAt
            )
        }

        guard let text = raw.textContent?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }

        let lineCount = text.split(separator: "\n", omittingEmptySubsequences: false).count
        let wordCount = text.split(whereSeparator: \.isWhitespace).count
        let charCount = text.count

        if let colorData = Self.detectColor(text) {
            return ClipboardItem(
                id: ClipboardItem.ID(),
                contentType: .color,
                textContent: text,
                richTextContent: raw.richTextContent,
                metadata: ClipboardMetadata(
                    characterCount: charCount,
                    wordCount: wordCount,
                    lineCount: lineCount,
                    colorHex: colorData.hex,
                    colorRGB: colorData.rgb,
                    colorHSL: colorData.hsl
                ),
                sourceApp: raw.sourceApp,
                copiedAt: raw.copiedAt
            )
        }

        if let url = URL(string: text),
           let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme),
           url.host != nil {
            return ClipboardItem(
                id: ClipboardItem.ID(),
                contentType: .link,
                textContent: text,
                richTextContent: raw.richTextContent,
                metadata: ClipboardMetadata(
                    characterCount: charCount,
                    wordCount: wordCount,
                    lineCount: lineCount
                ),
                sourceApp: raw.sourceApp,
                copiedAt: raw.copiedAt
            )
        }

        if let detectedLanguage = Self.detectCodeLanguage(text) {
            return ClipboardItem(
                id: ClipboardItem.ID(),
                contentType: .code,
                textContent: text,
                richTextContent: raw.richTextContent,
                metadata: ClipboardMetadata(
                    characterCount: charCount,
                    wordCount: wordCount,
                    lineCount: lineCount,
                    codeLanguage: detectedLanguage
                ),
                sourceApp: raw.sourceApp,
                copiedAt: raw.copiedAt
            )
        }

        return ClipboardItem(
            id: ClipboardItem.ID(),
            contentType: .text,
            textContent: text,
            richTextContent: raw.richTextContent,
            metadata: ClipboardMetadata(
                characterCount: charCount,
                wordCount: wordCount,
                lineCount: lineCount
            ),
            sourceApp: raw.sourceApp,
            copiedAt: raw.copiedAt
        )
    }

    public static func detectColor(_ input: String) -> (hex: String, rgb: String, hsl: String)? {
        let str = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") {
            let hexChars = str.dropFirst()
            if [3, 4, 6, 8].contains(hexChars.count),
               hexChars.allSatisfy({ $0.isHexDigit }) {
                let normalizedHex = Self.normalizeHex(String(hexChars))
                if let (r, g, b) = Self.rgbFromHex(normalizedHex) {
                    let (h, s, l) = Self.hslFromRGB(r: r, g: g, b: b)
                    return (
                        hex: "#" + normalizedHex.uppercased(),
                        rgb: "rgb(\(r), \(g), \(b))",
                        hsl: "hsl(\(h), \(s)%, \(l)%)"
                    )
                }
            }
        }
        return nil
    }

    private static func normalizeHex(_ hex: String) -> String {
        if hex.count == 3 {
            return hex.map { "\($0)\($0)" }.joined()
        }
        if hex.count == 6 {
            return hex
        }
        return hex
    }

    private static func rgbFromHex(_ hex: String) -> (Int, Int, Int)? {
        guard hex.count >= 6 else { return nil }
        guard let val = UInt64(hex.prefix(6), radix: 16) else { return nil }
        let r = Int((val >> 16) & 0xFF)
        let g = Int((val >> 8) & 0xFF)
        let b = Int(val & 0xFF)
        return (r, g, b)
    }

    private static func hslFromRGB(r: Int, g: Int, b: Int) -> (Int, Int, Int) {
        let rf = Double(r) / 255.0
        let gf = Double(g) / 255.0
        let bf = Double(b) / 255.0

        let maxC = max(rf, gf, bf)
        let minC = min(rf, gf, bf)
        let delta = maxC - minC

        var h: Double = 0
        var s: Double = 0
        let l = (maxC + minC) / 2.0

        if delta != 0 {
            s = l > 0.5 ? delta / (2.0 - maxC - minC) : delta / (maxC + minC)
            if maxC == rf {
                h = ((gf - bf) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxC == gf {
                h = ((bf - rf) / delta) + 2.0
            } else {
                h = ((rf - gf) / delta) + 4.0
            }
            h *= 60.0
            if h < 0 { h += 360.0 }
        }

        return (Int(h.rounded()), Int((s * 100).rounded()), Int((l * 100).rounded()))
    }

    public static func detectCodeLanguage(_ text: String) -> String? {
        if text.hasPrefix("{") && text.hasSuffix("}") && text.contains(":") {
            return "JSON"
        }
        if text.hasPrefix("[") && text.hasSuffix("]") && text.contains(",") {
            return "JSON"
        }
        if text.contains("func ") || text.contains("import Foundation") || text.contains("import SwiftUI") || text.contains("var body: some View") {
            return "Swift"
        }
        if text.contains("def ") && (text.contains(":\n") || text.contains("import ")) {
            return "Python"
        }
        if (text.contains("const ") || text.contains("let ")) && (text.contains("=>") || text.contains("function")) {
            return "JavaScript"
        }
        if text.contains("<html") || text.contains("</div>") || text.contains("</") {
            return "HTML"
        }
        if text.contains("SELECT ") && text.contains(" FROM ") {
            return "SQL"
        }
        if text.contains("curl ") || text.contains("git ") || text.hasPrefix("#!/bin/") {
            return "Shell"
        }
        return nil
    }
}

public struct RawClipboardEntry: Sendable {
    public var textContent: String?
    public var richTextContent: String?
    public var imageFileName: String?
    public var imageDimensions: ImageDimensions?
    public var fileURLs: [String]?
    public var byteSize: Int?
    public var sourceApp: ClipboardSourceApp?
    public var copiedAt: Date

    public init(
        textContent: String? = nil,
        richTextContent: String? = nil,
        imageFileName: String? = nil,
        imageDimensions: ImageDimensions? = nil,
        fileURLs: [String]? = nil,
        byteSize: Int? = nil,
        sourceApp: ClipboardSourceApp? = nil,
        copiedAt: Date
    ) {
        self.textContent = textContent
        self.richTextContent = richTextContent
        self.imageFileName = imageFileName
        self.imageDimensions = imageDimensions
        self.fileURLs = fileURLs
        self.byteSize = byteSize
        self.sourceApp = sourceApp
        self.copiedAt = copiedAt
    }
}
