# Design — Rill

**Rill** — a Spotlight-style launcher for macOS. Native Swift (AppKit + SwiftUI), macOS 26+, bundle `com.ssajudn.Rill`.

This is the entry document. Three companions:

| File                                       | Contents                                                                  |
| ------------------------------------------ | ------------------------------------------------------------------------- |
| [`architecture.md`](architecture.md)       | Layers, modules, concurrency model, data flow, persistence, testing, ADRs |
| [`swift-standards.md`](swift-standards.md) | Clean-code rules the codebase is held to                                  |
| [`AGENTS.md`](AGENTS.md)                   | Operating rules for AI agents working in this repo                        |

Reference implementation for the interaction model: Raycast 2.11.1 (reverse-engineered from the shipped DMG — see "Prior art" below).

---

## 1. Problem

The user wants to reach anything on their Mac without leaving the keyboard: an app, a file, a calculation, a system command. One keystroke in, one action out, never more than ~150 ms of perceived latency.

Raycast is the benchmark. Its launcher ("palette", internally) is a floating search field over a ranked result list, driven by a global hotkey.

## 2. Non-goals for v1

Explicitly deferred, to keep the first version shippable:

- Extension/plugin marketplace (a sandboxed third-party runtime is a product of its own).
- AI chat, cloud sync, team features.
- Clipboard history, snippets, window management.
- Windows/Linux.

Each gets a `shortcut:` comment in code and an entry in `architecture.md` §11 when the seam exists.

## 3. Prior art (what Raycast actually does)

Reverse-engineered from `Raycast 2.11.1.0` (arm64 DMG). Not Electron:

```
Raycast.app/Contents/
├── MacOS/Raycast                     Mach-O arm64 — native host (SwiftUI + Rust)
├── Frameworks/libraycast_host.dylib  Rust host core + backend-coordinator
└── Resources/macos-app_RaycastDesktopApp.bundle/Contents/Resources/
    ├── frontend/    239 rolldown/Vite chunks (React) — main-window.html entry
    ├── backend/     index.mjs (Node) + indexer.darwin-arm64.node + worker
    └── node/        embedded Node 26.12.1 runtime
```

Transferable ideas, all public-API reimplementable:

1. **Hotkey → host → window.** `registerHotkey(_:shortcut:scope:)`, `triggerHotkey(id:)`, `toggleMain(_:rootSearchEntryMethod:)`. `rootSearchEntryMethod` records _how_ the palette was opened (hotkey, click, command) — used for ranking and analytics.
2. **The launcher window is named "palette"** and is pre-warmed (`warmupMainWindow`) so the first frame is instant. The app is `LSUIElement = true` — it has no Dock tile and no menu bar at all, so showing the palette never changes the active app. Raycast additionally refcounts a `.regular` activation override for windows that need one (Settings), restoring `.accessory` on close.
3. **Search is sectioned.** Raycast's sections: `favorites`, `suggestions`, `fallback-commands`, `results`. Section is part of the result identity, not just visual grouping.
4. **Content indexing is the app's own.** `indexer.darwin-arm64.node` + a `Raycast Content Indexer` helper binary, with `SearchKind`, `SearchSorting`, `classifyPaths`, `recognizeText` (OCR). macOS Spotlight/MDQuery is not the primary file path.
5. **Search state is a formal machine** in the backend: `rootSearch`, `refreshRootSearch`, `clearRootSearch`, `contentSearch`, `fileSearch`, `revealInRootSearch`, `quickAiAutocompleteInRootSearch`.
6. **Ranking blends match quality with recency/frequency** in a stable, testable order (favorites pin, then frecency, then match score).

Non-transferable (we don't copy these): the three-runtime architecture (Swift + Rust + Node) buys them cross-platform extension hosting at the cost of a 15–30 MB footprint and a process supervisor we don't need. We stay single-process native.

## 4. Product definition

### 4.1 The one loop

```
press hotkey → palette appears, caret in field → type → results rank live
   → ↑/↓ or ⌘1…⌘9 → Enter → palette hides → action runs
```

Everything else in this document exists to make that loop feel instant and predictable.

### 4.2 Behaviour spec

| Input                                  | Behaviour                                                                                                                          |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| Global hotkey (default ⌥Space)         | Toggle palette. Show is idempotent; repeat press hides.                                                                            |
| `Esc` with a non-empty query           | Clear query, keep palette open (pop to root).                                                                                      |
| `Esc` with an empty query              | Hide palette.                                                                                                                      |
| `Enter`                                | Run the selected result's primary action.                                                                                          |
| `⌘Enter`                               | Run the secondary action (e.g. "Show in Finder", "Copy").                                                                          |
| `↑` / `↓`, `⌃N` / `⌃P`, `Tab` / `⇧Tab` | Move selection; selection wraps.                                                                                                   |
| `⌘1`…`⌘9`                              | Run the Nth result directly.                                                                                                       |
| Click outside / app loses key status   | Hide.                                                                                                                              |
| Hotkey pressed while palette open      | Hide (toggle semantics, not re-focus).                                                                                             |
| Palette open, another app steals focus | Hide; selection and query are preserved for the next show _only if_ the palette was hidden by focus loss, not by Esc or execution. |

Query is preserved across hide-by-focus-loss. Executing a command clears the query. This is the behaviour users have muscle memory for.

### 4.3 Result model

A result is not a `String`. Minimum shape:

```swift
struct SearchResult: Identifiable, Sendable, Hashable {
    struct ID: Hashable, Sendable { let source: String; let raw: String }

    let id: ID
    let title: String
    let subtitle: String?
    let icon: IconRef            // .systemSymbol / .bundle(id) / .fileURL(URL) — lazy, never decoded eagerly
    let section: Section         // .favorites, .suggestions, .commands, .applications, .files
    let kind: Kind               // .command / .application / .file / .calculation / .web
    let primaryAction: ActionDescriptor
    let secondaryActions: [ActionDescriptor]
    let baseScore: Double        // 0…1, from the provider's own relevance
}
```

`ActionDescriptor` is data, not a closure — it must cross an `async` boundary and be logged. The dispatcher resolves it to behaviour (`architecture.md` §6).

### 4.4 Sections

Fixed order, always rendered in this order even when empty (empty sections are dropped, order is not re-sorted):

1. `favorites` — user-pinned results.
2. `suggestions` — queryless defaults on an empty field (recent, most-used, a few system actions).
3. `commands` — built-in and app commands matching the query.
4. `applications` — installed apps.
5. `files` — Spotlight metadata matches.
6. `fallback` — "Search the web for …", "Open …", "Calculate …".

Ranking never crosses section boundaries. Users learn where things live; a file never jumps above an app command because of a fuzzy-score quirk.

### 4.5 Ranking

Pure function, no I/O, no clocks inside:

```swift
func rank(
    _ candidates: [SearchResult],
    usage: UsageSnapshot,
    now: Date
) -> [RankedSection]
```

Order within a section:

1. Pinned / favorite (stable by user-defined order).
2. `score = 0.6 * matchScore + 0.4 * frecency`
3. Tie-break: shorter title wins, then alphabetical (stable, so results don't jitter between keystrokes).

`matchScore` for text: exact match `1.0`; prefix `0.9`; word-boundary prefix `0.8`; substring `0.6`; subsequence/fuzzy `0.3–0.5` scaled by gap penalty. Diacritic- and case-insensitive.

`frecency` decays: `exp(-Δdays / 30)` multiplied by a use-count factor with diminishing returns (`log1p(count)`), normalized into 0…1. Constants live in one `RankingTuning` struct so they're tunable and testable.

### 4.6 Latency budgets

Measured on an M-series Mac, app warm, 4 000 apps+commands indexed:

| Stage                             | Budget                                            |
| --------------------------------- | ------------------------------------------------- |
| Hotkey → first visible frame      | **≤ 80 ms**                                       |
| Keystroke → results re-rendered   | **≤ 50 ms** (commands/apps), **≤ 150 ms** (files) |
| Keystroke → stale results cleared | ≤ 16 ms                                           |
| Execute → palette hidden          | ≤ 50 ms (hide first, then act)                    |
| Idle CPU                          | ≤ 0.3 % average                                   |
| Resident memory                   | ≤ 120 MB                                          |

These are release-build gates, checked in `PerformanceTests` and by hand with Instruments. A regression on the first two is a bug, not a nice-to-have.

## 5. Interaction design

### 5.1 Window

- Frameless floating `NSPanel`, ~680×420 pt, horizontally centred, vertically at ~22 % of the screen height (above the visual centroid, below the menu bar).
- Appears on the screen containing the mouse pointer.
- Backdrop: `NSVisualEffectView` `.hudWindow`/`.popover` material, rounded 12–16 pt corners, subtle shadow, no title bar.
- Show animation: 120 ms fade + 4 pt upward drift. Hide: 80 ms fade. Respect `NSWorkspace.accessibilityDisplayShouldReduceMotion`.
- The palette does **not** activate the app: it becomes key while the previous app stays the active app. See §5.3 — this is a hard requirement, not a polish item.

### 5.2 Content

```
┌──────────────────────────────────────────────┐
│  ⌕  query text                        [12]   │  search field, 28 pt
├──────────────────────────────────────────────┤
│  FAVORITES                                   │  section header, 11 pt, secondary
│  ▸ Safari                            ⌘1     │  selected row: accent fill
│  COMMANDS                                    │
│    Open Settings                     ⌘2     │
│    Sleep                             ⌘3     │
│  FILES                                       │
│    design.md /Users/…/projects      ⌘4     │
└──────────────────────────────────────────────┘
```

- Row height 44 pt, icon 20×20, title `.body`, subtitle `.caption` secondary, right-side shortcut hint.
- Keyboard selection is the only selection. Hover moves selection only if the pointer actually moves (avoids the list jumping under a resting cursor).
- Empty query → `suggestions`; never an empty palette.
- No results → a `fallback` section, never an empty state string.
- Result count is virtualised (`LazyVStack` + scroll position reset to top on query change).

### 5.3 Activation and focus model (hard requirement)

Opening the palette must be invisible to the window server's notion of "who is frontmost". The previously active app keeps its menu bar, its Dock highlight, and its focused window's title bar. The palette is an overlay, not a window switch.

Three separate things produce that, and all three are required:

| Mechanism                                                                  | Effect                                                                                                                | Who does it               |
| -------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| `LSUIElement = YES` (equivalently `NSApp.setActivationPolicy(.accessory)`) | The launcher **never has a Dock tile or menu bar of its own**. It cannot "become the active app" in the normal sense. | Info.plist                |
| `NSPanel` with `.nonactivatingPanel` + `canBecomeKey = true`               | The panel accepts keystrokes while its app remains inactive.                                                          | `PalettePanel`            |
| Never calling `NSApp.activate(_:)` on the show path                        | Activation is what moves the menu bar and Dock highlight. `makeKeyAndOrderFront` is not activation.                   | `PaletteWindowController` |

Observable result, which is the acceptance test:

- Hotkey pressed → palette appears, caret blinking in the field, typing works.
- Menu bar still shows the _previous_ app's menus.
- Dock still highlights the _previous_ app.
- The launcher never appears in ⌘Tab.
- Previous app's title bar dims (it lost key), but it did not lose active status.

**The one exception: Settings.** A preferences window needs a real menu bar and activation. So activation policy is refcounted, not toggled:

```swift
// RillPlatform/System/ActivationPolicyController.swift
@MainActor
final class ActivationPolicyController {
    private var overrides = 0

    func acquireRegular() {           // called when a real window opens
        overrides += 1
        if overrides == 1 { NSApp.setActivationPolicy(.regular) }
    }

    func releaseRegular() {           // called when it closes
        overrides -= 1
        if overrides == 0 { NSApp.setActivationPolicy(.accessory) }
    }
}
```

Refcounting matters: Settings and an About panel can be open at once, and closing one must not yank the Dock icon out from under the other. Raycast ships the same construct (`makeAccessoryPolicyOverrideToken(restoreRegularOnRelease:)` in `NSApplication+ActivationPolicy.swift`); it is the known-correct shape for this problem.

**Anti-patterns that break it** — each one is a bug report of the form "the Dock icon flashes when I open the launcher":

- `NSApp.activate(ignoringOtherApps: true)` anywhere on the show path.
- `NSApp.activate()` (the modern cooperative call) on the show path — it still activates.
- Setting `.regular` at launch "because SwiftUI needs it".
- Using `WindowGroup`/`Window`/`Settings` as the palette's scene — scenes own activation.
- `panel.makeKeyAndOrderFront` followed by `NSApp.activate` to "fix" a non-typing field. If the field doesn't type, the panel's `canBecomeKey`/style mask is wrong, not the activation.

After hiding, nothing needs restoring: we never took focus away from the previous app's _activation_, only its key window, and macOS returns key status to it automatically when the panel orders out.

### 5.4 Accessibility of the launcher itself

A keyboard launcher must be usable by VoiceOver and Switch Control:

- Search field carries a label, not just a placeholder.
- Each row is one accessibility element with title + subtitle + section + shortcut as its label/value; selection changes post `.announcementRequested` with the result count ("3 results").
- Full keyboard operability; no action requires the pointer.
- Focus ring visible against the blurred backdrop; honour Increase Contrast and Reduce Transparency.

### 5.5 Preferences (separate window)

A normal `Settings` scene: hotkey recorder, search-scope toggles (files: on/off + folders), appearance, launch at login (`SMAppService.mainApp`), permissions status. No preferences inside the palette. Opening it acquires the `.regular` policy override (§5.3) and releases it on close.

## 6. Permissions, distribution, and the constraint that shapes the design

| Capability                                                                      | Requirement                                                   |
| ------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| Global hotkey via Carbon `RegisterEventHotKey`                                  | **None.** No Accessibility permission.                        |
| Global key monitoring (`NSEvent.addGlobalMonitorForEvents`, `CGEventTap`)       | Input Monitoring / Accessibility. Avoid.                      |
| Reading other apps' focused text / UI (selected text, paste into frontmost app) | **Accessibility** (`AXIsProcessTrusted`). Degrade gracefully. |
| Spotlight file metadata (`NSMetadataQuery`)                                     | None for user-visible files; sandbox restricts scopes.        |
| Launch at login                                                                 | `SMAppService`, no permission.                                |

Two consequences, both accepted:

1. **The app is not sandboxed.** App Sandbox blocks the Accessibility API and severely limits filesystem-wide `NSMetadataQuery`. A Raycast-class launcher cannot ship sandboxed. That rules out the Mac App Store, so distribution is Developer ID + notarization (the $99/yr account, at release time only).
2. **Accessibility is optional, not required.** The core loop (hotkey → search → open app/file/URL) works without it. Features that need it are gated behind a permission row in Settings and simply absent (not broken) when unavailable.

Permissions are re-checked on every palette show (`AXIsProcessTrusted()` is cheap) so a user granting access in System Settings sees it take effect without relaunching.

## 7. Architecture in one paragraph

Clean Architecture, five Xcode targets, dependencies point inward: `RillDomain` (entities, use cases, ports — pure Swift, no UI import) ← `RillData` and `RillUI` ← `RillPlatform` (AppKit shell) ← `Rill` (app + composition root). Swift 6 language mode, strict concurrency; UI and AppKit are `@MainActor`, shared mutable state lives in actors, every value crossing a boundary is `Sendable`. Dependency injection is constructor-based at a single composition root. Full detail in `architecture.md`.

## 8. Milestones

| #   | Deliverable                                                                                | Done when                                                        |
| --- | ------------------------------------------------------------------------------------------ | ---------------------------------------------------------------- |
| M0  | Xcode skeleton, 5 targets + test bundle, CI script (`xcodebuild build`, `xcodebuild test`) | Builds clean in Swift 6 mode with zero warnings                  |
| M1  | Hotkey + floating panel + search field + `Esc`/toggle                                      | Hotkey shows panel in ≤ 80 ms; typing is uninterrupted           |
| M2  | Command + application providers, sectioned results, keyboard navigation, execute           | Open any app by typing 2–3 letters                               |
| M3  | Ranking with frecency, persistence                                                         | Repeating a query promotes what you used, stable across launches |
| M4  | File search via `NSMetadataQuery`, debounce + cancellation                                 | File results ≤ 150 ms, no stale flash                            |
| M5  | Settings window, hotkey recorder, launch at login                                          | Round-trip preferences                                           |
| M6  | Calculator + web fallback, accessibility pass, performance gates in CI                     | Budgets in §4.6 measured and enforced                            |
| M7  | Signing, notarisation, Sparkle updates                                                     | Installable by someone else                                      |

## 9. Risks

| Risk                                                | Mitigation                                                                                                 |
| --------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| File search over the whole disk is slow and noisy   | Debounce 60 ms, cap results per section (files: 20), scope to home by default, cancel in-flight queries    |
| Hotkey conflicts with other launchers / macOS       | Detect ⌘Space conflict, offer alternatives, never silently fail — surface "hotkey unavailable" in Settings |
| Accessibility permission UX is hostile              | Feature-gate; explain in-context; deep-link to the exact Settings pane; never block the core loop          |
| Non-sandboxed app looks scary to users              | Hardened runtime, notarised, no network in v1, document exactly what is read                               |
| Ranking feels random                                | Pure function + golden-file tests + a debug overlay showing each result's score components                 |
| SwiftUI `WindowGroup` fights a panel-based launcher | Do not use scenes for the palette; AppKit owns the window (`architecture.md` §5.3)                         |
