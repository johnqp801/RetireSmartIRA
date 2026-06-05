# In-App Review Prompt — Design Spec

**Date:** 2026-06-05
**Status:** Approved (brainstorm) → ready for implementation plan
**Target release:** 1.8.6 (bundled with the stock-gain-avoided / dividend engine fixes)
**Platforms:** iOS 18+ and macOS 15+ (universal app, single Apple App ID)

---

## 1. Goal

Ask satisfied users for an App Store review at a moment they've clearly gotten value —
without interrupting their work and without pestering newcomers. Today the app has **zero**
review-request code; all existing ratings are organic. Adding a well-timed prompt is the
cheapest available lever on review volume.

Design principles:
- **Value-event trigger, not raw session counting.** Prompt when the user has actually
  engaged with the core loop, not merely opened the app N times.
- **Never fire mid-loop.** Detect a high-value session, then fire at a calm moment.
- **Lean on the OS throttle.** iOS/macOS already cap the native prompt (~3×/365 days, ~once
  per version, OS decides whether to actually show it). We add only a per-version gate — no
  maturity floor, no heavy custom rate-limiting.

## 2. Trigger logic — "got value"

A session is **high-value** when *either* signal crosses its bar (combined engagement):

| Signal | Threshold (constant) |
|---|---|
| Scenario↔Tax-Planning switches | `≥ 4` (`reviewSwitchThreshold`) |
| Scenario recalcs (slider/input changes) | `≥ 6` (`reviewRecalcThreshold`) |

Gated only by a **version gate**: prompt at most once per app marketing version
(`lastPromptedVersion`). The OS throttle (~3×/365 days, once per version, the OS decides
whether to actually show it) is the backstop on top of this.

**No maturity floor.** An earlier draft also gated on "≥ 2nd session AND ≥ 3 days since first
launch"; removed as too conservative. The value-event itself (4 switches or 6 recalcs) is
already a strong engagement signal — a user who does that much, even in their first session,
has genuinely explored — and the version gate plus the OS throttle prevent over-prompting.
Both thresholds are named constants for easy tuning.

## 3. Fire timing — next launch only

When a session becomes high-value, **do not interrupt**. Set a persisted
`pendingReviewRequest` flag and fire the native prompt at the **next app launch** — the first
calm moment after a high-value session ("rich session + returned," the strongest signal).

**Why not "return to Dashboard" within the session?** In this app the Dashboard (Tax Summary,
tab 6) is *half the exploration loop* — users bounce between Scenarios (tab 5) and Tax Summary
(tab 6) — so firing there would interrupt mid-loop. Next-launch is unambiguous and never
mid-loop.

On firing: call the native review request, set `lastPromptedVersion = currentVersion`, clear
`pendingReviewRequest`.

## 4. Manual escape hatch

A **"Rate RetireSmartIRA"** row in `SettingsView` that always opens the App Store
write-review page. This is the escape hatch and drives *written* reviews (the native dialog
mostly yields silent star ratings).

- **App Store App ID: `6759405282`** (universal app — same ID both platforms).
- iOS: `https://apps.apple.com/app/id6759405282?action=write-review`
- macOS: `macappstore://apps.apple.com/app/id6759405282?action=write-review`
- Scheme chosen via `#if os(macOS)`; verify on macOS that it opens the Mac App Store.

## 5. Architecture

A single, testable unit owns all logic and state:

### `ReviewPromptManager` (`@Observable`)
- **Event inputs:** `recordLaunch()`, `recordScenarioTaxSwitch()` (a tab-5↔tab-6 transition),
  `recordScenarioRecalc()`
- **Decision:** `shouldRequestReviewOnLaunch() -> Bool`, `markRequested()`
- **Recalc debounce:** `recordScenarioRecalc()` coalesces rapid calls (slider drags) to at most
  one per `recalcDebounceInterval` (1.0s), via an injectable `now: () -> Date` (default
  `Date.init`) used *only* for this debounce — deterministic in tests.
- **No StoreKit inside.** The manager only decides; the *view* performs the actual
  `requestReview`. This keeps the decision logic pure and unit-testable.

### Native prompt API
Use the SwiftUI **`@Environment(\.requestReview)`** action (available iOS 16+ / macOS 13+).
Deliberately avoid `SKStoreReviewRequest.requestReview(in: windowScene)` — its `UIWindowScene`
parameter is iOS-only and won't compile for macOS.

### Per-session vs persisted state
- **In memory (per session):** `switchCount`, `recalcCount` (reset on each launch).
- **Persisted (UserDefaults), 2 keys:** `lastPromptedVersion`, `pendingReviewRequest`.

## 6. Wiring — hook points

| Hook | Location | Call |
|---|---|---|
| Scenario↔Tax-Summary switch | `ContentView.onChange(of: selectedTab)` (~line 163): when `{old,new}` is the unordered pair `{5, 6}` | `recordScenarioTaxSwitch()` |
| Scenario recalc | `scenarioBinding` setter in `TaxPlanningView.swift:1469` (single choke point for all scenario edits) | `recordScenarioRecalc()` (debounced) |
| Launch + fire | `RetireSmartIRAApp` / root `.onAppear` (or `scenePhase` → active) | `recordLaunch()`; if `shouldRequestReviewOnLaunch()`, call `requestReview` then `markRequested()` |

Tabs: **5 = Scenarios** (`TaxPlanningView`), **6 = Tax Summary** (`DashboardView`).
`selectedTab` is updated on **both** platforms (iOS `TabView`; macOS sidebar maps into
`selectedTab` at ContentView ~line 161), so the switch hook fires on both via one code path.

## 7. Platform considerations (iOS + macOS)

1. **Native prompt:** SwiftUI `requestReview` works on both; the UIKit variant does not.
2. **Manual deep link:** platform-aware scheme; same App ID. **Must be verified on macOS**
   that the link opens the Mac App Store (the one real platform quirk).
3. **Hooks:** tab-switch (unified via `selectedTab`), recalc, and `scenePhase` are all
   cross-platform.

## 8. Testing

Unit-test `ReviewPromptManager` with an injected clock (`now`); no StoreKit in tests:
- 4 switches alone → sets `pendingReviewRequest`.
- 6 debounced recalcs alone → sets `pendingReviewRequest`.
- Below both thresholds → `pendingReviewRequest` stays false.
- **Recalc debounce:** many recalcs within `recalcDebounceInterval` count as one (a single
  slider drag must not trip the threshold).
- **Same-session gate:** after a high-value session, `shouldRequestReviewOnLaunch()` is false
  until the *next* `recordLaunch()`.
- **Next launch:** pending + unprompted version → `shouldRequestReviewOnLaunch()` true; after
  `markRequested()` it sets `lastPromptedVersion`, clears `pendingReviewRequest`, returns false.
- **Version gate:** once `lastPromptedVersion == currentVersion`, never true again.
- Manual "Rate" URL builder returns the correct per-platform write-review URL for id `6759405282`.

## 9. Release

Bundles with the three engine accuracy fixes (dividend double-count + stock-gain-avoided in
gross income + stock-gain-avoided in NII/impacts) into **one** release, **1.8.6**, off the
reconciled `main`. One App Store submission, one review wait — the explicit reason for
bundling rather than shipping two releases.

## 10. Out of scope (YAGNI)

- Custom rate-limiting beyond the version gate (the OS handles frequency).
- A/B testing thresholds or remote config.
- Tracking which users left reviews (App Store doesn't expose this).
- PDF-export as a trigger (rejected — under-fires for the power-user loop).
