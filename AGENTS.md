# AGENTS.md

Operating rules for anyone (human or agent) changing this repository.

**What this is:** Rill, a native macOS launcher in the style of Spotlight/Raycast. AppKit-owned floating panel, SwiftUI content, Swift 6. Bundle id `com.ssajudn.Rill`.

Read before your first change, in this order:

1. [`design.md`](design.md) — what the product does and why (behaviour spec, latency budgets).
2. [`architecture.md`](architecture.md) — layers, ports, concurrency, ADRs.
3. [`swift-standards.md`](swift-standards.md) — the code rules this repo is held to.

If a rule here and a rule in those documents disagree, the documents win and this file is stale — fix it in the same change.

---

## 1. Non-negotiable behaviour

These are product requirements, not preferences. A change that breaks one is rejected regardless of how clean it is.

1. **The app never activates.** `LSUIElement = YES`, panel style `.nonactivatingPanel`, and **no** `NSApp.activate(_:)` anywhere on the palette show path. The previously active app keeps its menu bar and Dock highlight. See `design.md` §5.3.
2. **No Dock tile, no menu bar, no ⌘Tab entry.** Ever.
3. **`ENABLE_APP_SANDBOX = NO`.** Sandbox is incompatible with Accessibility and filesystem-wide metadata search. Do not "fix" this; it is ADR-006.
4. **The palette is AppKit-owned.** No `WindowGroup`, `Window`, or `Settings` scene may host it. Scenes activate.
5. **Activation policy is refcounted**, never toggled. Only `ActivationPolicyController` may call `setActivationPolicy`; only Settings/About may acquire `.regular`.

## 2. Architecture

Dependency direction is inward and enforced by target dependencies:

```
Rill (app) ──▶ RillPlatform ──▶ RillDomain
    │              │
    ├──▶ RillData ─┘
    └──▶ RillUI ───┘

RillData ──▶ RillDomain
RillUI   ──▶ RillDomain
```

| Target         | Rule                                                                                                                 |
| -------------- | -------------------------------------------------------------------------------------------------------------------- |
| `RillDomain`   | Foundation only. No AppKit, SwiftUI, Observation, SQLite, networking. `nonisolated` default isolation.               |
| `RillData`     | Adapters that implement `RillDomain` ports. `nonisolated` default isolation; long-lived mutable state is an `actor`. |
| `RillUI`       | SwiftUI views + `@Observable` view models. `MainActor` default isolation.                                            |
| `RillPlatform` | AppKit, Carbon, Accessibility. `MainActor` default isolation.                                                        |
| `Rill`         | `main.swift`, `AppDelegate`, composition root. No feature logic.                                                     |

Rules:

- Every side effect is behind a protocol declared in `RillDomain/Ports`. No `NSWorkspace.shared`, `UserDefaults.standard`, `FileManager`, or `Date()` in domain or use-case code.
- Exactly one composition root constructs concrete types. Feature code receives ports through `init`.
- Domain returns domain types (`SearchResult`), never `NSRunningApplication`, `NSImage`, or `URLRequest`.
- New dependency: justify it in an ADR entry in `architecture.md`, check the licence, and only if the stdlib/Apple framework cannot do it.

## 3. Swift rules (summary)

Full detail in `swift-standards.md`. The ones that get a change blocked:

- Swift 6 language mode. Every target, every file.
- No `!`, `try!`, `as!`, `fatalError`, `Task.detached`, `DispatchQueue`, `@unchecked Sendable`, `nonisolated(unsafe)`, `print`.
- Structs and `let` by default. Classes only for identity, `@Observable`, actor, or AppKit subclassing.
- Errors are typed enums. `throws(ClosedErrorSet)` when the set is closed.
- UI strings through `String(localized:)`. No user-facing text in Domain.
- Logging through `os.Logger`, one `category` per area, query text `privacy: .private`.
- Naming per the Swift API Design Guidelines: reads as a sentence at the call site; no abbreviations (`vm`, `mgr`, `idx`).
- Public domain API gets a `///` doc comment.

## 4. Testing

- Swift Testing (`import Testing`), suites mirroring source folders.
- Every branch that can fail gets a test. Pure logic (`Ranking`, `MatchScore`, `Frecency`) is tested exhaustively with parameterised tests.
- No real clock, no network, no `UserDefaults.standard`, no writes outside a temp directory. Inject `Clock`.
- Fakes over mocking frameworks. A fake is short enough to read.
- Test names are sentences in backticks: `@Test func `prefix match outranks substring`()`.

## 5. Build and verify

```sh
# build everything
xcodebuild -scheme Rill -destination 'platform=macOS' build

# unit tests
xcodebuild -scheme Rill -destination 'platform=macOS' test

# check the two product invariants after any RillPlatform change
plutil -p <built>/Rill.app/Contents/Info.plist | grep LSUIElement     # must be true
xcodebuild -list -project Rill.xcodeproj                              # all 5 targets + tests
```

Before handing off a change:

1. Build is warning-free under Swift 6.
2. New logic has a test.
3. Palette show path still does not activate the app (launch the app: no Dock tile, `lsappinfo info -only Status <pid>` reports `type="UIElement"`).
4. Latency budgets in `design.md` §4.6 unchanged, or the change explains why.

## 6. Project file

`Rill.xcodeproj/project.xcproj` is Xcode 27's JSON project format. Prefer Xcode's UI for target/build-setting changes. If you must edit it by hand: keep it valid JSON, keep IDs unique, and run `xcodebuild -list` plus a build immediately after. Do not let a hand edit leave the project unopenable.

## 7. When you defer something

Any deliberate shortcut gets a comment at the code site in this exact form:

```swift
// shortcut: <the limit>, <when to upgrade>
```

and a row in `architecture.md` §11. A deferral without an upgrade trigger is a bug.

## 8. Scope discipline

Do not build what the milestone does not ask for. Extensions, AI, clipboard history, sync, and multi-platform support are explicitly out of scope for v1 (`design.md` §2). If a change needs one of them to be coherent, stop and raise it instead of building it.
