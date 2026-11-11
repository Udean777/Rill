/// Supplies installed applications, cached after the first scan.
public protocol ApplicationCataloguing: Sendable {
    func applications() async -> [SearchResult]
}
