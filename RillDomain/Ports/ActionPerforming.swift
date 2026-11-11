/// Runs a resolved action. Framework errors are open, so this stays untyped.
public protocol ActionPerforming: Sendable {
    func perform(_ action: ActionDescriptor) async throws
}
