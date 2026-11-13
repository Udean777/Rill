import Foundation
import RillData
import RillDomain
import Testing

@Suite("SpotlightFileSearch")
struct SpotlightFileSearchTests {
    @Test func `predicate hides folders when includeFolders is false`() {
        let options = FileSearchOptions(includeFiles: true, includeFolders: false, includeHidden: true)
        let predicate = SpotlightFileSearch.predicateString(for: "notes", options: options)

        #expect(predicate.contains("kMDItemContentType != \"public.folder\""))
        #expect(!predicate.contains("kMDItemFSInvisible != 1"))
    }

    @Test func `predicate restricts to folders when includeFiles is false`() {
        let options = FileSearchOptions(includeFiles: false, includeFolders: true, includeHidden: false)
        let predicate = SpotlightFileSearch.predicateString(for: "notes", options: options)

        #expect(predicate.contains("kMDItemContentType == \"public.folder\""))
        #expect(predicate.contains("kMDItemFSInvisible != 1"))
    }

    @Test func `shouldExclude filters dot-segments when includeHidden is false`() {
        let options = FileSearchOptions(includeHidden: false)

        #expect(SpotlightFileSearch.shouldExclude(path: "/Users/test/.env", options: options))
        #expect(SpotlightFileSearch.shouldExclude(path: "/Users/test/repo/.git/config", options: options))
        #expect(!SpotlightFileSearch.shouldExclude(path: "/Users/test/Documents/notes.md", options: options))
    }

    @Test func `shouldExclude filters excluded directory trees`() {
        let options = FileSearchOptions(
            includeHidden: true,
            excludedPaths: ["/Users/test/Projects/node_modules/"]
        )

        #expect(SpotlightFileSearch.shouldExclude(path: "/Users/test/Projects/node_modules", options: options))
        #expect(SpotlightFileSearch.shouldExclude(path: "/Users/test/Projects/node_modules/pkg/index.js", options: options))
        #expect(!SpotlightFileSearch.shouldExclude(path: "/Users/test/Projects/node_modules_backup/a.txt", options: options))
    }
}
