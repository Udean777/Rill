# Swift standards

Rules for every line in this repo. Mostly borrowed from sources, not invented:

- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) — naming, clarity at call site, argument labels.
- [Announcing Swift 6](https://www.swift.org/blog/announcing-swift-6/) — data-race safety as a language mode, typed throws, `Synchronization`.
- SE-0413 (typed throws), SE-0430 (`sending`), SE-0461 (`nonisolated(nonsending)`), SE-0466 (default actor isolation) — concurrency semantics used below.
- [Swift Testing](https://github.com/swiftlang/swift-testing) — `@Test`, `#expect`, `#require`.
- [swift-dependencies](https://github.com/pointfreeco/swift-dependencies) — the argument for controllable dependencies; we take the principle, not the library (see ADR-002).
- Clean Architecture reference: Domain / Data / Presentation with dependencies pointing inward.

Where a rule is enforced by tooling, the tool is named. Everything else is review.

---

## 1. Naming

Follow the API Design Guidelines. The three tests: **clarity at the point of use**, **fluency**, **no jargon**.

```swift
// ✅ reads as a sentence at the call site
results.removeAll(where: \.isStale)
panel.orderFrontRegardless()
try hotkey.register(.default)

// ❌
results.filterOut(stale: true)
panel.show2()
hotkey.reg(hk)
```

- Types and protocols: `UpperCamelCase`. Protocols describing a capability are nouns (`FileSearching`); protocols describing a value are nouns too (`Clock`), not `-able`.
- Methods and properties: `lowerCamelCase`. Methods with side effects are imperative (`record`, `toggle`, `execute`); without, noun phrases (`rank`, `snapshot`).
- Booleans read as assertions: `isVisible`, `hasFocus`, `canBecomeKey`, `shouldHideOnDeactivate` — never `visible`, never `flag`.
- No abbreviations except universally understood ones (`URL`, `ID`, `UI`, `HTTP`). `cfg`, `mgr`, `vc`, `idx`, `tmp` are banned. `vm` is banned.
- No type-name stutter: `RillDomain.SearchResult`, not `SearchResultModel`.
- Argument labels complete the phrase; omit when redundant:
  ```swift
  func move(to index: Int)          // ✅ moveTo(index:) reads worse
  func insert(_ result: SearchResult, at index: Int)
  ```
- Default arguments beat overloads. Two overloads for the same idea is a smell.
- File names match the primary type: `Ranking.swift`, `PaletteViewModel.swift`. One primary type per file.

## 2. Types

- `struct` by default; `let` by default. `var` needs a reason.
- `final class` only for: identity (`NSPanel` subclass), observation (`@Observable` view models), actor isolation, framework subclassing.
- `enum` with associated values beats a struct of optionals. `enum` with no cases is the correct namespace for constants.
- Avoid `Any`, `AnyObject`, `AnyHashable`, and `[String: Any]` outside of a single, documented decoding boundary.
- No `class` hierarchies of your own. Composition plus protocols. The one inheritance chain we accept is `NSPanel` → `PalettePanel` because AppKit requires it.
- Access control: `internal` by default, `private` aggressively, `public` only at module boundaries (Domain ports and entities). `fileprivate` only for a helper used by exactly one type in one file.
- `Sendable` on every type that crosses a concurrency boundary. Compiler-checked in Swift 6 mode; do not silence it.

## 3. Functions

- Small and single-purpose. If the body needs a comment to explain a second phase, extract that phase.
- Parameter count ≤ 4. Beyond that, take a parameter struct (`SearchOptions`), not a sixth positional argument.
- Return values over inout. `inout` is for genuine mutation of an existing value.
- Never return `Optional` as an error channel. `throws` or a `Result` at a boundary.
- Prefer `callAsFunction` for single-purpose use cases (`SearchUseCase`) so call sites read `search(query)`, and the type is still explicit at the composition root.
- 4-space indentation, 100-column soft limit, one statement per line. No ternaries nested inside ternaries.

## 4. Optionals and failure

```swift
// ❌ forces the reviewer to prove safety
let window = app.windows.first!

// ✅
guard let window = app.windows.first else { return }
```

- No `!`, `try!`, `as!`, `fatalError`, or `preconditionFailure` in shipping paths. The single allowed exception is an unreachable branch in a `switch` over a closed enum, and even then prefer `@unknown default`.
- Unwrap in the smallest scope; `guard` at the top of a function, not `if let` pyramids.
- Errors are typed domain enums, never strings:
  ```swift
  enum FileSearchError: Error, Equatable {
      case indexUnavailable
      case queryTooBroad
      case cancelled
  }
  ```
- Typed throws when the error set is closed: `func search(_:) throws(FileSearchError) -> [SearchResult]`. Untyped `throws` when wrapping framework errors.
- `try?` is allowed only where degradation is the intended behaviour **and** the error is logged or explicitly irrelevant. Never `try?` around a write that must succeed.
- Never swallow `CancellationError` inside a `catch` that also handles real errors — check `Task.isCancelled` first.

## 5. Concurrency

Non-negotiable for this project.

- **Swift 6 language mode** on every target. Warnings are errors in CI (`-warnings-as-errors`).
- UI and AppKit: `@MainActor`. Do not add `@MainActor` to pure logic to make a warning disappear.
- Shared mutable state: `actor`. Not a lock, not a serial queue, not `nonisolated(unsafe)`.
- Prefer `async let` and `withThrowingTaskGroup` for fan-out. Concurrency must be _structured_ — every child task's completion or failure is accounted for.
- **No `Task.detached`.** A detached task cannot be cancelled by its owner and loses priority/task-local context. If you think you need one, you need a longer-lived actor instead.
- **No `@unchecked Sendable`** without a `// SAFETY: <invariant that makes it safe>` comment on the line above. Target: zero occurrences.
- **No `nonisolated(unsafe)`** at all in v1.
- No `DispatchQueue.async`, no completion handlers, no `DispatchSemaphore`. `async/await` everywhere. The `@MainActor`-bound `NSMetadataQuery` is the one framework run-loop exception and it is documented at its call site.
- Cancellation is cooperative and _checked_: long loops call `try Task.checkCancellation()` at least once per batch.
- Never use `Task.sleep` for debounce outside a cancellable task; debounce always lives in the same `Task` that does the work, so cancelling one cancels both.
- `Clock` is a port. Never call `Date()` or `Task.sleep` inside Domain — pass the time in (`now: Date`) or inject the clock. This is what makes ranking and timeouts deterministic in tests.
- Bridging from a C callback (Carbon hotkey) into Swift concurrency: the callback may not capture context. Use a `@MainActor` hop through a token registry, and keep it to one small, documented file.

## 6. Dependencies

- Compile-time, constructor-injected. The composition root (`AppEnvironment.live()`) is the only place that names a concrete implementation.
- Never read `.shared` (`NSWorkspace.shared`, `UserDefaults.standard`) inside Domain or use-case code. Those reads belong in an adapter, behind a port.
- No global mutable state. The one allowed static is the hotkey token registry, which is `let`-only after startup and documented.
- Adding a package dependency requires: a line in the ADR log, a licence check, and no equivalent in the standard library or an Apple framework. Current allowed set: none required for v1 (`GRDB` only if persistence outgrows JSON; `Sparkle` only when distributing).

## 7. Observation and SwiftUI

- `@Observable` (Observation framework) for view models. Not `ObservableObject`/`@Published`.
- Only UI-relevant state is observable. Large result arrays are observable; derived values are computed, not stored twice.
- Mark plumbing with `@ObservationIgnored` (ports, caches, tasks) so it doesn't trigger invalidations.
- Views are stateless: no business logic, no `URLSession`, no `FileManager`, no `Date()`.
- The view body is one expression or a short chain of extracted subviews. A `body` over ~40 lines is split.
- `#Preview` for every view, with injected fakes — previews must never hit the disk or the network.
- `.task(id:)` for view-scoped async work; never `onAppear { Task { … } }` (unstructured, uncancellable).
- Views never call `NSApp.activate(_:)` or `NSApp.setActivationPolicy(_:)`. Activation is owned by `ActivationPolicyController`; a view that needs the app frontmost is a design error, not a missing call.

## 8. Formatting and structure

| Rule                | Detail                                                                                                   |
| ------------------- | -------------------------------------------------------------------------------------------------------- |
| Indentation         | 4 spaces, no tabs                                                                                        |
| Line length         | 100 soft, 120 hard                                                                                       |
| Braces              | opening brace on the same line, `else` on the same line as the closing brace                             |
| Imports             | alphabetical, one per line, no wildcard (Swift has none); never import a module you don't use            |
| Order within a type | nested types → static constants → stored properties → init → public API → internal API → private helpers |
| `MARK`              | Use `// MARK: -` to separate groups once a type exceeds ~60 lines                                        |
| Blank lines         | exactly one between members, none at the start/end of a scope                                            |
| Trailing whitespace | none                                                                                                     |
| File length         | ≤ 300 lines. Beyond that, the file is doing two jobs.                                                    |

Tooling: `swift-format` for whitespace/layout, `SwiftLint` for the semantic rules above that can be automated (`force_unwrapping`, `force_try`, `force_cast`, `identical_operands`, `empty_count`, `todo`, `unused_import`, `cyclomatic_complexity` ≤ 10, `function_body_length` ≤ 50, `type_body_length` ≤ 300). Both configs live in the repo root and run in CI. A `swiftlint:disable` must carry a justification on the same line and will be challenged in review.

## 9. Documentation

```swift
/// Ranks candidates into ordered sections.
///
/// Ordering never crosses a section boundary: a file result cannot outrank a
/// command result regardless of score.
///
/// - Parameters:
///   - candidates: Unranked results from all providers.
///   - usage: Frecency and favourites, as of the most recent snapshot.
/// - Returns: Non-empty sections only, in `Section.allCases` order.
public static func rank(
    _ candidates: [SearchResult],
    query: SearchQuery,
    usage: UsageSnapshot,
    now: Date
) -> [RankedSection]
```

- `///` on every `public` declaration in Domain. First line is a single-sentence summary ending in a period.
- `//` comments explain **why**, never what. `// increment the index` is noise; `// NSMetadataQuery must run on the main run loop` earns its place.
- `// MARK` for structure, `// TODO:` never — use an issue or a `shortcut:` comment.
- `shortcut: <limit>, <when to upgrade>` is the required form for deliberate deferrals. It is greppable, which is the point.

## 10. Localisation and user-facing text

- Every user-visible string goes through `String(localized:)` from day one, with a comment for translators when the interpolation is not self-evident.
- No string concatenation to build sentences (word order differs by language).
- No user-facing text in Domain. Domain returns enums/IDs; the UI localises.
- Sentence case for labels and buttons, no terminal punctuation on single sentences, no exclamation marks.

## 11. Logging and diagnosability

```swift
private let log = Logger(subsystem: "com.ssajudn.Rill", category: "search")
log.debug("query=\(query.raw, privacy: .public) files=\(count, privacy: .public)")
```

- `os.Logger` only. No `print`, no `NSLog`, no custom log wrapper.
- One subsystem, one `category` per module area: `search`, `hotkey`, `window`, `store`, `actions`.
- Query text is user data: `privacy: .public` only for counts and durations, `privacy: .private` (the default) for content.
- Every `catch` that isn't rethrown logs with the error and enough context to reproduce.

## 12. Testing

Swift Testing, in `Tests/`, mirroring source structure.

```swift
import Testing

@Suite("Ranking")
struct RankingTests {
    @Test func `prefix match outranks substring`() {
        let ranked = Ranking.rank(
            [.fixture(title: "Safari"), .fixture(title: "Photoshop")],
            query: SearchQuery(raw: "saf"),
            usage: .empty,
            now: .distantPast
        )
        #expect(ranked.first?.results.first?.title == "Safari")
    }

    @Test(arguments: [0, 1, 9, 100])
    func `result count is capped per section`(count: Int) { … }
}
```

- `#expect` / `#require` — `#require` when a `nil` would otherwise make the test meaningless.
- Backtick names as sentences. No `test` prefix, no `should` (the assertion already says should).
- One behaviour per test. Arrange–Act–Assert, no blank-line ceremony.
- Parameterised tests over loops. `.tags(...)` for grouping slow/UI tests.
- No real clock, no real network, no `UserDefaults.standard`, no writing outside a temp directory.
- Fakes over mocking frameworks; a fake is a small type you can read in 20 lines.
- Regression tests carry the bug's shape: a comment with the issue number and the exact input that failed.

## 13. Review checklist

A PR is not mergeable until every line is true:

- [ ] No `!`, `try!`, `as!`, `Task.detached`, `@unchecked Sendable`, `DispatchQueue`, `print`.
- [ ] No concrete adapter type named outside `CompositionRoot`.
- [ ] Domain target still imports nothing but Foundation.
- [ ] Every new async path is cancellable and checks cancellation.
- [ ] New user-visible text is localised; new UI is keyboard-reachable and has an accessibility label.
- [ ] A test exists for the branch that can fail.
- [ ] Performance budgets in `design.md` §4.6 hold (spot-check show + query latency).
- [ ] No `NSApp.activate` / `setActivationPolicy` outside `ActivationPolicyController`.
- [ ] Public API in Domain has a `///` doc comment.
- [ ] Any deferral has a `shortcut:` comment with its upgrade trigger.
