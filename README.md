<div align="center">

# Rill

**A Spotlight-style launcher for macOS that never steals focus.**

![Swift 6](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)
![macOS 26+](https://img.shields.io/badge/macOS-26%2B-000000?logo=apple&logoColor=white)
![Xcode 27](https://img.shields.io/badge/Xcode-27-147EFB?logo=xcode&logoColor=white)
![No dependencies](https://img.shields.io/badge/third--party%20dependencies-none-2ea44f)

</div>

Rill is a native macOS launcher — press **⌥Space**, type, hit Enter. It finds apps, files and built-in commands, ranks them by how you actually work, and disappears. The previously active app keeps its menu bar, its Dock highlight and its ⌘Tab entry: Rill never becomes the frontmost app.

```
┌ ⌕ Search ────────────────────────────────────┐
│ SUGGESTED ───────────────────────────────    │  apps used in the last 7 days
│   ▸ Safari                            ⌘1    │
│ ALL APPS ────────────────────────────────    │  five per page
│   Notes                               ⌘2    │
│   …                                          │
│                          ‹  1/10  ›          │
├──────────────────────────────────────────────┤
│ [⚙ Open Settings] [⌂ Home] [▦ Applications]  │  fixed command chips
└──────────────────────────────────────────────┘
```

---

## Features

| Feature | What it does |
| --- | --- |
| **Non-activating palette** | A frameless floating `NSPanel` that becomes key without activating the app. No Dock tile, no menu bar, no ⌘Tab entry. |
| **Instant open** | The panel is built and pre-warmed at launch; showing it costs one `makeKeyAndOrderFront`. Hotkey → first frame in ≤ 80 ms. |
| **Apps, commands and files** | One search field over installed applications, built-in commands, and Spotlight metadata. Results are grouped into fixed sections, never re-sorted across boundaries. |
| **Suggested apps** | The five apps you used most in the last seven days, surfaced first on an empty field. Usage is recorded from app activations Rill observes itself — no private APIs, no permissions. |
| **Paged application browser** | All apps are shown five per page with a `‹ 1/N ›` pager. Page Up / Page Down flip pages; arrow keys flip a page when the selection walks off its edge. |
| **Command chip row** | Built-in commands (`Open Settings`, `Open Home Folder`, `Open Applications`) stay pinned under the list in the root layout — always one click or arrow-press away. |
| **Frecency ranking** | Results blend match quality with usage frequency and recency (`exp(-Δdays/30) · log1p(count)`). Pinned rows win. Stable tie-breaks stop results from jittering between keystrokes. |
| **Keyboard-first** | `↑` `↓` `Tab` `⇧Tab` `⌃P` `⌃N` to move, `Enter` to run, `⌘1…⌘9` for the first nine rows, `Esc` to clear or dismiss, Page Up/Down for pages. |
| **Fuzzy matching** | Case- and diacritic-insensitive: exact, prefix, word-boundary, substring, then subsequence with a gap penalty. |
| **Calculator fallback** | Type `12 * 4`, get `48` and copy it. No extra app, no network. |
| **Web search fallback** | Anything else offers “Search Google for …” as the last section. |
| **File search** | `NSMetadataQuery` over your home directory, debounced and cancellable, toggleable in Settings. |
| **Custom hotkey** | A recorder in Settings rebinds the global hotkey through Carbon `RegisterEventHotKey` — no Accessibility or Input Monitoring prompt. |
| **Launch at login** | `SMAppService`-backed toggle in Settings. |
| **Status bar item** | A menu bar entry as a second way in; the palette itself is still summonable anywhere. |
| **Accessibility** | Every row has a label and selection trait, the pager announces “Page X of Y”, focus stays on the search field, and reduced-motion disables the show/hide animation. |

## Tech stack

| Layer | Choice | Why |
| --- | --- | --- |
| Language | **Swift 6**, strict concurrency, `async`/`await` | Data-race safety at compile time; no `DispatchQueue`, no `@unchecked Sendable`. |
| Window | **AppKit** (`NSPanel`, `.nonactivatingPanel`, `.hudWindow` material) | SwiftUI scenes activate the app. A launcher cannot afford that, so AppKit owns the window. |
| Content | **SwiftUI** + `@Observable` view models | Declarative rows and state without a third-party architecture framework. |
| Hotkey | **Carbon** `RegisterEventHotKey` | No permission prompt, cannot keylog. Wrapped behind a port so it can be replaced in one file. |
| Files | **`NSMetadataQuery`** | macOS already indexes the disk; we do not ship an indexer in v1. |
| App usage | **`NSWorkspace.didActivateApplicationNotification`** | Public API, no permissions. Feeds suggested apps and frecency. |
| Persistence | **JSON snapshot** behind a `UsageStoring` port, atomic writes from an `actor` | Thousands of rows at most; a database would be premature. |
| Testing | **Swift Testing** (`import Testing`) | Parameterised pure-logic tests with injected `Clock` and fake ports. |
| Project | **Xcode 27** JSON project format, five targets | Folder-based membership: new files join their target without project edits. |
| Dependencies | **None** | Standard library and Apple frameworks only. |

### Architecture

Dependencies point inward and are enforced by target dependencies:

```
Rill (app) ──▶ RillPlatform ──▶ RillDomain
    │              │
    ├──▶ RillData ─┘
    └──▶ RillUI ───┘

RillData ──▶ RillDomain
RillUI   ──▶ RillDomain
```

| Target | Responsibility |
| --- | --- |
| `RillDomain` | Entities, ports, use cases, and pure ranking. Foundation only — no AppKit, SwiftUI, SQLite or networking. |
| `RillData` | Adapters: application catalogue, JSON usage store, Spotlight file search, command registry. |
| `RillUI` | SwiftUI views and `@Observable` view models. Talks to the domain through use cases only. |
| `RillPlatform` | AppKit, Carbon and Accessibility: the panel, hotkey, activation policy, app-usage tracker. |
| `Rill` | `main.swift`, `AppDelegate` and the single composition root. No feature logic. |

Every side effect sits behind a protocol in `RillDomain/Ports`; feature code receives ports through `init`, and exactly one place constructs the concrete adapters.

## Hard rules

These are product requirements, not preferences:

1. **The app never activates.** No `NSApp.activate(_:)` on the show path. The previous app keeps focus.
2. **No Dock tile, no menu bar icon for the palette, no ⌘Tab entry.** `LSUIElement = YES`.
3. **The app is not sandboxed.** Accessibility and filesystem-wide metadata search are incompatible with the sandbox.
4. **The palette is AppKit-owned.** No `WindowGroup`, `Window` or `Settings` scene hosts it.
5. **Activation policy is refcounted.** Only Settings and About may borrow `.regular`, and they hand it back.

## Build and run

```sh
# build
xcodebuild -scheme Rill -destination 'platform=macOS' build

# unit tests (52 tests, 12 suites)
xcodebuild -scheme Rill -destination 'platform=macOS' test

# open in Xcode
open Rill.xcodeproj
```

Requirements: macOS 26+, Xcode 27.

## Performance budgets

Measured on Apple silicon, app warm, 4 000 apps and commands indexed:

| Stage | Budget |
| --- | --- |
| Hotkey → first visible frame | ≤ 80 ms |
| Keystroke → results re-rendered | ≤ 50 ms (commands/apps), ≤ 150 ms (files) |
| Execute → palette hidden | ≤ 50 ms (hide first, then act) |
| Idle CPU | ≤ 0.3 % average |
| Resident memory | ≤ 120 MB |

## Documentation

- [`design.md`](design.md) — what the product does and why: behaviour, ranking, latency budgets.
- [`architecture.md`](architecture.md) — layers, ports, concurrency, ADR log.
- [`swift-standards.md`](swift-standards.md) — the code rules this repository is held to.
- [`AGENTS.md`](AGENTS.md) — operating rules for anyone changing the repo.

## Non-goals for v1

Extensions, AI, clipboard history, sync and multi-platform support are explicitly out of scope. Rill does one thing: get you to an app, a file or a command faster than the mouse.
