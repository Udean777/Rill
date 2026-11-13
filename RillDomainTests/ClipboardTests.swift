import Foundation
import RillDomain
import Testing

@Suite("Clipboard Classification & Entities")
struct ClipboardClassificationTests {
    private let store = FakeClipboardStore()

    @Test
    func classifiesHexColor() {
        let useCase = RecordClipboardItemUseCase(store: store)
        let item = useCase.classify(RawClipboardEntry(textContent: "#3B82F6", copiedAt: .distantPast))

        #expect(item != nil)
        #expect(item?.contentType == .color)
        #expect(item?.metadata.colorHex == "#3B82F6")
        #expect(item?.metadata.colorRGB != nil)
        #expect(item?.metadata.colorHSL != nil)
    }

    @Test
    func classifiesShortHexColor() {
        let useCase = RecordClipboardItemUseCase(store: store)
        let item = useCase.classify(RawClipboardEntry(textContent: "#fff", copiedAt: .distantPast))

        #expect(item != nil)
        #expect(item?.contentType == .color)
        #expect(item?.metadata.colorHex == "#FFFFFF")
    }

    @Test
    func classifiesWebURL() {
        let useCase = RecordClipboardItemUseCase(store: store)
        let item = useCase.classify(RawClipboardEntry(textContent: "https://github.com/apple/swift", copiedAt: .distantPast))

        #expect(item != nil)
        #expect(item?.contentType == .link)
        #expect(item?.textContent == "https://github.com/apple/swift")
    }

    @Test
    func classifiesCodeSnippets() {
        let useCase = RecordClipboardItemUseCase(store: store)

        let swiftCode = useCase.classify(RawClipboardEntry(textContent: "import SwiftUI\nfunc greet() {}", copiedAt: .distantPast))
        #expect(swiftCode?.contentType == .code)
        #expect(swiftCode?.metadata.codeLanguage == "Swift")

        let jsonCode = useCase.classify(RawClipboardEntry(textContent: "{\"key\": \"value\"}", copiedAt: .distantPast))
        #expect(jsonCode?.contentType == .code)
        #expect(jsonCode?.metadata.codeLanguage == "JSON")

        let jsArrow = useCase.classify(RawClipboardEntry(textContent: "const add = (a, b) => a + b", copiedAt: .distantPast))
        #expect(jsArrow?.contentType == .code)
        #expect(jsArrow?.metadata.codeLanguage == "JavaScript")

        let nonJSConst = useCase.classify(RawClipboardEntry(textContent: "const count = 42", copiedAt: .distantPast))
        #expect(nonJSConst?.contentType == .text)
        #expect(nonJSConst?.metadata.codeLanguage == nil)
    }

    @Test
    func classifiesPlainText() {
        let useCase = RecordClipboardItemUseCase(store: store)
        let item = useCase.classify(RawClipboardEntry(textContent: "Just a regular note to remember later.", copiedAt: .distantPast))

        #expect(item != nil)
        #expect(item?.contentType == .text)
        #expect(item?.metadata.wordCount == 7)
        #expect(item?.metadata.lineCount == 1)
    }

    @Test
    func classifiesFiles() {
        let useCase = RecordClipboardItemUseCase(store: store)
        let item = useCase.classify(RawClipboardEntry(fileURLs: ["/Users/test/Doc.pdf", "/Users/test/Photo.png"], copiedAt: .distantPast))

        #expect(item != nil)
        #expect(item?.contentType == .files)
        #expect(item?.metadata.fileURLs?.count == 2)
        #expect(item?.textContent == "2 files")
    }

    @Test(arguments: [
        "/tmp/photo.png",
        "/tmp/photo.JPG",
        "/tmp/photo.jpeg",
        "/tmp/anim.gif",
        "/tmp/banner.webp",
        "/tmp/portrait.heic",
        "/tmp/portrait.heif",
        "/tmp/vector.svg",
        "/tmp/modern.avif",
        "/tmp/next.jxl",
        "/tmp/scan.tiff",
        "/tmp/bitmap.bmp",
        "/tmp/favicon.ico",
        "/tmp/camera.dng",
        "/tmp/camera.cr2",
    ])
    func `identifies image file paths across extensions`(path: String) {
        #expect(ClipboardFileKind.isImageFile(atPath: path))
    }

    @Test(arguments: [
        "/tmp/report.pdf",
        "/tmp/archive.zip",
        "/tmp/notes.txt",
        "/tmp/App.swift",
        "/tmp/folder",
        "",
    ])
    func `rejects non-image file paths`(path: String) {
        #expect(!ClipboardFileKind.isImageFile(atPath: path))
    }

    @Test
    func `normalizes leading dot and whitespace in extensions`() {
        #expect(ClipboardFileKind.isImageExtension(".PNG"))
        #expect(ClipboardFileKind.isImageExtension(" webp "))
        #expect(!ClipboardFileKind.isImageExtension(""))
        #expect(!ClipboardFileKind.isImageExtension("pdf"))
    }
}

@Suite("Clipboard Search & Filtering")
struct ClipboardSearchTests {
    @Test
    func filtersBySearchQueryAndFilterType() async {
        let store = FakeClipboardStore()
        let textItem = ClipboardItem(
            id: ClipboardItem.ID(),
            contentType: .text,
            textContent: "Meeting notes with engineering",
            copiedAt: Date()
        )
        let linkItem = ClipboardItem(
            id: ClipboardItem.ID(),
            contentType: .link,
            textContent: "https://news.ycombinator.com",
            copiedAt: Date()
        )
        let pinnedCode = ClipboardItem(
            id: ClipboardItem.ID(),
            contentType: .code,
            textContent: "func add(a: Int, b: Int) -> Int { a + b }",
            copiedAt: Date(),
            isPinned: true
        )

        await store.save(textItem)
        await store.save(linkItem)
        await store.save(pinnedCode)

        let search = SearchClipboardUseCase(store: store)

        let allResults = await search(query: "", filter: .all)
        #expect(allResults.count == 3)

        let textOnly = await search(query: "", filter: .text)
        #expect(textOnly.count == 1)
        #expect(textOnly.first?.contentType == .text)

        let linksOnly = await search(query: "", filter: .links)
        #expect(linksOnly.count == 1)
        #expect(linksOnly.first?.contentType == .link)

        let pinnedOnly = await search(query: "", filter: .pinned)
        #expect(pinnedOnly.count == 1)
        #expect(pinnedOnly.first?.isPinned == true)

        let queryMatched = await search(query: "engineering", filter: .all)
        #expect(queryMatched.count == 1)
        #expect(queryMatched.first?.textContent?.contains("Meeting") == true)
    }
}

private actor FakeClipboardStore: ClipboardStoring {
    private var stored: [ClipboardItem] = []

    func items(matching query: String, filter: ClipboardFilter, limit: Int) async -> [ClipboardItem] {
        stored.filter { item in
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .text: matchesFilter = item.contentType == .text
            case .code: matchesFilter = item.contentType == .code
            case .images: matchesFilter = item.contentType == .image
            case .links: matchesFilter = item.contentType == .link
            case .colors: matchesFilter = item.contentType == .color
            case .files: matchesFilter = item.contentType == .files
            case .pinned: matchesFilter = item.isPinned
            }
            guard matchesFilter else { return false }
            if query.isEmpty { return true }
            return (item.textContent ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    func save(_ item: ClipboardItem) async {
        stored.removeAll { $0.id == item.id }
        stored.insert(item, at: 0)
    }

    func delete(id: ClipboardItem.ID) async {
        stored.removeAll { $0.id == id }
    }

    func togglePin(id: ClipboardItem.ID) async {
        if let idx = stored.firstIndex(where: { $0.id == id }) {
            stored[idx].isPinned.toggle()
        }
    }

    func clearHistory(keepingPinned: Bool) async {
        if keepingPinned {
            stored.removeAll { !$0.isPinned }
        } else {
            stored.removeAll()
        }
    }

    func itemCount() async -> Int {
        stored.count
    }
}
