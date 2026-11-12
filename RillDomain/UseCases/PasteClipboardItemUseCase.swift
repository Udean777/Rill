import Foundation

/// Coordinates pasting or copying a clipboard item back to the system pasteboard
/// and optionally issuing a direct paste keystroke.
public struct PasteClipboardItemUseCase: Sendable {
    private let writer: PasteboardWriting
    private let directPaster: DirectPasting?

    public init(writer: PasteboardWriting, directPaster: DirectPasting? = nil) {
        self.writer = writer
        self.directPaster = directPaster
    }

    public func callAsFunction(
        item: ClipboardItem,
        asPlainText: Bool = false,
        imageDirectory: URL? = nil,
        triggerDirectPaste: Bool = true
    ) async throws {
        switch item.contentType {
        case .image:
            if let fileName = item.metadata.imageFileName,
               let imageDir = imageDirectory {
                let fileURL = imageDir.appendingPathComponent(fileName)
                try await writer.writeImage(at: fileURL)
            } else if let text = item.textContent {
                try await writer.writeText(text, richText: nil)
            }

        case .files:
            if let paths = item.metadata.fileURLs {
                let urls = paths.map { URL(fileURLWithPath: $0) }
                try await writer.writeFiles(at: urls)
            } else if let text = item.textContent {
                try await writer.writeText(text, richText: nil)
            }

        case .text, .code, .link, .color:
            if let text = item.textContent {
                let rich = asPlainText ? nil : item.richTextContent
                try await writer.writeText(text, richText: rich)
            }
        }

        if triggerDirectPaste, let directPaster, directPaster.isDirectPasteAvailable() {
            try await directPaster.paste()
        }
    }
}
