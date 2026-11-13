import Foundation
import RillData
import RillDomain
import Testing

@Suite("UserDefaultsPreferencesStore")
struct UserDefaultsPreferencesStoreTests {
    @Test func `hidden sections survive a save and load roundtrip`() async throws {
        let suite = makeSuiteName()
        defer { clearSuite(suite) }
        let store = try makeStore(suite)

        await store.save(Preferences(hiddenSections: [.files, .systemSettings]))
        let loaded = await store.load()

        #expect(loaded.hiddenSections == [.files, .systemSettings])
    }

    @Test func `a fresh store hides no sections`() async throws {
        let suite = makeSuiteName()
        defer { clearSuite(suite) }

        let loaded = try await makeStore(suite).load()

        #expect(loaded.hiddenSections.isEmpty)
    }

    @Test func `an unknown stored section is ignored`() async throws {
        let suite = makeSuiteName()
        defer { clearSuite(suite) }
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.set(["files", "not-a-section"], forKey: "preferences.sections.hidden")

        let loaded = await UserDefaultsPreferencesStore(userDefaults: defaults).load()

        #expect(loaded.hiddenSections == [.files])
    }

    @Test func `expanded search preferences survive a save and load roundtrip`() async throws {
        let suite = makeSuiteName()
        defer { clearSuite(suite) }
        let store = try makeStore(suite)

        let saved = Preferences(
            fileSearchScope: .custom,
            fileSearchIncludeFiles: false,
            fileSearchIncludeFolders: true,
            fileSearchIncludeHidden: true,
            fileSearchCustomPaths: ["/Users/test/Projects"],
            fileSearchExcludedPaths: ["/Users/test/Projects/node_modules"],
            calculatorEnabled: false,
            webSearchEnabled: false
        )
        await store.save(saved)
        let loaded = await store.load()

        #expect(loaded.fileSearchScope == .custom)
        #expect(!loaded.fileSearchIncludeFiles)
        #expect(loaded.fileSearchIncludeFolders)
        #expect(loaded.fileSearchIncludeHidden)
        #expect(loaded.fileSearchCustomPaths == ["/Users/test/Projects"])
        #expect(loaded.fileSearchExcludedPaths == ["/Users/test/Projects/node_modules"])
        #expect(!loaded.calculatorEnabled)
        #expect(!loaded.webSearchEnabled)
    }

    private func makeSuiteName() -> String {
        "RillTests.\(UUID().uuidString)"
    }

    /// The reference is handed to the store and never used again, so the send
    /// stays race-free; cleanup uses a fresh instance.
    private func makeStore(_ suite: String) throws -> UserDefaultsPreferencesStore {
        let defaults = try #require(UserDefaults(suiteName: suite))
        return UserDefaultsPreferencesStore(userDefaults: defaults)
    }

    private func clearSuite(_ suite: String) {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }
}
