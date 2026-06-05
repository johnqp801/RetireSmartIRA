# In-App Review Prompt — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ask satisfied users for an App Store review after a high-value session, without interrupting them, on iOS and macOS — bundled into release 1.8.6.

**Architecture:** A pure, unit-testable `@Observable` `ReviewPromptManager` owns all logic and state (engagement counters in memory; two UserDefaults keys persisted). It performs NO StoreKit; the app's root view calls the SwiftUI `requestReview` action when the manager says so, at next launch. Three thin hooks feed events: a tab-5↔6 switch in `ContentView`, a debounced recalc in `TaxPlanningView`'s `scenarioBinding` setter, and launch in `RetireSmartIRAApp`. A manual "Rate" row in `SettingsView` opens the write-review URL.

**Tech Stack:** Swift, SwiftUI, Swift Testing (`@Test`/`#expect`), `@Observable`, `StoreKit` `@Environment(\.requestReview)` (iOS 16+/macOS 13+), UserDefaults.

**Spec:** `docs/superpowers/specs/2026-06-05-in-app-review-prompt-design.md`

---

## File Structure

- **Create** `RetireSmartIRA/ReviewPromptManager.swift` — all decision logic + persistence.
- **Create** `RetireSmartIRATests/ReviewPromptManagerTests.swift` — unit tests.
- **Modify** `RetireSmartIRA/RetireSmartIRAApp.swift` — instantiate + inject manager; on launch, `recordLaunch()` then fire if eligible.
- **Modify** `RetireSmartIRA/ContentView.swift` — in the existing `.onChange(of: selectedTab)` (~line 163), detect a `{5,6}` transition → `recordScenarioTaxSwitch()`.
- **Modify** `RetireSmartIRA/TaxPlanningView.swift` — in `scenarioBinding`'s setter (~line 1469) → `recordScenarioRecalc()`.
- **Modify** `RetireSmartIRA/SettingsView.swift` — add a "Rate RetireSmartIRA" row.

Test command (whole suite or one suite):
```
xcodebuild test -project RetireSmartIRA.xcodeproj -scheme RetireSmartIRA \
  -destination 'platform=macOS' -derivedDataPath /tmp/rsi-fix-ddata \
  -only-testing:RetireSmartIRATests/ReviewPromptManagerTests
```
(Drop `-only-testing` for the full suite. Note: `-only-testing` at the *function* level does not match Swift Testing — filter at the *suite* level.)

---

## Task 1: ReviewPromptManager — high-value detection (switch & recalc thresholds)

**Files:**
- Create: `RetireSmartIRA/ReviewPromptManager.swift`
- Test: `RetireSmartIRATests/ReviewPromptManagerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import Testing
import Foundation
@testable import RetireSmartIRA

@MainActor
@Suite("ReviewPromptManager", .serialized)
struct ReviewPromptManagerTests {

    /// Fresh isolated defaults per test so persisted keys don't leak.
    private func makeManager(now: @escaping () -> Date = { Date(timeIntervalSince1970: 0) },
                             version: String = "1.8.6") -> ReviewPromptManager {
        let suite = "test.review.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return ReviewPromptManager(defaults: defaults, currentVersion: version, now: now)
    }

    @Test("4 Scenario<->Tax switches set pendingRequest")
    func switchThresholdSetsPending() {
        let m = makeManager()
        for _ in 0..<3 { m.recordScenarioTaxSwitch() }
        #expect(m.pendingRequest == false)
        m.recordScenarioTaxSwitch()           // 4th
        #expect(m.pendingRequest == true)
    }

    @Test("Below both thresholds leaves pendingRequest false")
    func belowThresholdStaysFalse() {
        let m = makeManager()
        m.recordScenarioTaxSwitch()
        m.recordScenarioTaxSwitch()
        #expect(m.pendingRequest == false)
    }
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run the test command above.
Expected: FAIL — `cannot find 'ReviewPromptManager' in scope`.

- [ ] **Step 3: Create the manager (minimal to pass)**

`RetireSmartIRA/ReviewPromptManager.swift`:
```swift
import Foundation
import Observation

/// Decides when to ask the user for an App Store review, based on in-app engagement.
/// Pure logic + UserDefaults; performs NO StoreKit (the view does that).
@Observable
final class ReviewPromptManager {

    // Tunable constants
    static let switchThreshold = 4
    static let recalcThreshold = 6
    static let recalcDebounceInterval: TimeInterval = 1.0

    private let defaults: UserDefaults
    private let currentVersion: String
    private let now: () -> Date

    // In-memory per-session state
    private(set) var switchCount = 0
    private(set) var recalcCount = 0
    private var lastRecalcTime: Date?

    private enum Key {
        static let lastPromptedVersion = "reviewPrompt.lastPromptedVersion"
        static let pendingRequest = "reviewPrompt.pendingRequest"
    }

    init(defaults: UserDefaults = .standard,
         currentVersion: String = ReviewPromptManager.bundleMarketingVersion,
         now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.currentVersion = currentVersion
        self.now = now
    }

    static var bundleMarketingVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
    }

    // Read-only persisted accessors (tests read pendingRequest)
    var pendingRequest: Bool { defaults.bool(forKey: Key.pendingRequest) }
    private var lastPromptedVersion: String? {
        defaults.string(forKey: Key.lastPromptedVersion)
    }
    private var alreadyPromptedThisVersion: Bool { lastPromptedVersion == currentVersion }

    private func setPending(_ value: Bool) { defaults.set(value, forKey: Key.pendingRequest) }

    // Events
    func recordScenarioTaxSwitch() {
        switchCount += 1
        evaluateHighValue()
    }

    func recordScenarioRecalc() {
        recalcCount += 1
        evaluateHighValue()
    }

    private func evaluateHighValue() {
        guard !alreadyPromptedThisVersion, !pendingRequest else { return }
        if switchCount >= Self.switchThreshold || recalcCount >= Self.recalcThreshold {
            setPending(true)
        }
    }
}
```

- [ ] **Step 4: Run tests, verify they pass**

Run the test command. Expected: PASS (both tests).

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/ReviewPromptManager.swift RetireSmartIRATests/ReviewPromptManagerTests.swift
git commit -m "feat(review-prompt): ReviewPromptManager high-value detection"
```

---

## Task 2: Recalc debounce

**Files:**
- Modify: `RetireSmartIRA/ReviewPromptManager.swift`
- Test: `RetireSmartIRATests/ReviewPromptManagerTests.swift`

- [ ] **Step 1: Write failing tests**

Add inside `ReviewPromptManagerTests`:
```swift
    @Test("Rapid recalcs within debounce interval count as one")
    func recalcDebounceCoalesces() {
        var t = Date(timeIntervalSince1970: 0)
        let m = makeManager(now: { t })
        // 20 recalcs at the same instant (a single slider drag) -> counts as 1
        for _ in 0..<20 { m.recordScenarioRecalc() }
        #expect(m.recalcCount == 1)
        #expect(m.pendingRequest == false)
    }

    @Test("6 spaced recalcs cross the recalc threshold")
    func spacedRecalcsSetPending() {
        var t = Date(timeIntervalSince1970: 0)
        let m = makeManager(now: { t })
        for _ in 0..<6 {
            m.recordScenarioRecalc()
            t = t.addingTimeInterval(2)   // > 1.0s apart
        }
        #expect(m.recalcCount == 6)
        #expect(m.pendingRequest == true)
    }
```

- [ ] **Step 2: Run tests, verify they fail**

Expected: FAIL — `recalcDebounceCoalesces` sees `recalcCount == 20`.

- [ ] **Step 3: Add the debounce to `recordScenarioRecalc()`**

Replace the existing `recordScenarioRecalc()` with:
```swift
    func recordScenarioRecalc() {
        let t = now()
        if let last = lastRecalcTime, t.timeIntervalSince(last) < Self.recalcDebounceInterval {
            return
        }
        lastRecalcTime = t
        recalcCount += 1
        evaluateHighValue()
    }
```

- [ ] **Step 4: Run tests, verify they pass**

Expected: PASS (all four tests so far).

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/ReviewPromptManager.swift RetireSmartIRATests/ReviewPromptManagerTests.swift
git commit -m "feat(review-prompt): debounce rapid recalcs (slider drag = 1)"
```

---

## Task 3: Launch decision, version gate, session reset

**Files:**
- Modify: `RetireSmartIRA/ReviewPromptManager.swift`
- Test: `RetireSmartIRATests/ReviewPromptManagerTests.swift`

- [ ] **Step 1: Write failing tests**

Add inside `ReviewPromptManagerTests`:
```swift
    @Test("High-value session does not fire until next launch")
    func firesOnlyOnNextLaunch() {
        let m = makeManager()
        for _ in 0..<4 { m.recordScenarioTaxSwitch() }   // pending = true, same session
        #expect(m.pendingRequest == true)
        #expect(m.shouldRequestReviewOnLaunch() == true) // eligible, but the *view* only
                                                         // checks this right after recordLaunch()
        m.recordLaunch()                                 // simulate next launch
        #expect(m.shouldRequestReviewOnLaunch() == true)
    }

    @Test("recordLaunch resets per-session counters but not pending")
    func launchResetsCounters() {
        let m = makeManager()
        m.recordScenarioTaxSwitch()
        m.recordScenarioTaxSwitch()
        m.recordLaunch()
        #expect(m.switchCount == 0)
        #expect(m.recalcCount == 0)
    }

    @Test("markRequested gates further prompts for this version")
    func versionGate() {
        let m = makeManager(version: "1.8.6")
        for _ in 0..<4 { m.recordScenarioTaxSwitch() }
        #expect(m.shouldRequestReviewOnLaunch() == true)
        m.markRequested()
        #expect(m.pendingRequest == false)
        #expect(m.shouldRequestReviewOnLaunch() == false)
        // New high-value engagement does NOT re-arm for the same version
        for _ in 0..<4 { m.recordScenarioTaxSwitch() }
        #expect(m.pendingRequest == false)
    }
```

- [ ] **Step 2: Run tests, verify they fail**

Expected: FAIL — `cannot find 'shouldRequestReviewOnLaunch'` / `recordLaunch` / `markRequested`.

- [ ] **Step 3: Add the launch/decision API**

Add to `ReviewPromptManager`:
```swift
    /// Call once when the app becomes active. Resets per-session engagement counters.
    func recordLaunch() {
        switchCount = 0
        recalcCount = 0
        lastRecalcTime = nil
    }

    /// Whether the root view should request a review now (call right after recordLaunch()).
    func shouldRequestReviewOnLaunch() -> Bool {
        pendingRequest && !alreadyPromptedThisVersion
    }

    /// Call after the native review request has been made.
    func markRequested() {
        defaults.set(currentVersion, forKey: Key.lastPromptedVersion)
        setPending(false)
    }
```

- [ ] **Step 4: Run tests, verify they pass**

Expected: PASS (all seven tests).

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/ReviewPromptManager.swift RetireSmartIRATests/ReviewPromptManagerTests.swift
git commit -m "feat(review-prompt): next-launch decision + per-version gate"
```

---

## Task 4: Write-review URL builder (per platform)

**Files:**
- Modify: `RetireSmartIRA/ReviewPromptManager.swift`
- Test: `RetireSmartIRATests/ReviewPromptManagerTests.swift`

- [ ] **Step 1: Write failing test**

Add inside `ReviewPromptManagerTests`:
```swift
    @Test("Write-review URL targets app id 6759405282 with write-review action")
    func writeReviewURL() {
        let url = ReviewPromptManager.writeReviewURL.absoluteString
        #expect(url.contains("6759405282"))
        #expect(url.contains("action=write-review"))
        #if os(macOS)
        #expect(url.hasPrefix("macappstore://"))
        #else
        #expect(url.hasPrefix("https://apps.apple.com"))
        #endif
    }
```

- [ ] **Step 2: Run test, verify it fails**

Expected: FAIL — `type 'ReviewPromptManager' has no member 'writeReviewURL'`.

- [ ] **Step 3: Add the URL builder**

Add to `ReviewPromptManager`:
```swift
    static let appStoreID = "6759405282"

    /// Deep link to the App Store "write a review" page (per platform).
    static var writeReviewURL: URL {
        #if os(macOS)
        return URL(string: "macappstore://apps.apple.com/app/id\(appStoreID)?action=write-review")!
        #else
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!
        #endif
    }
```

- [ ] **Step 4: Run test, verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/ReviewPromptManager.swift RetireSmartIRATests/ReviewPromptManagerTests.swift
git commit -m "feat(review-prompt): per-platform write-review URL (id 6759405282)"
```

---

## Task 5: Wire the manager into the app (UI hooks)

UI wiring is verified by **build + manual run**, not unit tests. Do all edits, then build for both platforms.

**Files:**
- Modify: `RetireSmartIRA/RetireSmartIRAApp.swift`
- Modify: `RetireSmartIRA/ContentView.swift`
- Modify: `RetireSmartIRA/TaxPlanningView.swift`
- Modify: `RetireSmartIRA/SettingsView.swift`

- [ ] **Step 1: Instantiate + inject the manager, and fire on launch**

In `RetireSmartIRAApp.swift`, beside the existing `@State private var dataManager` (line ~27), add:
```swift
    @State private var reviewPrompt = ReviewPromptManager()
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
```
Inject it next to `.environment(dataManager)` (line ~43):
```swift
                    .environment(reviewPrompt)
```
On the same view that has `.environment(dataManager)`, add launch handling:
```swift
                    .task {
                        reviewPrompt.recordLaunch()
                        if reviewPrompt.shouldRequestReviewOnLaunch() {
                            requestReview()
                            reviewPrompt.markRequested()
                        }
                    }
```
> Note: if `@Environment(\.requestReview)` is not accessible at App scope on your SDK, move the
> `.task { … }` block (and the two `@Environment` lines) onto `ContentView`'s body instead —
> the manager is the same injected instance. Keep `recordLaunch()` before the eligibility check.

- [ ] **Step 2: Hook the Scenario↔Tax-Summary switch in ContentView**

In `ContentView.swift`, read the manager and extend the existing `.onChange(of: selectedTab)` (~line 163). Add near the other `@Environment`/`@State` of the struct:
```swift
    @Environment(ReviewPromptManager.self) private var reviewPrompt
```
Change the existing handler body from:
```swift
        .onChange(of: selectedTab) { _, newValue in
            // ...existing...
        }
```
to also detect a 5↔6 transition (use `oldValue`):
```swift
        .onChange(of: selectedTab) { oldValue, newValue in
            // ...existing body unchanged...
            let pair = Set([oldValue, newValue])
            if pair == Set([5, 6]) {        // Scenarios (5) <-> Tax Summary (6)
                reviewPrompt.recordScenarioTaxSwitch()
            }
        }
```
> If the existing closure signature is `{ _, newValue in }`, change the first `_` to `oldValue`.

- [ ] **Step 3: Hook the recalc in TaxPlanningView's scenarioBinding setter**

In `TaxPlanningView.swift`, add the manager to the view:
```swift
    @Environment(ReviewPromptManager.self) private var reviewPrompt
```
In `scenarioBinding` (~line 1469), inside the returned `Binding`'s `set:` closure, after the
existing `setter(...)` call, add:
```swift
            reviewPrompt.recordScenarioRecalc()
```
So the setter becomes (illustrative — keep the existing setter call):
```swift
        Binding<Double>(
            get: { property(dataManager.scenario) },
            set: { newValue in
                setter(dataManager.scenario, newValue)
                reviewPrompt.recordScenarioRecalc()
            }
        )
```

- [ ] **Step 4: Add the manual "Rate" row in SettingsView**

In `SettingsView.swift`, add a new `Section` (after the existing ones, before the close of the
`Form`/`List`):
```swift
            Section("Support") {
                Link(destination: ReviewPromptManager.writeReviewURL) {
                    Label("Rate RetireSmartIRA", systemImage: "star")
                }
            }
```

- [ ] **Step 5: Build both platforms (verify it compiles & injects)**

```bash
xcodebuild build -project RetireSmartIRA.xcodeproj -scheme RetireSmartIRA \
  -destination 'platform=macOS' -derivedDataPath /tmp/rsi-fix-ddata 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`. Repeat with `-destination 'generic/platform=iOS'`.
If you see "No ObservableObject of type ReviewPromptManager found" at runtime, the
`.environment(reviewPrompt)` injection (Step 1) is missing or below the view that reads it.

- [ ] **Step 6: Manual smoke test (run the app)**

1. Launch; bounce Scenarios↔Tax Summary 4 times → no prompt yet (fires next launch).
2. Quit and relaunch → native review sheet appears once. Relaunch again → does NOT reappear
   (version gate).
3. Settings → "Rate RetireSmartIRA" → opens the App Store write-review page (verify on **macOS**
   it opens the Mac App Store).

- [ ] **Step 7: Run the full test suite (no regressions)**

```bash
xcodebuild test -project RetireSmartIRA.xcodeproj -scheme RetireSmartIRA \
  -destination 'platform=macOS' -derivedDataPath /tmp/rsi-fix-ddata > /tmp/rsi-review-full.log 2>&1
grep -E "\*\* TEST (SUCCEEDED|FAILED)" /tmp/rsi-review-full.log | tail -1
```
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 8: Commit**

```bash
git add RetireSmartIRA/RetireSmartIRAApp.swift RetireSmartIRA/ContentView.swift \
        RetireSmartIRA/TaxPlanningView.swift RetireSmartIRA/SettingsView.swift
git commit -m "feat(review-prompt): wire manager into app, tabs, scenario binding, settings"
```

---

## Task 6: Version bump for 1.8.6

**Files:**
- Modify: `RetireSmartIRA.xcodeproj/project.pbxproj`

- [ ] **Step 1: Bump versions**

Set `MARKETING_VERSION = 1.8.6` and increment `CURRENT_PROJECT_VERSION` (next build number above
the shipped 50) for all targets. Verify both platforms build.

- [ ] **Step 2: Commit**

```bash
git add RetireSmartIRA.xcodeproj/project.pbxproj
git commit -m "chore(release): bump to 1.8.6"
```

---

## Notes for the implementer
- DRY/YAGNI: no remote config, no A/B, no analytics on who reviewed (App Store doesn't expose it).
- The manager is the only place with logic; keep StoreKit out of it (testability).
- Tabs 5/6 are the Scenarios/Tax-Summary pair — do not hardcode other indices.
- If `@Environment(\.requestReview)` won't resolve at App scope, host the launch `.task` on
  `ContentView` (see Task 5 Step 1 note); behavior is identical.
