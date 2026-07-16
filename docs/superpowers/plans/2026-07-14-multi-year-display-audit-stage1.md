# Multi-Year Display Audit Harness — Stage 0 + Stage 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a deterministic, in-repo gate that catches wrong values (and reconciliation/invariant violations) in every Multi-Year Plan display, and emits one structured packet per profile for the later multi-model layer (Stage 2).

**Architecture:** A Swift Testing suite in `RetireSmartIRATests/AuditHarness/`. It (1) enumerates a deterministic catalog of diverse households, (2) runs the real engine to snapshot exactly what each surface renders, (3) checks that snapshot against a set of invariants/identities (the property oracle, which reads engine OUTPUT and asserts relationships — it never re-derives a full projection), and (4) writes a JSON packet per profile to a known directory for Stage 2. Invariant violations fail the build.

**Tech Stack:** Swift, Swift Testing (`@Suite`/`@Test`, `@MainActor`), `Codable` for packets, `FileManager` for packet output. Reuses the shipped engine (`OptimizationEngine`, `ProjectionEngine`, `ApproachComparisonCoordinator`, `HeirFrontierCoordinator`, `PlanPathMetrics`, `MultiYearCPABriefing`).

## Global Constraints

- Swift Testing only (`import Testing`), `@MainActor`, `.serialized` suites — match existing multi-year tests.
- Scope all code searches to `RetireSmartIRA/` and `RetireSmartIRATests/`. Never grep `.build`, `DerivedData`, `.git`.
- **No network in Stage 1.** The deterministic core must run offline as part of the normal test suite.
- The property oracle asserts relationships on engine OUTPUT; it must NOT call the engine a second time to "confirm" a number against itself for the invariant checks. (Differential checks that run the engine with vs without a lever are allowed and explicitly noted where used.)
- Config is pinned: `let provider = TaxYearConfigProvider.fixed(TaxYearConfig.loadOrFallback(forYear: 2026))`. No `Date()`/RNG anywhere (reproducibility).
- Packets are written under `RetireSmartIRATests/AuditHarness/packets/` (git-ignored); the directory is created if absent.
- Run the full macOS suite green before considering any task done (project rule: 1,847+ tests are the source of truth).

---

### Task 1: Display Spec document (Stage 0)

**Files:**
- Create: `docs/superpowers/audit/multi-year-display-spec.md`

**Interfaces:**
- Produces: the authoritative list of display keys used by every later task. Each key is `surface.field` (e.g. `comparison.lifetimeTaxPV`, `frontier.heirsKeep`, `cpa.peakForcedRMD`). Tasks 3-5 reference these exact keys.

- [ ] **Step 1: Enumerate every Multi-Year display value.** Read `ApproachComparisonView.swift`, `HeirFrontierChartView.swift`, `HeirFrontierView.swift`, `ConversionLadderChart.swift`, `BalancesChart.swift`, `ThresholdMapChart.swift`, `MultiYearCPABriefing.swift`. For each rendered number, add a row to the doc.

- [ ] **Step 2: Write the spec table.** For each display key record: *represents*, *units* (`nominal$`/`pv$`/`%`/`count`/`age`), *formula* (in tax terms, not app code), and *invariants* ("correct means…"). Include at minimum:
  - `comparison.lifetimeTaxPV` — PV of owner in-horizon tax paid. Invariant: `= Σ realPresentValue(taxBreakdown.total)`; does NOT include terminal tax.
  - `comparison.deferredTaxOnRemainingIRA` — heir tax on ending traditional. Invariant: `grossEnding − deferred == heirsKeep`.
  - `comparison.endingTraditional/Roth/Taxable`, `comparison.heirsKeep`, `comparison.peakForcedRMD`.
  - `frontier.weight[]`, `frontier.ownerLifetimeTax`, `frontier.heirsKeep`. Invariant: no point dominated on both axes; heirsKeep non-decreasing in weight (within ε).
  - `ladder.conversionByYear` — invariant: `≤ availableTraditional` that year (no phantom).
  - `balances.traditional/roth/taxable[]` — invariant: non-negative every year.
  - `cliffmap.magiLine[]` vs `cliffmap.thresholds` — invariant: thresholds sourced from config, 2026 nominal.
  - `cpa.*` — every figure the PDF prints, each mapped to a `comparison.*`/`ladder.*` equivalent it must equal.

- [ ] **Step 3: Commit.**

```bash
git add docs/superpowers/audit/multi-year-display-spec.md
git commit -m "docs(audit): Stage 0 Multi-Year display spec (definition of correct)"
```

---

### Task 2: Deterministic profile catalog

**Files:**
- Create: `RetireSmartIRATests/AuditHarness/AuditProfiles.swift`
- Test: `RetireSmartIRATests/AuditHarness/AuditProfilesTests.swift`

**Interfaces:**
- Produces: `struct AuditProfile { let id: String; let inputs: MultiYearStaticInputs; let assumptions: MultiYearAssumptions; let approach: ConversionApproach; let heirWeight: Double }` and `enum AuditProfiles { static let all: [AuditProfile] }`.

- [ ] **Step 1: Write the failing test.**

```swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Audit — profile catalog", .serialized)
@MainActor
struct AuditProfilesTests {
    @Test("catalog is non-empty, ids unique, spans PA/IL/MS/CA/NJ and no-tax states")
    func catalogWellFormed() {
        let all = AuditProfiles.all
        #expect(all.count >= 24)
        #expect(Set(all.map(\.id)).count == all.count)
        let states = Set(all.map { $0.inputs.state })
        for s in ["PA", "IL", "MS", "CA", "NJ", "FL"] { #expect(states.contains(s)) }
    }
}
```

- [ ] **Step 2: Run to verify it fails.** Run: `xcodebuild test -project RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/AuditProfilesTests`. Expected: FAIL (`AuditProfiles` undefined).

- [ ] **Step 3: Implement the catalog.** Build a deterministic cross-product (filing × age × trad size × state × giving × approach × heirWeight) with fixed values. Reuse an `mfj(...)`/`single(...)` builder mirroring `HeirObjectiveTests.heirInputs` (baseYear 2026, growth 0.06, cpi 0.025, horizon 95). Include households that reproduce known findings: a PA 62 converter (I1), a residual-IRA high-income MFJ (B2), a $6M/CA MFJ (I3). No RNG — literal arrays.

- [ ] **Step 4: Run to verify it passes.** Same command. Expected: PASS.

- [ ] **Step 5: Commit.** `git add RetireSmartIRATests/AuditHarness/ && git commit -m "test(audit): deterministic Multi-Year profile catalog"`

---

### Task 3: Display snapshot extractor

**Files:**
- Create: `RetireSmartIRATests/AuditHarness/DisplaySnapshot.swift`
- Test: `RetireSmartIRATests/AuditHarness/DisplaySnapshotTests.swift`

**Interfaces:**
- Consumes: `AuditProfile`.
- Produces: `struct DisplaySnapshot: Codable` with fields keyed to the Task 1 spec (`comparison`, `frontier`, `ladder`, `balances`, `cliffmap`, `cpa`), and `static func capture(_ profile: AuditProfile, provider: TaxYearConfigProvider) -> DisplaySnapshot`.

- [ ] **Step 1: Write the failing test.**

```swift
@Test("snapshot captures the comparison columns and frontier points the views render")
func snapshotMirrorsViews() {
    let p = AuditProfiles.all.first { $0.id.contains("pa62") }!
    let provider = TaxYearConfigProvider.fixed(TaxYearConfig.loadOrFallback(forYear: 2026))
    let snap = DisplaySnapshot.capture(p, provider: provider)
    #expect(snap.comparison.selected.deferredTaxOnRemainingIRA >= 0)
    #expect(snap.frontier.points.count == 6)
    #expect(!snap.balances.traditional.isEmpty)
}
```

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (`DisplaySnapshot` undefined).

- [ ] **Step 3: Implement `capture`.** Call the same coordinators the views use: `ApproachComparisonCoordinator().compare(...)` for `comparison`; `HeirFrontierCoordinator().computeFrontier(...)` for `frontier`; the selected path's `executedRothConversion`/`endOfYearBalances`/`rmd`/`magi`/`agi` arrays for `ladder`/`balances`/`cliffmap`; `MultiYearCPABriefing` build output for `cpa`. Store plain `Codable` structs (mirror `ApproachColumn` fields exactly, incl. `deferredTaxOnRemainingIRA`).

- [ ] **Step 4: Run to verify it passes.** Expected: PASS.

- [ ] **Step 5: Commit.** `git commit -am "test(audit): DisplaySnapshot extractor mirrors Multi-Year surfaces"`

---

### Task 4: Property oracle (invariants + identities, incl. the 2026-07-14 findings)

**Files:**
- Create: `RetireSmartIRATests/AuditHarness/DisplayInvariants.swift`
- Test: `RetireSmartIRATests/AuditHarness/DisplayInvariantsTests.swift`

**Interfaces:**
- Consumes: `AuditProfile`, `DisplaySnapshot`.
- Produces: `struct InvariantViolation: Codable { let key: String; let detail: String }` and `enum DisplayInvariants { static func check(_ profile: AuditProfile, _ snap: DisplaySnapshot, provider: TaxYearConfigProvider) -> [InvariantViolation] }`.

- [ ] **Step 1: Write the failing test.**

```swift
@Test("deferred-tax reconciliation invariant holds for a residual-IRA profile")
func deferredTaxReconciles() {
    let p = AuditProfiles.all.first { $0.id.contains("residual") }!
    let provider = TaxYearConfigProvider.fixed(TaxYearConfig.loadOrFallback(forYear: 2026))
    let snap = DisplaySnapshot.capture(p, provider: provider)
    let violations = DisplayInvariants.check(p, snap, provider: provider)
    // No reconciliation violation: grossEnding - deferred == heirsKeep.
    #expect(!violations.contains { $0.key == "comparison.deferredReconciliation" })
}
```

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (`DisplayInvariants` undefined).

- [ ] **Step 3: Implement the first invariant set.** Each returns a violation only when broken (ε = 1.0):
  - `comparison.deferredReconciliation`: `|(endingRoth+endingTaxable+endingTraditional − deferredTaxOnRemainingIRA) − heirsKeep| < 1`.
  - `frontier.nonDominated`: no point has both higher ownerLifetimeTax AND lower heirsKeep than another; `heirsKeep` non-decreasing in `weight` within ε.
  - `ladder.noPhantom`: each year's `executedRothConversion ≤ start-of-year convertible traditional`.
  - `magi.geAGI`: each year `magi ≥ agi − 1` (A3 fingerprint surfaces as violation if broken by gross-up).
  - `balances.nonNegative`: every balance series ≥ −1 every year.
  - `state.paConversionExempt`: for PA/IL/MS profiles with a 59½+ owner, the state tax attributable to the conversion is ~0. Compute differentially: project the same profile with vs without the year's conversion (this is the one allowed second engine run) and assert the state-tax delta < 1 for those states. (Catches I1.)

- [ ] **Step 4: Run to verify it passes** on the current branch. Expected: PASS (this branch has I1/I3/B2 fixed). Expected on `main`: these invariants FIRE — that is the harness reproducing the findings, and is asserted in Task 5.

- [ ] **Step 5: Commit.** `git commit -am "test(audit): property oracle — reconciliation, frontier, phantom, MAGI, PA-conversion invariants"`

---

### Task 5: Packet emission + the standing gate

**Files:**
- Create: `RetireSmartIRATests/AuditHarness/AuditPacket.swift`
- Create: `RetireSmartIRATests/AuditHarness/AuditGateTests.swift`
- Modify: `.gitignore` (add `RetireSmartIRATests/AuditHarness/packets/`)

**Interfaces:**
- Consumes: `AuditProfile`, `DisplaySnapshot`, `InvariantViolation`.
- Produces: `struct AuditPacket: Codable { let profileId: String; let inputsSummary: [String: String]; let snapshot: DisplaySnapshot; let violations: [InvariantViolation] }` and `enum AuditPacketWriter { static func write(_ packets: [AuditPacket], to dir: URL) throws }`. Stage 2 (separate plan) consumes these packets.

- [ ] **Step 1: Write the failing test.**

```swift
@Test("gate: every catalog profile snapshots, and packets are written")
func gateRunsAndWritesPackets() throws {
    let provider = TaxYearConfigProvider.fixed(TaxYearConfig.loadOrFallback(forYear: 2026))
    var packets: [AuditPacket] = []
    var allViolations: [InvariantViolation] = []
    for p in AuditProfiles.all {
        let snap = DisplaySnapshot.capture(p, provider: provider)
        let v = DisplayInvariants.check(p, snap, provider: provider)
        allViolations += v
        packets.append(AuditPacket(profileId: p.id, inputsSummary: p.summary, snapshot: snap, violations: v))
    }
    let dir = URL(fileURLWithPath: "RetireSmartIRATests/AuditHarness/packets", isDirectory: true)
    try AuditPacketWriter.write(packets, to: dir)
    #expect(packets.count == AuditProfiles.all.count)
    // HARD GATE: on this fixed-fix branch, no invariant may fire.
    #expect(allViolations.isEmpty, "display invariant violations: \(allViolations)")
}
```

- [ ] **Step 2: Run to verify it fails.** Expected: FAIL (`AuditPacket`/`AuditPacketWriter`/`p.summary` undefined).

- [ ] **Step 3: Implement packet + writer.** Add `AuditProfile.summary: [String: String]` (state, filing, age, trad, approach, heirWeight). `AuditPacketWriter.write` creates `dir` and writes one `<profileId>.json` per packet via `JSONEncoder` (`.prettyPrinted`, `.sortedKeys`). Add the packets dir to `.gitignore`.

- [ ] **Step 4: Run to verify it passes.** Expected: PASS on this branch (all fixes present → `allViolations` empty). Then confirm the harness *reproduces findings on main*: check out `main` into a scratch worktree, run the same suite, and confirm `state.paConversionExempt`, `frontier.nonDominated`, and `comparison.deferredReconciliation` (absent on main — no deferred row) fire. Note the result in the commit message; do not commit the scratch run.

- [ ] **Step 5: Run the full macOS suite** to confirm no regressions: `xcodebuild test -project RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS'`. Expected: all green.

- [ ] **Step 6: Commit.** `git commit -am "test(audit): standing display-audit gate + JSON packet emission for Stage 2"`

---

## Self-Review

- **Spec coverage:** Stage 0 → Task 1. Profile generator → Task 2. Display extractor → Task 3. Oracle (property/invariant) → Task 4. Differ/packets/hard-gate → Task 5. Exact-value oracle for complex series is intentionally deferred (see Non-goals in the spec §9: property/invariant is the v1 truth; a full independent re-projection is impractical and not attempted). Stage 2 (multi-model runner) → separate Plan B. Scope §6 surfaces are all captured in Task 3 and keyed via Task 1.
- **Placeholder scan:** none — every task has concrete test + implementation direction and exact commands.
- **Type consistency:** `AuditProfile`, `DisplaySnapshot`, `InvariantViolation`, `AuditPacket`, `AuditProfiles.all`, `DisplaySnapshot.capture`, `DisplayInvariants.check`, `AuditPacketWriter.write`, `AuditProfile.summary` are defined once and referenced consistently.

## Follow-on (not this plan)

- **Plan B — Stage 2 multi-model runner:** provider-agnostic CLI that reads `packets/*.json` + the Task 1 spec, sends to GPT + Gemini (+ optional Claude), requires ≥2-model consensus to flag, surfaces disagreements only. Blocked on this plan's packet output.
- Extend the invariant set as new display types land (per-year income/expense overrides in the v2.2 feature work).
