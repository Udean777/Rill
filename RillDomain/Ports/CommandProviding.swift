/// Supplies the in-memory command catalogue. Synchronous: commands are few and
/// already built when the palette opens.
public protocol CommandProviding: Sendable {
    var commands: [SearchResult] { get }
}
