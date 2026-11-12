import Foundation

/// A recorded entry from the macOS system pasteboard.
public struct ClipboardItem: Identifiable, Sendable, Hashable, Codable {
    public struct ID: Hashable, Sendable, Codable {
        public let raw: UUID

        public init(raw: UUID = UUID()) {
            self.raw = raw
        }
    }

    public enum ContentType: String, Sendable, Codable, CaseIterable {
        case text
        case code
        case link
        case color
        case image
        case files
    }

    public let id: ID
    public let contentType: ContentType
    public let textContent: String?
    public let richTextContent: String?
    public let metadata: ClipboardMetadata
    public let sourceApp: ClipboardSourceApp?
    public let copiedAt: Date
    public var isPinned: Bool

    public init(
        id: ID = ID(),
        contentType: ContentType,
        textContent: String? = nil,
        richTextContent: String? = nil,
        metadata: ClipboardMetadata = .empty,
        sourceApp: ClipboardSourceApp? = nil,
        copiedAt: Date,
        isPinned: Bool = false
    ) {
        self.id = id
        self.contentType = contentType
        self.textContent = textContent
        self.richTextContent = richTextContent
        self.metadata = metadata
        self.sourceApp = sourceApp
        self.copiedAt = copiedAt
        self.isPinned = isPinned
    }
}

public struct ClipboardMetadata: Sendable, Hashable, Codable {
    public var characterCount: Int?
    public var wordCount: Int?
    public var lineCount: Int?
    public var codeLanguage: String?
    public var colorHex: String?
    public var colorRGB: String?
    public var colorHSL: String?
    public var imageDimensions: ImageDimensions?
    public var imageFileName: String?
    public var fileURLs: [String]?
    public var byteSize: Int?

    public init(
        characterCount: Int? = nil,
        wordCount: Int? = nil,
        lineCount: Int? = nil,
        codeLanguage: String? = nil,
        colorHex: String? = nil,
        colorRGB: String? = nil,
        colorHSL: String? = nil,
        imageDimensions: ImageDimensions? = nil,
        imageFileName: String? = nil,
        fileURLs: [String]? = nil,
        byteSize: Int? = nil
    ) {
        self.characterCount = characterCount
        self.wordCount = wordCount
        self.lineCount = lineCount
        self.codeLanguage = codeLanguage
        self.colorHex = colorHex
        self.colorRGB = colorRGB
        self.colorHSL = colorHSL
        self.imageDimensions = imageDimensions
        self.imageFileName = imageFileName
        self.fileURLs = fileURLs
        self.byteSize = byteSize
    }

    public static let empty = ClipboardMetadata()
}

public struct ImageDimensions: Sendable, Hashable, Codable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public struct ClipboardSourceApp: Sendable, Hashable, Codable {
    public let name: String
    public let bundleID: String

    public init(name: String, bundleID: String) {
        self.name = name
        self.bundleID = bundleID
    }
}

public enum ClipboardFilter: String, Sendable, CaseIterable, Identifiable {
    case all = "All"
    case text = "Text"
    case code = "Code"
    case images = "Images"
    case links = "Links"
    case colors = "Colors"
    case files = "Files"
    case pinned = "Pinned"

    public var id: String { rawValue }
}
