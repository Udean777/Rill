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
        #expect(prefs.suggestionWindowDays == 7)
        #expect(prefs.applicationsPerPage == 5)
        #expect(prefs.statusBarEnabled == true)
        #expect(prefs.showKeyboardHints == true)
        #expect(prefs.hasCompletedOnboarding == false)
    }

    @Test func `every section is visible by default`() {
        #expect(Preferences.default.hiddenSections.isEmpty)
    }

    @Test func `sanitizing keeps the hidden sections`() {
        let prefs = Preferences(hiddenSections: [.files, .systemSettings])

        #expect(prefs.sanitized().hiddenSections == [.files, .systemSettings])
    }

    @Test func `sanitizing replaces out-of-range choices with defaults`() {        let prefs = Preferences(suggestionWindowDays: 90, applicationsPerPage: 10)
        let sanitized = prefs.sanitized()

        #expect(sanitized.suggestionWindowDays == 7)
        #expect(sanitized.applicationsPerPage == 5)
    }

    @Test func `sanitizing keeps supported choices`() {
        let prefs = Preferences(suggestionWindowDays: 30, applicationsPerPage: 3)

        #expect(prefs.sanitized() == prefs)
    }

    @Test func `preferences store saves and loads roundtrip`() async {
        let store = InMemoryPreferencesStore()
        let initial = await store.load()
        #expect(initial == .default)

        let customHotkey = Hotkey(keyCode: 12, modifiers: [.command, .shift])
        let updated = Preferences(
            hotkey: customHotkey,
            fileSearchEnabled: false,
            fileSearchScope: .homeDirectory,
            hasCompletedOnboarding: true
        )

        await store.save(updated)
        let loaded = await store.load()
        #expect(loaded == updated)
        #expect(loaded.hotkey.keyCode == 12)
        #expect(loaded.fileSearchEnabled == false)
        #expect(loaded.hasCompletedOnboarding == true)
    }
}
