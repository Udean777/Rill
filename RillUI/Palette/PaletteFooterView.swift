import RillDomain
import SwiftUI

/// Compact, uncluttered footer bar for the launcher palette.
/// Replaces the cramped chip row with a clean dual-cluster layout:
/// - Left: Contextual action hint for the selected item (e.g. ↵ Open, ⌘P Pin)
/// - Right: Global navigation and quick-access utility buttons (Clipboard ⌥⌘V, Settings ⌘,)
struct PaletteFooterView: View {
    let selectedResult: SearchResult?
    let showsHints: Bool
    let hasMultipleApplicationPages: Bool
    let onOpenClipboard: () -> Void
    let onOpenSettings: () -> Void

    init(
        selectedResult: SearchResult?,
        showsHints: Bool,
        hasMultipleApplicationPages: Bool = false,
        onOpenClipboard: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.selectedResult = selectedResult
        self.showsHints = showsHints
        self.hasMultipleApplicationPages = hasMultipleApplicationPages
        self.onOpenClipboard = onOpenClipboard
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        HStack(spacing: 12) {
            if let selectedResult {
                HStack(spacing: 10) {
                    actionHint("↵", label: actionTitle(for: selectedResult))

                    actionHint("⌘P", label: selectedResult.section == .favorites ? "Unpin" : "Pin")
                }
            }

            Spacer(minLength: 16)

            if showsHints {
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Text("↑↓")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))

                        Text("Move")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    if hasMultipleApplicationPages {
                        HStack(spacing: 4) {
                            Text("←→")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))

                            Text("Page")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Rectangle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 0.5, height: 14)

                    Button {
                        onOpenClipboard()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 11))

                            Text("Clipboard")
                                .font(.system(size: 12, weight: .medium))

                            Text("⌥⌘V")
                                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open Clipboard History (Option-Command-V)")

                    Button {
                        onOpenSettings()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 11))

                            Text("⌘,")
                                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open Settings (Command-Comma)")
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 32)
    }

    private func actionTitle(for result: SearchResult) -> String {
        switch result.primaryAction {
        case .openApplication:
            return "Open"
        case .openFile:
            return "Open"
        case .openURL:
            return "Open"
        case .copyToPasteboard:
            return "Copy"
        case .openSettings:
            return "Settings"
        case .openClipboardHistory:
            return "Clipboard"
        }
    }

    private func actionHint(_ key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}
