import SwiftUI

/// Contextual empty state shown when a query yields no results (Things 3 & Raycast inspiration).
struct EmptyResultView: View {
    let query: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 2)

            Text("No results for “\(query.trimmingCharacters(in: .whitespacesAndNewlines))”")
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(.primary)

            Text(suggestionText)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: 340)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
    }

    private var iconName: String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            return "folder.badge.questionmark"
        } else if trimmed.hasPrefix(">") || trimmed.hasPrefix(":") {
            return "terminal"
        }
        return "magnifyingglass"
    }

    private var suggestionText: String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix(">") || trimmed.hasPrefix(":") {
            return String(localized: "Commands do not require a prefix. Try typing 'Lock Screen' or 'Sleep' directly.")
        } else if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            return String(localized: "Direct path navigation isn't supported. Search by file or app name instead.")
        } else if trimmed.count <= 2 {
            return String(localized: "Keep typing to search across applications, files, and commands.")
        } else {
            return String(localized: "Check the spelling or try searching for an application (e.g. 'Safari') or command (e.g. 'Lock Screen').")
        }
    }
}
