import Foundation
import RillDomain
import Testing

actor InMemoryPreferencesStore: PreferencesStoring {
    private var preferences: Preferences

    init(preferences: Preferences = .default) {
        self.preferences = preferences
    }

    func load() async -> Preferences {
        preferences
    }

    func save(_ preferences: Preferences) async {
        self.preferences = preferences
    }
}

@Suite("Preferences")
struct PreferencesTests {
    @Test func `default preferences match expected defaults`() async {
        let prefs = Preferences.default
        #expect(prefs.hotkey == .default)
        #expect(prefs.fileSearchEnabled == true)
        #expect(prefs.fileSearchScope == .homeDirectory)
    }

    @Test func `preferences store saves and loads roundtrip`() async {
        let store = InMemoryPreferencesStore()
        let initial = await store.load()
        #expect(initial == .default)

        let customHotkey = Hotkey(keyCode: 12, modifiers: [.command, .shift])
        let updated = Preferences(
            hotkey: customHotkey,
            fileSearchEnabled: false,
            fileSearchScope: .homeDirectory
        )

        await store.save(updated)
        let loaded = await store.load()
        #expect(loaded == updated)
        #expect(loaded.hotkey.keyCode == 12)
        #expect(loaded.fileSearchEnabled == false)
    }
}
