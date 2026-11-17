import Foundation
import Testing

@testable import RillDomain

@Suite("RecordClipboardItemUseCase colour detection")
struct ClipboardColorDetectionTests {
    @Test func `short hex expands and converts to rgb and hsl`() {
        let detected = RecordClipboardItemUseCase.detectColor("#fff")

        #expect(detected?.hex == "#FFFFFF")
        #expect(detected?.rgb == "rgb(255, 255, 255)")
        #expect(detected?.hsl == "hsl(0, 0%, 100%)")
    }

    @Test func `six digit hex keeps its channels`() {
        let detected = RecordClipboardItemUseCase.detectColor("  #3498db  ")

        #expect(detected?.hex == "#3498DB")
        #expect(detected?.rgb == "rgb(52, 152, 219)")
        #expect(detected?.hsl == "hsl(204, 70%, 53%)")
    }

    @Test func `non-colour text is not classified`() {
        #expect(RecordClipboardItemUseCase.detectColor("#12") == nil)
        #expect(RecordClipboardItemUseCase.detectColor("#gggggg") == nil)
        #expect(RecordClipboardItemUseCase.detectColor("hello") == nil)
    }
}

@Suite("RecordClipboardItemUseCase language detection")
struct ClipboardLanguageDetectionTests {
    @Test func `json needs matching braces and a separator`() {
        #expect(RecordClipboardItemUseCase.detectCodeLanguage(#"{"name": "Rill"}"#) == "JSON")
        #expect(RecordClipboardItemUseCase.detectCodeLanguage("[1, 2, 3]") == "JSON")
        #expect(RecordClipboardItemUseCase.detectCodeLanguage("plain text") == nil)
    }

    @Test func `known languages are recognised`() {
        #expect(RecordClipboardItemUseCase.detectCodeLanguage("import SwiftUI\nstruct A {}") == "Swift")
        #expect(RecordClipboardItemUseCase.detectCodeLanguage("def greet():\n    return 1") == "Python")
        #expect(
            RecordClipboardItemUseCase.detectCodeLanguage("const f = () => 1")
                == "JavaScript"
        )
        #expect(RecordClipboardItemUseCase.detectCodeLanguage("<html></html>") == "HTML")
        #expect(RecordClipboardItemUseCase.detectCodeLanguage("SELECT a FROM b") == "SQL")
        #expect(RecordClipboardItemUseCase.detectCodeLanguage("git status") == "Shell")
    }

    @Test func `prose with no syntax markers stays plain text`() {
        #expect(RecordClipboardItemUseCase.detectCodeLanguage("Catatan rapat hari ini.") == nil)
    }
}
