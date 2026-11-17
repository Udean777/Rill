import Foundation
import Observation
import RillDomain
import SwiftUI

/// Owns the editable `Preferences`: mutation, persistence, and the change
/// notification the rest of the app reacts to.
@MainActor
@Observable
public final class PreferencesEditor {
    public private(set) var values: Preferences

    @ObservationIgnored private let store: PreferencesStoring
    @ObservationIgnored var onChanged: ((Preferences) -> Void)?

    public init(store: PreferencesStoring) {
        self.store = store
        self.values = .default
    }

    public func load() async {
        values = await store.load()
    }

    public func binding<Value: Equatable>(
        for keyPath: WritableKeyPath<Preferences, Value>
    ) -> Binding<Value> {
        Binding(
            get: { self.values[keyPath: keyPath] },
            set: { self.update(keyPath, to: $0) }
        )
    }

    /// Updates any equatable preference field and persists the change.
    public func update<Value: Equatable>(
        _ keyPath: WritableKeyPath<Preferences, Value>,
        to value: Value
    ) {
        guard values[keyPath: keyPath] != value else { return }
        values[keyPath: keyPath] = value
        save()
    }

    public func addFileSearchCustomPath(_ path: String) {
        addPath(path, to: \.fileSearchCustomPaths)
    }

    public func removeFileSearchCustomPath(_ path: String) {
        removePath(path, from: \.fileSearchCustomPaths)
    }

    public func addFileSearchExcludedPath(_ path: String) {
        addPath(path, to: \.fileSearchExcludedPaths)
    }

    public func removeFileSearchExcludedPath(_ path: String) {
        removePath(path, from: \.fileSearchExcludedPaths)
    }

    public func updateSectionVisibility(_ section: RillDomain.Section, isVisible: Bool) {
        if isVisible {
            values.hiddenSections.remove(section)
        } else {
            values.hiddenSections.insert(section)
        }
        save()
    }

    /// Sets a shortcut without persisting; the hotkey coordinator saves once
    /// registration succeeds.
    func setHotkey(_ hotkey: Hotkey, at keyPath: WritableKeyPath<Preferences, Hotkey>) {
        values[keyPath: keyPath] = hotkey
    }

    func restorePrimaryHotkey(_ hotkey: Hotkey) {
        values.hotkey = hotkey
    }

    /// Restores every preference except onboarding completion, so the welcome
    /// window does not come back. The caller persists after registration.
    func resetToDefaults() {
        let completed = values.hasCompletedOnboarding
        values = .default
        values.hasCompletedOnboarding = completed
    }

    func persist() async {
        await store.save(values)
    }

    private func addPath(_ path: String, to keyPath: WritableKeyPath<Preferences, [String]>) {
        let normalized = Self.normalizePath(path)
        guard !normalized.isEmpty, !values[keyPath: keyPath].contains(normalized) else { return }
        values[keyPath: keyPath].append(normalized)
        save()
    }

    private func removePath(_ path: String, from keyPath: WritableKeyPath<Preferences, [String]>) {
        values[keyPath: keyPath].removeAll { $0 == path }
        save()
    }

    private static func normalizePath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 1, trimmed.hasSuffix("/") else { return trimmed }
        return String(trimmed.dropLast())
    }

    private func save() {
        let snapshot = values
        Task {
            await store.save(snapshot)
            // Apply after persisting: the palette re-runs its search and reads
            // these values back from the store.
            onChanged?(snapshot)
        }
    }
}
