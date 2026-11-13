/// Fixed result groups. Ranking never crosses a section boundary, so the
/// declaration order is the render order (see design.md §4.4).
public enum Section: String, Sendable, CaseIterable {
    case currency
    case systemSettings
    case favorites
    case suggestions
    case applications
    case commands
    case files
    case fallback
}
