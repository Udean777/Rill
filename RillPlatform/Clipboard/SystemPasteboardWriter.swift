import AppKit
import os
import RillDomain

/// Writes clipboard content back to `NSPasteboard.general` with transient flags.
@MainActor
public final class SystemPasteboardWriter: PasteboardWriting {
    private let log = Logger(subsystem: "com.ssajudn.Rill", category: "pasteboardWriter")
    private let pasteboard = NSPasteboard.general
    public var onWillWrite: ((Int) -> Void)?

    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    public init() {}

    public nonisolated func writeText(_ text: String, richText: String?) async throws {
        await MainActor.run {
            pasteboard.clearContents()
            onWillWrite?(pasteboard.changeCount + 1)

            pasteboard.setString(text, forType: .string)
            if let richText {
                pasteboard.setString(richText, forType: .rtf)
            }
            pasteboard.setData(Data(), forType: Self.transientType)
        }
    }

    public nonisolated func writeImage(at fileURL: URL) async throws {
        await MainActor.run {
            guard let image = NSImage(contentsOf: fileURL) else { return }
            pasteboard.clearContents()
            onWillWrite?(pasteboard.changeCount + 1)

            pasteboard.writeObjects([image])
            pasteboard.setData(Data(), forType: Self.transientType)
        }
    }

    public nonisolated func writeFiles(at urls: [URL]) async throws {
        await MainActor.run {
            pasteboard.clearContents()
            onWillWrite?(pasteboard.changeCount + 1)

            pasteboard.writeObjects(urls as [NSURL])
            pasteboard.setData(Data(), forType: Self.transientType)
        }
    }
}
