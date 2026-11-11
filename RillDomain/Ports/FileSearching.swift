/// Searches files indexed by the operating system metadata service.
public protocol FileSearching: Sendable {
    /// Queries indexed files matching `query`.
    /// - Parameter query: The user search input.
    /// - Returns: File search candidates matching the query, capped per section policy.
    func search(query: SearchQuery) async -> [SearchResult]
}
