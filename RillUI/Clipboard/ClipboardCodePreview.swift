import SwiftUI

/// Code payload with a line-number gutter and lightweight syntax colours.
struct ClipboardCodePreview: View {
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
