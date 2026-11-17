import SwiftUI

/// Plain text payload with its character, word, and line counters.
struct ClipboardTextPreview: View {
    let text: String
    let characterCount: Int?
    let wordCount: Int?
    let lineCount: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let characterCount {
                    ClipboardMetaPill(text: "\(characterCount) chars")
                }
                if let wordCount {
                    ClipboardMetaPill(text: "\(wordCount) words")
                }
                if let lineCount, lineCount > 1 {
                    ClipboardMetaPill(text: "\(lineCount) lines")
                }
                Spacer()
            }

            ScrollView {
                Text(text)
                    .font(.system(size: 13.5))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }
}
