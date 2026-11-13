# Audit — Currency Converter (pre-implementation)

**Status:** audit only. No implementation was written.  
**Date:** Fri Nov 13 2026  
**Scope:** user types `$20` (or any currency amount) in the palette, and Rill converts it to their local currency (IDR in Indonesia, etc.) without leaving the launcher.

---

## 1. The ask, restated

- Detect a currency amount in the typed query (e.g. `$20`, `€50`, `100 JPY`).
- Resolve the user's region/currency from the system locale (Indonesia → IDR).
- Convert the amount to the local currency and show it as a result.
- Support *any* input currency → any local currency.
- No network is currently used anywhere in the app; this feature would be the first.

---

## 2. What already exists that this can reuse

| Existing piece | Relevance to currency converter |
|---|---|
| `SearchUseCase` (Domain) | Fans out to providers, ranks within sections. The converter would be one more provider (or one more fallback candidate) fed into the same `Ranking.rank`. |
| `Section.fallback` | The natural home for a conversion result, exactly like `calculation` and `web` fallbacks today (`SearchUseCase.fallbackResults`). |
| `Kind.calculation` / `Kind.web` | Precedent for non-app result kinds; a `.currency` kind would follow the same shape. |
| `ActionDescriptor.copyToPasteboard` | The natural primary action: copy the converted amount so the user can paste it elsewhere. |
| `String(localized:)` + localisation rule | All user-visible text must be localised; conversion subtitles/titles follow this. |
| `Clock` port + injected `now` | Exchange-rate freshness and cache expiry need an injected clock, never `Date()`. |
| `Preferences` + `PreferencesStoring` | Toggle for "convert currency on amount queries", default base/local currency override, cache TTL. |
| `IconRef.systemSymbol` | Currency results can use a generic symbol icon (e.g. `dollarsign.circle`) without AppKit leaking into Domain. |
| Test infrastructure (`StubFileSearch`, `FixedClock`, fakes) | Pattern to follow for testing the converter in isolation. |

No new module, no new target, no new dependency is strictly required. The converter fits entirely inside the existing ports/adapters/seam structure.

---

## 3. What does NOT exist and must be added (audit findings)

### 3.1 Network — the app's first outbound call (ADR-level decision)

**Finding:** The codebase has zero network usage. `RillDomain` imports only Foundation; there is no `URLSession`, `URLRequest`, or `import Network` anywhere. `design.md` §9 (risks) lists "no network in v1" as an accepted constraint, and `architecture.md` §6 (dependencies) says the allowed dependency set is "none required for v1".

A currency converter *requires* exchange rates. Options, in order of preference for this codebase:

| Option | Description | Fit |
|---|---|---|
| **Frankfurter API** (`api.frankfurter.dev/v2/rate/{base}/{quote}`) | Free, no API key, 219 currencies, ECB reference rates, mid-market, no quotas, caching explicitly encouraged, public-domain-friendly privacy (no request logs). | Best fit. Zero dependency, standard `URLSession` behind a port. |
| Hardcoded daily snapshot bundled in the app | Offline, no network at all, but rates go stale immediately and there's no update mechanism. | Poor UX for a converter; violates "supports various currency" if a user types an exotic pair. |
| A paid API (ExchangeRate-API, OpenExchangeRates, etc.) | Requires an API key, secret management, and a new dependency justification. | Rejected: adds cost and complexity for a launcher feature. |

**Audit recommendation:** Use Frankfurter via a new port `CurrencyRateFetching` (Domain) + adapter `FrankfurterRateFetcher` (RillData, uses `URLSession`). Add one ADR entry. Cache rates in memory keyed by pair with a TTL (e.g. 24 h) so repeated keystrokes don't hammer the network; persist nothing to disk for rates (they're reference data, not user data).

### 3.2 Query parsing — no currency parser exists today

**Finding:** `SearchQuery` normalises text (fold, trim, tokens) but understands no currency syntax. The calculator fallback uses `ExpressionEvaluator.evaluate(raw)` which would choke on `$20`.

**Audit recommendation:** Add a small, pure `CurrencyParser` (Domain, Foundation only) that recognises:
- Symbol-prefixed: `$20`, `€50`, `£100`, `¥1000`, `Rp 20000`
- Code-suffixed/prefixed: `20 USD`, `50 EUR`, `1000 JPY`, `IDR 200000`
- Mixed: `20 USD to IDR`, `$20 in IDR`

It returns `CurrencyAmount { amount: Decimal; code: String }` or `nil`. `Decimal` is correct for money (no floating-point drift). This is a pure function → exhaustively testable, no Mac needed.

### 3.3 Local-currency detection — not present

**Finding:** No code reads the user's region or currency. Swift's `Locale.current` provides:
- `currencyCode` (e.g. `"IDR"`, `"USD"`)
- `regionCode` (e.g. `"ID"`, `"US"`)
- `currencySymbol` (e.g. `"Rp"`, `"$"`)

These are value types, read on `@MainActor` (Platform/UI) or injected via a port. The Domain must not call `Locale.current` directly (it's an ambient side effect); instead a port `LocaleProviding: Sendable { var currencyCode: String? { get } }` is implemented in RillData/RillPlatform and injected.

### 3.4 New result kind / section placement

**Finding:** `Section` has `fallback` last; `Kind` has `.calculation`, `.web`. A conversion result most naturally lives in `.fallback` (below apps/commands/files) so it never jumps above a launch target because of score quirks — consistent with design.md §4.5 ("ranking never crosses section boundaries").

**Audit recommendation:** Reuse `.fallback` section; add `Kind.currency`? Actually `.calculation` already covers numeric results. To keep the enum closed and minimal, reuse `.calculation` kind with a currency title, OR add `.currency`. Given "no abbreviation, one concept per enum case", adding `.currency` is cleaner than overloading `.calculation`. Decision deferred to implementation; either is defensible. I lean **add `.currency`** because the action (copy converted local amount) and subtitle ("20 USD = 320,000 IDR") differ meaningfully from a bare calculation.

---

## 4. Data flow (end to end), following the existing pattern

```
User types "$20"
    │
    ▼
PaletteViewModel.updateQuery("$20")  →  SearchQuery(raw: "$20")
    │
    ▼
SearchUseCase.callAsFunction(query)
    ├─ commands.commands                      (in-memory)
    ├─ applications.applications()            (actor)
    ├─ files.search(query)                    (Spotlight, optional)
    └─ NEW: currencyConverter.convert(query)  → CurrencyResult?
        ├─ CurrencyParser.parse("$20")        → {20, USD}  (pure)
        ├─ LocaleProviding.currencyCode       → "IDR"      (port)
        ├─ CurrencyRateFetching.rate(USD→IDR) → 16000      (network, cached)
        └─ 20 * 16000 = 320000 IDR
    │
    ▼
Ranking.rank(candidates, ...)   (pure, unchanged)
    │
    ▼
PaletteView renders fallback row:
    "$20 USD = Rp 320.000 IDR"   copy on Enter
```

The converter runs concurrently with the other providers via `async let`, and its failure degrades gracefully (no conversion row, other sections unaffected) — same pattern as `try?` file search.

---

## 5. Error & degradation handling (typed throws, per swift-standards)

| Failure | Behaviour |
|---|---|
| Query isn't a currency amount | `CurrencyParser` returns `nil`; no conversion row, silent. |
| Local currency unknown (`Locale.current.currencyCode == nil`) | Fall back to a default (USD) or skip; never crash. |
| Network unavailable / rate missing | Log via `os.Logger`, skip the conversion row; palette still shows apps/files. |
| Rate cache expired | Re-fetch on next query; stale rate acceptable for a launcher (reference rates update once/day). |
| Parsing ambiguous (`$` could be USD/CAD/AUD/...) | Default to the user's local currency if it's a dollar variant, else USD; document the heuristic. |

All errors are typed domain enums where the set is closed (`CurrencyError`), untyped `throws` only wrapping `URLSession` framework errors.

---

## 6. Concurrency & latency impact

- `CurrencyRateFetching.rate` is async (network). It runs in an `async let` alongside apps/commands/files, so it cannot block the ≤ 50 ms keystroke budget for the non-conversion sections.
- The conversion row may appear slightly later than instant results; that's acceptable for a fallback-level result. If the rate isn't cached, the row appears on a subsequent keystroke once the fetch completes — or not at all for a single keystroke. This is a deliberate trade: **correctness over instant conversion on the first keystroke**.
- No `Task.detached`, no `DispatchQueue`. Structured concurrency only, matching architecture.md §4.
- Cancellation: the search task is cancelled on each new keystroke; the in-flight rate fetch is abandoned via `Task.isCancelled` checks before publishing.

---

## 7. Localisation & user-facing text

- All strings via `String(localized:)`.
- Amount formatting uses `NumberFormatter` with `.currencyStyle` and the target `Locale` (e.g. `Rp 320.000` in Indonesia, `$320.00` in the US). Formatting lives in UI (RillUI), not Domain — Domain returns the raw `Decimal` amount and currency codes.
- No user-facing text in Domain (rule: design.md §3 / swift-standards §10).

---

## 8. Security & privacy

- Frankfurter is anonymous, no request logs, no IP retention (per their FAQ). Queries qualify as "data not collected" — no App Store privacy-label impact (moot since Rill is non-sandboxed, Developer ID).
- The user's typed amount (`$20`) is sent to Frankfurter as the base/quote currency codes only — the *amount* is never transmitted, only currency codes. No PII leaves the device except the currency pair (e.g. `USD/IDR`), which is not user-identifying.
- `currencyCode`/`regionCode` from `Locale.current` are read locally, never transmitted.

---

## 9. Tests required (before any code is considered done)

Following the repo's test rules (swift-standards §12):

1. `CurrencyParserTests` — parameterised: `$20` → USD 20, `€50` → EUR 50, `20 USD` → USD 20, `1000 JPY` → JPY 1000, `Rp 20000` → IDR 20000, `hello` → nil, empty → nil, ambiguous symbols → documented default.
2. `CurrencyConverterUseCaseTests` (fake `CurrencyRateFetching`, fake `LocaleProviding`, `FixedClock`) — conversion math, cache TTL expiry, degraded behaviour when rate fetch fails, local-currency fallback when `currencyCode` is nil.
3. `SearchUseCaseTests` addition — a typed currency query yields a fallback conversion row; non-currency queries unaffected.
4. No real clock, no real network, no `UserDefaults.standard`, temp dir only — per existing rules.

---

## 10. Docs / architecture changes required (tidy-up)

The architecture docs currently have no mention of currency, network, or exchange rates. To keep the docs clean and the contract binding:

1. **`architecture.md`** — add a `CurrencyRateFetching` port to §3 (ports), add the converter adapter to the module-graph responsibility table (RillData gains a network adapter), add an ADR entry (Frankfurter + first network call), add a `shortcut:` entry to §11 (network-free v1 is relaxed for this feature), and add the cache-TTL shortcut to §11.
2. **`design.md`** — add a currency-converter row to the behaviour-spec table (§4.2) and a latency note (§4.6) that conversion rows are fallback-tier and may appear after instant results.
3. **`swift-standards.md`** — no change needed (existing rules cover typed throws, `Decimal` for money, `Clock` injection, localisation).
4. **`AGENTS.md`** — no change needed (it references the docs above).

---

## 11. Shortcuts / deliberate deferrals (to be recorded as `shortcut:` comments)

| Shortcut | Upgrade trigger |
|---|---|
| Rates fetched live per query pair, cached in memory only (no disk persistence) | When conversion latency on cold start is complained about → persist daily rate snapshot to disk behind the same port. |
| Frankfurter default blended rates, no provider filter | When a user needs official reference rates for a specific country → add `providers=` filter option in Settings. |
| Local currency detected from `Locale.current`, no manual override | When users travel or want a fixed base currency → add "default currency" preference. |
| `$` symbol defaults to USD (or local dollar variant) | When symbol ambiguity causes wrong conversions → add explicit currency-code input (`20 CAD`). |
| No history of past conversions | When users ask to reuse recent conversions → add to usage/frecency model. |

---

## 12. Decision summary (audit outcome)

**Go / no-go:** Go. The feature fits the existing architecture with one new port (`CurrencyRateFetching`), one adapter (`FrankfurterRateFetcher`), one pure parser (`CurrencyParser`), one locale port (`LocaleProviding`), and one new `Kind.currency` result routed to `.fallback`. It is the app's first network call, so one ADR entry is required and the "no network in v1" note in `design.md` §9 must be amended.

**Do not implement yet.** This document is the audit. Implementation follows only after the docs are tidied (architecture.md + design.md updates above) and the user signs off.

**Not building:** an extension marketplace, AI, offline rate database, multi-currency manual input beyond symbol detection, or conversion history — all explicitly deferred via the shortcuts table.
