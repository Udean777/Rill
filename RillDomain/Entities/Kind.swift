/// What a result represents. Used by rendering and, later, action resolution.
public enum Kind: String, Sendable, Hashable {
    case command
    case application
    case file
    case calculation
    case web
}
