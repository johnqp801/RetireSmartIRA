# State Tax Phase 1: JSON Extraction (Behavior-Inert) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move all 51 jurisdictions' tax configuration out of hardcoded Swift into schema-validated JSON bundled with the app, proving via an equivalence gate that not one computed number changed.

**Architecture:** Make the existing `StateTaxConfig` value types `Codable`, then **generate** the 51 JSON files from the in-memory `configs2026` table rather than transcribing them. The hardcoded table is retained as `configs2026Legacy` and becomes the test oracle: an equivalence suite asserts JSON-loaded configs produce byte-identical state tax across a scenario grid. Correctness of the *data* is explicitly out of scope for this phase; only fidelity of the *move* is tested.

**Tech Stack:** Swift 5.9+, Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`), Foundation `JSONEncoder`/`JSONDecoder`, Xcode scheme `RetireSmartIRA`.

## Global Constraints

- Platform target: native macOS (NOT Catalyst) + iOS/iPadOS, universal binary, iOS 18 / macOS 15.
- Test command: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS'`
- The full suite is the source of truth: **1,570 Swift Testing tests in 265 suites + 503 XCTest**. A change is not done until the suite is green.
- Scope searches to `RetireSmartIRA/` and `RetireSmartIRATests/`. Never grep `node_modules`, `.build`, `DerivedData`, `.git`, `Pods/`.
- **This phase changes no computed value.** Any diff in engine output is a bug in this phase, not a correction. Corrections happen in Phase 5.
- **Never hand-transcribe state data.** All JSON is generated from `configs2026Legacy`. Hand-transcription would inject the exact class of error this program exists to remove.
- No em dash characters in any comment, string, or documentation produced.
- `configs2026Legacy` is retained through Phase 3 as the equivalence oracle. Do not delete it in this phase.

## File Structure

**Create:**
- `RetireSmartIRA/StateTaxVerification.swift` — `StateVerification` metadata type. One job: carry provenance (date, sources, bill refs, known limitations) for one jurisdiction.
- `RetireSmartIRA/StateTaxCodable.swift` — hand-written `Codable` conformances for the five enums carrying associated values. One job: stable JSON representation of enums Swift cannot synthesize.
- `RetireSmartIRA/StateTaxDataLoader.swift` — loads and decodes bundled JSON into `[USState: StateTaxConfig]`. One job: I/O and decode.
- `RetireSmartIRA/Resources/StateTaxData/2026/*.json` — 51 generated files.
- `RetireSmartIRATests/StateTaxCodableRoundTripTests.swift` — per-type encode/decode round trips.
- `RetireSmartIRATests/StateTaxDataGeneratorTests.swift` — the generator, run as a test that writes the 51 files.
- `RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift` — **the Phase 1 gate.**

**Modify:**
- `RetireSmartIRA/StateTaxData.swift:470` — rename `configs2026` to `configs2026Legacy`, add loader-backed `configs2026`.
- `RetireSmartIRA/StateTaxData.swift:2068-2069` — route `config(for:)` through the loader.

---

### Task 1: `StateVerification` metadata type

**Files:**
- Create: `RetireSmartIRA/StateTaxVerification.swift`
- Test: `RetireSmartIRATests/StateTaxCodableRoundTripTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `struct StateVerification: Codable, Equatable, Sendable` with `lastVerified: String` (ISO `yyyy-MM-dd`), `primarySources: [String]`, `billReferences: [String]`, `knownLimitations: [String]`. Task 7 embeds this in `StateTaxConfig`.

`lastVerified` is `String` rather than `Date` deliberately: it is a calendar date with no time zone meaning, and `Date` round-trips lossily through JSON in a way that would make the equivalence test flaky.

- [ ] **Step 1: Write the failing test**

Create `RetireSmartIRATests/StateTaxCodableRoundTripTests.swift`:

```swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("State tax Codable round trips (Phase 1)")
struct StateTaxCodableRoundTripTests {

    @Test("StateVerification round-trips through JSON")
    func verificationRoundTrips() throws {
        let original = StateVerification(
            lastVerified: "2026-08-02",
            primarySources: ["https://www.ksrevenue.gov/webfile/help/scheduleS_A.html"],
            billReferences: ["SB 1 (2024 special session)"],
            knownLimitations: ["Public pensions are not distinguished from private."]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StateVerification.self, from: data)
        #expect(decoded == original)
    }

    @Test("StateVerification defaults to unverified with empty collections")
    func verificationUnverifiedDefault() {
        let unverified = StateVerification.unverified
        #expect(unverified.lastVerified == "")
        #expect(unverified.primarySources.isEmpty)
        #expect(unverified.knownLimitations.isEmpty)
        #expect(unverified.isVerified == false)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxCodableRoundTripTests`
Expected: FAIL to compile with "cannot find 'StateVerification' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `RetireSmartIRA/StateTaxVerification.swift`:

```swift
import Foundation

/// Provenance for one jurisdiction's tax configuration.
///
/// Required by schema on every state file. A jurisdiction cannot be added
/// without a primary source and a verification date. That requirement is the
/// forcing function: the 2026-08-02 audit found roughly 29 of 51 jurisdictions
/// defective, and Wisconsin was wrong while carrying a "verified" code comment,
/// because nothing structural required the comment to mean anything.
struct StateVerification: Codable, Equatable, Sendable {
    /// ISO `yyyy-MM-dd`. Empty string means never verified.
    ///
    /// Deliberately a String, not a Date: this is a calendar date with no
    /// time-zone meaning, and Date round-trips lossily through JSON in a way
    /// that would make the Phase 1 equivalence test flaky.
    let lastVerified: String

    /// State DOR pages, statutes, or enrolled bills. Advisor blogs and
    /// tax-prep vendor help pages are not admissible here.
    let primarySources: [String]

    /// Bill numbers with their disposition, e.g. "SB25-136 (postponed indefinitely)".
    let billReferences: [String]

    /// Plain sentences describing what this app does NOT model for this state.
    /// Surfaced verbatim in the disclosure UI. Required, may be empty.
    let knownLimitations: [String]

    var isVerified: Bool { !lastVerified.isEmpty }

    /// Placeholder for jurisdictions carrying no verification stamp today.
    /// Phase 1 assigns this to every state that lacks a "Verified" comment.
    static let unverified = StateVerification(
        lastVerified: "",
        primarySources: [],
        billReferences: [],
        knownLimitations: []
    )
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxCodableRoundTripTests`
Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/StateTaxVerification.swift RetireSmartIRATests/StateTaxCodableRoundTripTests.swift
git commit -m "feat(state-tax): add StateVerification provenance type"
```

---

### Task 2: `Codable` for `StateTaxSystem`

**Files:**
- Create: `RetireSmartIRA/StateTaxCodable.swift`
- Modify: `RetireSmartIRATests/StateTaxCodableRoundTripTests.swift`

**Interfaces:**
- Consumes: `StateTaxSystem` (`StateTaxData.swift:132`), `TaxBracket` (`TaxModels.swift:10`, already `Codable`).
- Produces: `extension StateTaxSystem: Codable`. JSON shape is a tagged object: `{"kind": "flat", "rate": 0.038}`.

`TaxBracket` carries `var id = UUID()`, which is `Codable` but generates a fresh UUID per decode. The equivalence test compares computed tax, not bracket identity, so this is harmless. Do not attempt to preserve `id` across the round trip.

- [ ] **Step 1: Write the failing test**

Append to `StateTaxCodableRoundTripTests.swift`, inside the suite:

```swift
    @Test("StateTaxSystem round-trips every case")
    func taxSystemRoundTrips() throws {
        let cases: [StateTaxSystem] = [
            .noIncomeTax,
            .specialLimited,
            .flat(rate: 0.038),
            .progressive(
                single: [TaxBracket(threshold: 0, rate: 0.052),
                         TaxBracket(threshold: 23_000, rate: 0.0558)],
                married: [TaxBracket(threshold: 0, rate: 0.052),
                          TaxBracket(threshold: 46_000, rate: 0.0558)]
            )
        ]
        for original in cases {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(StateTaxSystem.self, from: data)
            #expect(decoded.matchesShape(of: original), "round trip lost \(original)")
        }
    }
```

Add this test-only helper at file scope in the same test file, below the suite:

```swift
extension StateTaxSystem {
    /// Structural equality ignoring TaxBracket.id, which is regenerated on decode.
    func matchesShape(of other: StateTaxSystem) -> Bool {
        switch (self, other) {
        case (.noIncomeTax, .noIncomeTax), (.specialLimited, .specialLimited):
            return true
        case let (.flat(a), .flat(b)):
            return a == b
        case let (.progressive(s1, m1), .progressive(s2, m2)):
            let sameBrackets: ([TaxBracket], [TaxBracket]) -> Bool = { x, y in
                x.count == y.count && zip(x, y).allSatisfy {
                    $0.threshold == $1.threshold && $0.rate == $1.rate
                }
            }
            return sameBrackets(s1, s2) && sameBrackets(m1, m2)
        default:
            return false
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxCodableRoundTripTests`
Expected: FAIL to compile, "instance method 'encode' requires that 'StateTaxSystem' conform to 'Encodable'".

- [ ] **Step 3: Write minimal implementation**

Create `RetireSmartIRA/StateTaxCodable.swift`:

```swift
import Foundation

// Hand-written Codable conformances for the enums carrying associated values.
// Swift cannot synthesize these. Each uses an explicit "kind" discriminator so
// the JSON stays readable and reviewable by a non-Swift reader, which is one of
// the reasons the data is moving to JSON at all.

extension StateTaxSystem: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, rate, single, married
    }
    private enum Kind: String, Codable {
        case noIncomeTax, flat, progressive, specialLimited
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .noIncomeTax:
            try c.encode(Kind.noIncomeTax, forKey: .kind)
        case .specialLimited:
            try c.encode(Kind.specialLimited, forKey: .kind)
        case .flat(let rate):
            try c.encode(Kind.flat, forKey: .kind)
            try c.encode(rate, forKey: .rate)
        case .progressive(let single, let married):
            try c.encode(Kind.progressive, forKey: .kind)
            try c.encode(single, forKey: .single)
            try c.encode(married, forKey: .married)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .noIncomeTax:
            self = .noIncomeTax
        case .specialLimited:
            self = .specialLimited
        case .flat:
            self = .flat(rate: try c.decode(Double.self, forKey: .rate))
        case .progressive:
            self = .progressive(
                single: try c.decode([TaxBracket].self, forKey: .single),
                married: try c.decode([TaxBracket].self, forKey: .married)
            )
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxCodableRoundTripTests`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/StateTaxCodable.swift RetireSmartIRATests/StateTaxCodableRoundTripTests.swift
git commit -m "feat(state-tax): Codable conformance for StateTaxSystem"
```

---

### Task 3: `Codable` for `StateDeduction` and `EstimatedPaymentSchedule`

**Files:**
- Modify: `RetireSmartIRA/StateTaxCodable.swift`
- Modify: `RetireSmartIRA/PlanningModels.swift:100` (add `Codable` to `EstimatedPaymentSchedule`'s conformance list)
- Modify: `RetireSmartIRATests/StateTaxCodableRoundTripTests.swift`

**Interfaces:**
- Consumes: `StateDeduction` (`StateTaxData.swift:353`), `EstimatedPaymentSchedule` (`PlanningModels.swift:100`).
- Produces: `extension StateDeduction: Codable`; `EstimatedPaymentSchedule: Codable`. `StateDeduction` JSON shape: `{"kind": "fixed", "single": 3360, "married": 3360}`.

`EstimatedPaymentSchedule` is a struct of four `Double`s, so its conformance is synthesized. Only the declaration needs changing.

- [ ] **Step 1: Write the failing test**

Append inside the suite:

```swift
    @Test("StateDeduction round-trips every case")
    func stateDeductionRoundTrips() throws {
        let cases: [StateDeduction] = [
            .none,
            .conformsToFederal,
            .fixed(single: 3_360, married: 3_360)
        ]
        for original in cases {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(StateDeduction.self, from: data)
            switch (decoded, original) {
            case (.none, .none), (.conformsToFederal, .conformsToFederal):
                break
            case let (.fixed(s1, m1), .fixed(s2, m2)):
                #expect(s1 == s2 && m1 == m2)
            default:
                Issue.record("round trip lost \(original)")
            }
        }
    }

    @Test("EstimatedPaymentSchedule round-trips")
    func estimatedScheduleRoundTrips() throws {
        let original = EstimatedPaymentSchedule.california
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EstimatedPaymentSchedule.self, from: data)
        #expect(decoded == original)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxCodableRoundTripTests`
Expected: FAIL to compile on both `StateDeduction` and `EstimatedPaymentSchedule` conformance.

- [ ] **Step 3: Write minimal implementation**

Append to `RetireSmartIRA/StateTaxCodable.swift`:

```swift
extension StateDeduction: Codable {
    private enum CodingKeys: String, CodingKey { case kind, single, married }
    private enum Kind: String, Codable { case none, conformsToFederal, fixed }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try c.encode(Kind.none, forKey: .kind)
        case .conformsToFederal:
            try c.encode(Kind.conformsToFederal, forKey: .kind)
        case .fixed(let single, let married):
            try c.encode(Kind.fixed, forKey: .kind)
            try c.encode(single, forKey: .single)
            try c.encode(married, forKey: .married)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .none: self = .none
        case .conformsToFederal: self = .conformsToFederal
        case .fixed:
            self = .fixed(
                single: try c.decode(Double.self, forKey: .single),
                married: try c.decode(Double.self, forKey: .married)
            )
        }
    }
}
```

In `RetireSmartIRA/PlanningModels.swift`, change line 100 from:

```swift
struct EstimatedPaymentSchedule: Equatable, Sendable {
```

to:

```swift
struct EstimatedPaymentSchedule: Codable, Equatable, Sendable {
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxCodableRoundTripTests`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/StateTaxCodable.swift RetireSmartIRA/PlanningModels.swift RetireSmartIRATests/StateTaxCodableRoundTripTests.swift
git commit -m "feat(state-tax): Codable for StateDeduction and EstimatedPaymentSchedule"
```

---

### Task 4: `Codable` for `StateSafeHarborRule`

**Files:**
- Modify: `RetireSmartIRA/StateTaxCodable.swift`
- Modify: `RetireSmartIRATests/StateTaxCodableRoundTripTests.swift`

**Interfaces:**
- Consumes: `StateSafeHarborRule` (`PlanningModels.swift:162`).
- Produces: `extension StateSafeHarborRule: Codable`.

Before writing the conformance, read `PlanningModels.swift:162` through the end of the enum and enumerate **every** case including any beyond `mirrorsFederal`, `flatRate`, `agiThreshold`, and the California disqualification case. The switch must be exhaustive or it will not compile, which is the desired safety property.

- [ ] **Step 1: Write the failing test**

Append inside the suite:

```swift
    @Test("StateSafeHarborRule round-trips every case")
    func safeHarborRoundTrips() throws {
        let cases: [StateSafeHarborRule] = [
            .mirrorsFederal,
            .flatRate(1.10),
            .agiThreshold(threshold: 250_000, lowRate: 1.00, highRate: 1.10)
        ]
        for original in cases {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(StateSafeHarborRule.self, from: data)
            #expect(decoded == original, "round trip lost \(original)")
        }
    }

```

A companion test that exercises every safe-harbor rule the real table actually uses is added in Task 8, once `configs2026Legacy` exists. It is not written here, because writing a test and immediately commenting it out leaves dead code in the tree across three commits.

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxCodableRoundTripTests`
Expected: FAIL to compile, "instance method 'encode' requires that 'StateSafeHarborRule' conform to 'Encodable'".

- [ ] **Step 3: Write minimal implementation**

Append to `RetireSmartIRA/StateTaxCodable.swift`, extending the switch to cover every case found in `PlanningModels.swift`:

```swift
extension StateSafeHarborRule: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, rate, threshold, lowRate, highRate
    }
    private enum Kind: String, Codable {
        case mirrorsFederal, flatRate, agiThreshold
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .mirrorsFederal:
            try c.encode(Kind.mirrorsFederal, forKey: .kind)
        case .flatRate(let rate):
            try c.encode(Kind.flatRate, forKey: .kind)
            try c.encode(rate, forKey: .rate)
        case .agiThreshold(let threshold, let lowRate, let highRate):
            try c.encode(Kind.agiThreshold, forKey: .kind)
            try c.encode(threshold, forKey: .threshold)
            try c.encode(lowRate, forKey: .lowRate)
            try c.encode(highRate, forKey: .highRate)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .mirrorsFederal:
            self = .mirrorsFederal
        case .flatRate:
            self = .flatRate(try c.decode(Double.self, forKey: .rate))
        case .agiThreshold:
            self = .agiThreshold(
                threshold: try c.decode(Double.self, forKey: .threshold),
                lowRate: try c.decode(Double.self, forKey: .lowRate),
                highRate: try c.decode(Double.self, forKey: .highRate)
            )
        }
    }
}
```

If the compiler reports the switch is not exhaustive, add the missing case to both `Kind` and both switches. Do not use a `default:` branch: exhaustiveness is the point, because a silently unhandled safe-harbor case would decode to the wrong rule.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxCodableRoundTripTests`
Expected: PASS, 6 tests with the second test still commented out.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/StateTaxCodable.swift RetireSmartIRATests/StateTaxCodableRoundTripTests.swift
git commit -m "feat(state-tax): Codable for StateSafeHarborRule"
```

---

### Task 5: `Codable` for `ExemptionLevel`

**Files:**
- Modify: `RetireSmartIRA/StateTaxCodable.swift`
- Modify: `RetireSmartIRATests/StateTaxCodableRoundTripTests.swift`

**Interfaces:**
- Consumes: `RetirementIncomeExemptions.ExemptionLevel` (`StateTaxData.swift:252`), `RetirementIncomeExemptions.PhaseoutTier` (`StateTaxData.swift:243`).
- Produces: `extension RetirementIncomeExemptions.PhaseoutTier: Codable`, `extension RetirementIncomeExemptions.ExemptionLevel: Codable`.

This is the most intricate conformance because `.steppedPhaseoutByFilingStatus` carries three associated values including an array of structs. New Jersey is the only state using it today and its behavior is verified correct, so a silent loss here would be a regression in working code.

- [ ] **Step 1: Write the failing test**

Append inside the suite:

```swift
    @Test("ExemptionLevel round-trips every case including NJ's stepped phaseout")
    func exemptionLevelRoundTrips() throws {
        let cases: [RetirementIncomeExemptions.ExemptionLevel] = [
            .none,
            .full,
            .partial(maxExempt: 31_110),
            .steppedPhaseoutByFilingStatus(
                maxExemptSingle: 75_000,
                maxExemptMFJ: 100_000,
                tiers: [
                    .init(upperBound: 100_000, mfjPercent: 1.0, singlePercent: 1.0),
                    .init(upperBound: 125_000, mfjPercent: 0.50, singlePercent: 0.375),
                    .init(upperBound: 150_000, mfjPercent: 0.25, singlePercent: 0.1875),
                    .init(upperBound: .infinity, mfjPercent: 0.0, singlePercent: 0.0)
                ]
            )
        ]
        for original in cases {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(
                RetirementIncomeExemptions.ExemptionLevel.self, from: data)
            // Compare behaviorally: the exclusion each produces must match.
            for income in [40_000.0, 90_000.0, 130_000.0, 200_000.0] {
                for married in [true, false] {
                    #expect(
                        decoded.excludedAmount(eligibleIncome: 50_000,
                                               totalGrossIncome: income,
                                               isMarried: married,
                                               perIndividualMultiplier: 1)
                        == original.excludedAmount(eligibleIncome: 50_000,
                                                   totalGrossIncome: income,
                                                   isMarried: married,
                                                   perIndividualMultiplier: 1),
                        "round trip changed behavior at income \(income) married \(married)")
                }
            }
        }
    }
```

Comparing behavior rather than structure is deliberate: it is the property actually required, and it will catch a subtly wrong tier ordering that a field-by-field check could miss.

The signature is verified: `excludedAmount(eligibleIncome:totalGrossIncome:isMarried:perIndividualMultiplier:)` at `StateTaxData.swift:286-291`, with `perIndividualMultiplier` defaulting to `1.0`. `.infinity` must survive the round trip; `JSONEncoder` rejects non-conforming floats by default, which Step 3 handles with a sentinel.

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxCodableRoundTripTests`
Expected: FAIL to compile, `ExemptionLevel` does not conform to `Encodable`.

- [ ] **Step 3: Write minimal implementation**

Append to `RetireSmartIRA/StateTaxCodable.swift`:

```swift
extension RetirementIncomeExemptions.PhaseoutTier: Codable {
    private enum CodingKeys: String, CodingKey {
        case upperBound, mfjPercent, singlePercent
    }

    // Foundation's JSONEncoder throws on non-conforming floats by default, and
    // NJ's open-ended cliff band uses .infinity as its upper bound. Encode it
    // as a sentinel string so the JSON stays valid and human-readable.
    private static let infinitySentinel = "unbounded"

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if upperBound.isInfinite {
            try c.encode(Self.infinitySentinel, forKey: .upperBound)
        } else {
            try c.encode(upperBound, forKey: .upperBound)
        }
        try c.encode(mfjPercent, forKey: .mfjPercent)
        try c.encode(singlePercent, forKey: .singlePercent)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let sentinel = try? c.decode(String.self, forKey: .upperBound),
           sentinel == Self.infinitySentinel {
            self.init(upperBound: .infinity,
                      mfjPercent: try c.decode(Double.self, forKey: .mfjPercent),
                      singlePercent: try c.decode(Double.self, forKey: .singlePercent))
        } else {
            self.init(upperBound: try c.decode(Double.self, forKey: .upperBound),
                      mfjPercent: try c.decode(Double.self, forKey: .mfjPercent),
                      singlePercent: try c.decode(Double.self, forKey: .singlePercent))
        }
    }
}

extension RetirementIncomeExemptions.ExemptionLevel: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, maxExempt, maxExemptSingle, maxExemptMFJ, tiers
    }
    private enum Kind: String, Codable {
        case none, full, partial, steppedPhaseoutByFilingStatus
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try c.encode(Kind.none, forKey: .kind)
        case .full:
            try c.encode(Kind.full, forKey: .kind)
        case .partial(let maxExempt):
            try c.encode(Kind.partial, forKey: .kind)
            try c.encode(maxExempt, forKey: .maxExempt)
        case .steppedPhaseoutByFilingStatus(let single, let mfj, let tiers):
            try c.encode(Kind.steppedPhaseoutByFilingStatus, forKey: .kind)
            try c.encode(single, forKey: .maxExemptSingle)
            try c.encode(mfj, forKey: .maxExemptMFJ)
            try c.encode(tiers, forKey: .tiers)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .none:
            self = .none
        case .full:
            self = .full
        case .partial:
            self = .partial(maxExempt: try c.decode(Double.self, forKey: .maxExempt))
        case .steppedPhaseoutByFilingStatus:
            self = .steppedPhaseoutByFilingStatus(
                maxExemptSingle: try c.decode(Double.self, forKey: .maxExemptSingle),
                maxExemptMFJ: try c.decode(Double.self, forKey: .maxExemptMFJ),
                tiers: try c.decode([RetirementIncomeExemptions.PhaseoutTier].self, forKey: .tiers)
            )
        }
    }
}
```

If `PhaseoutTier` has no memberwise initializer accessible from an extension, add an explicit `init(upperBound:mfjPercent:singlePercent:)` to the struct at `StateTaxData.swift:243`.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxCodableRoundTripTests`
Expected: PASS, 7 tests.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/StateTaxCodable.swift RetireSmartIRA/StateTaxData.swift RetireSmartIRATests/StateTaxCodableRoundTripTests.swift
git commit -m "feat(state-tax): Codable for ExemptionLevel and PhaseoutTier"
```

---

### Task 6: `Codable` for `RetirementIncomeExemptions`

**Files:**
- Modify: `RetireSmartIRA/StateTaxCodable.swift`
- Modify: `RetireSmartIRATests/StateTaxCodableRoundTripTests.swift`

**Interfaces:**
- Consumes: everything from Task 5, plus `RetirementIncomeExemptions.AgeTier` (`StateTaxData.swift:234`) and `RetirementIncomeExemptions.CapGainsTreatment` (`StateTaxData.swift:341`).
- Produces: `extension RetirementIncomeExemptions.AgeTier: Codable`, `extension RetirementIncomeExemptions.CapGainsTreatment: Codable`, `extension RetirementIncomeExemptions: Codable`.

`AgeTier` holds a `ClosedRange<Int>`, which is `Codable` in Foundation but encodes as an opaque two-element array. Encode `lowerBound` and `upperBound` explicitly so a reviewer can read the file.

`RetirementIncomeExemptions` has nine stored properties, all with defaults. Every one must appear in `CodingKeys` and be decoded with its default as fallback, so that adding a field in Phase 3 does not break decoding of Phase 1 files.

- [ ] **Step 1: Write the failing test**

Append inside the suite:

```swift
    @Test("RetirementIncomeExemptions round-trips with every field populated")
    func retirementExemptionsRoundTrip() throws {
        let original = RetirementIncomeExemptions(
            socialSecurityExempt: true,
            pensionExemption: .partial(maxExempt: 65_000),
            iraWithdrawalExemption: .partial(maxExempt: 65_000),
            exemptionAppliesPerIndividual: true,
            regularExemptionMinAge: 65,
            earlyAgeTier: .init(ageRange: 62...64, level: .partial(maxExempt: 35_000)),
            pensionAndIRAShareSingleCap: true,
            otherRetirementIncomeExclusion: true,
            capitalGainsTreatment: .taxedAsOrdinary
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RetirementIncomeExemptions.self, from: data)

        #expect(decoded.socialSecurityExempt == original.socialSecurityExempt)
        #expect(decoded.exemptionAppliesPerIndividual == original.exemptionAppliesPerIndividual)
        #expect(decoded.regularExemptionMinAge == original.regularExemptionMinAge)
        #expect(decoded.pensionAndIRAShareSingleCap == original.pensionAndIRAShareSingleCap)
        #expect(decoded.otherRetirementIncomeExclusion == original.otherRetirementIncomeExclusion)
        #expect(decoded.earlyAgeTier?.ageRange == original.earlyAgeTier?.ageRange)
    }

    @Test("Decoding tolerates a file missing optional fields")
    func retirementExemptionsDecodesSparseJSON() throws {
        let sparse = Data("""
        {"socialSecurityExempt": true,
         "pensionExemption": {"kind": "none"},
         "iraWithdrawalExemption": {"kind": "none"}}
        """.utf8)
        let decoded = try JSONDecoder().decode(RetirementIncomeExemptions.self, from: sparse)
        #expect(decoded.regularExemptionMinAge == 0)
        #expect(decoded.earlyAgeTier == nil)
        #expect(decoded.exemptionAppliesPerIndividual == false)
    }
```

The second test guards forward compatibility: Phase 3 adds fields, and Phase 1's files must keep decoding.

Confirm the memberwise initializer's parameter order against `StateTaxData.swift:158-228` before running; Swift requires declaration order.

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxCodableRoundTripTests`
Expected: FAIL to compile, `RetirementIncomeExemptions` does not conform to `Encodable`.

- [ ] **Step 3: Write minimal implementation**

Append to `RetireSmartIRA/StateTaxCodable.swift`:

```swift
extension RetirementIncomeExemptions.CapGainsTreatment: Codable {
    private enum Kind: String, Codable {
        case followsFederal, taxedAsOrdinary, noStateTax
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .followsFederal:  try c.encode(Kind.followsFederal)
        case .taxedAsOrdinary: try c.encode(Kind.taxedAsOrdinary)
        case .noStateTax:      try c.encode(Kind.noStateTax)
        }
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        switch try c.decode(Kind.self) {
        case .followsFederal:  self = .followsFederal
        case .taxedAsOrdinary: self = .taxedAsOrdinary
        case .noStateTax:      self = .noStateTax
        }
    }
}

extension RetirementIncomeExemptions.AgeTier: Codable {
    private enum CodingKeys: String, CodingKey { case minAge, maxAge, level }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(ageRange.lowerBound, forKey: .minAge)
        try c.encode(ageRange.upperBound, forKey: .maxAge)
        try c.encode(level, forKey: .level)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            ageRange: try c.decode(Int.self, forKey: .minAge)...c.decode(Int.self, forKey: .maxAge),
            level: try c.decode(RetirementIncomeExemptions.ExemptionLevel.self, forKey: .level)
        )
    }
}

extension RetirementIncomeExemptions: Codable {
    private enum CodingKeys: String, CodingKey {
        case socialSecurityExempt, pensionExemption, iraWithdrawalExemption
        case exemptionAppliesPerIndividual, regularExemptionMinAge, earlyAgeTier
        case pensionAndIRAShareSingleCap, otherRetirementIncomeExclusion
        case capitalGainsTreatment
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(socialSecurityExempt, forKey: .socialSecurityExempt)
        try c.encode(pensionExemption, forKey: .pensionExemption)
        try c.encode(iraWithdrawalExemption, forKey: .iraWithdrawalExemption)
        try c.encode(exemptionAppliesPerIndividual, forKey: .exemptionAppliesPerIndividual)
        try c.encode(regularExemptionMinAge, forKey: .regularExemptionMinAge)
        try c.encodeIfPresent(earlyAgeTier, forKey: .earlyAgeTier)
        try c.encode(pensionAndIRAShareSingleCap, forKey: .pensionAndIRAShareSingleCap)
        try c.encode(otherRetirementIncomeExclusion, forKey: .otherRetirementIncomeExclusion)
        try c.encode(capitalGainsTreatment, forKey: .capitalGainsTreatment)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Every field falls back to its declared default. Phase 3 adds fields;
        // Phase 1 files must keep decoding without regeneration.
        self.init(
            socialSecurityExempt: try c.decodeIfPresent(Bool.self, forKey: .socialSecurityExempt) ?? true,
            pensionExemption: try c.decodeIfPresent(ExemptionLevel.self, forKey: .pensionExemption) ?? .none,
            iraWithdrawalExemption: try c.decodeIfPresent(ExemptionLevel.self, forKey: .iraWithdrawalExemption) ?? .none,
            exemptionAppliesPerIndividual: try c.decodeIfPresent(Bool.self, forKey: .exemptionAppliesPerIndividual) ?? false,
            regularExemptionMinAge: try c.decodeIfPresent(Int.self, forKey: .regularExemptionMinAge) ?? 0,
            earlyAgeTier: try c.decodeIfPresent(AgeTier.self, forKey: .earlyAgeTier),
            pensionAndIRAShareSingleCap: try c.decodeIfPresent(Bool.self, forKey: .pensionAndIRAShareSingleCap) ?? false,
            otherRetirementIncomeExclusion: try c.decodeIfPresent(Bool.self, forKey: .otherRetirementIncomeExclusion) ?? false,
            capitalGainsTreatment: try c.decodeIfPresent(CapGainsTreatment.self, forKey: .capitalGainsTreatment) ?? .followsFederal
        )
    }
}
```

The memberwise `init` argument order must match declaration order in `StateTaxData.swift:158-228`. If the compiler objects, reorder the call, not the struct.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxCodableRoundTripTests`
Expected: PASS, 9 tests.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/StateTaxCodable.swift RetireSmartIRATests/StateTaxCodableRoundTripTests.swift
git commit -m "feat(state-tax): Codable for RetirementIncomeExemptions"
```

---

### Task 7: `Codable` for `StateTaxConfig`

**Files:**
- Modify: `RetireSmartIRA/StateTaxCodable.swift`
- Modify: `RetireSmartIRA/StateTaxData.swift:364-440` (add `verification` property)
- Modify: `RetireSmartIRATests/StateTaxCodableRoundTripTests.swift`

**Interfaces:**
- Consumes: all conformances from Tasks 1-6.
- Produces: `extension StateTaxConfig: Codable`. Adds stored property `let verification: StateVerification` with default `.unverified` in the initializer, so no existing call site breaks.

- [ ] **Step 1: Write the failing test**

Append inside the suite:

```swift
    @Test("StateTaxConfig round-trips with verification metadata")
    func stateTaxConfigRoundTrips() throws {
        let original = StateTaxConfig(
            state: .iowa,
            taxSystem: .flat(rate: 0.038),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .conformsToFederal,
            verification: StateVerification(
                lastVerified: "2026-08-02",
                primarySources: ["https://revenue.iowa.gov/"],
                billReferences: ["HF 2317 (signed 2022-03-01)"],
                knownLimitations: ["Roth conversion income is not yet exempted."]
            )
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StateTaxConfig.self, from: data)

        #expect(decoded.state == .iowa)
        #expect(decoded.verification.lastVerified == "2026-08-02")
        #expect(decoded.verification.knownLimitations.count == 1)
        #expect(decoded.taxSystem.matchesShape(of: original.taxSystem))
        #expect(decoded.currentYearSafeHarborRate == original.currentYearSafeHarborRate)
        #expect(decoded.pretax401kContributionsTaxableForState
                == original.pretax401kContributionsTaxableForState)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxCodableRoundTripTests`
Expected: FAIL to compile, no `verification:` parameter and no `Codable` conformance.

- [ ] **Step 3: Write minimal implementation**

In `RetireSmartIRA/StateTaxData.swift`, add the stored property alongside the others in `StateTaxConfig` (after `capitalLossesClassIsolated`):

```swift
    /// Provenance for this jurisdiction. Required by the JSON schema; defaults
    /// to `.unverified` so existing Swift call sites compile unchanged during
    /// the Phase 1 migration.
    let verification: StateVerification
```

Add the parameter to the initializer signature, last, with a default:

```swift
         capitalLossesClassIsolated: Bool = false,
         verification: StateVerification = .unverified) {
```

and assign it in the body:

```swift
        self.verification = verification
```

Append to `RetireSmartIRA/StateTaxCodable.swift`:

```swift
extension StateTaxConfig: Codable {
    private enum CodingKeys: String, CodingKey {
        case state, taxSystem, retirementExemptions, stateDeduction
        case estimatedPaymentSchedule, safeHarborRule, currentYearSafeHarborRate
        case hsaContributionsTaxableForState
        case traditionalIRAContributionsTaxableForState
        case otherPreTaxDeductionsTaxableForState
        case pretax401kContributionsTaxableForState
        case capitalLossesClassIsolated
        case verification
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(state.abbreviation, forKey: .state)
        try c.encode(taxSystem, forKey: .taxSystem)
        try c.encode(retirementExemptions, forKey: .retirementExemptions)
        try c.encode(stateDeduction, forKey: .stateDeduction)
        try c.encode(estimatedPaymentSchedule, forKey: .estimatedPaymentSchedule)
        try c.encode(safeHarborRule, forKey: .safeHarborRule)
        try c.encode(currentYearSafeHarborRate, forKey: .currentYearSafeHarborRate)
        try c.encode(hsaContributionsTaxableForState, forKey: .hsaContributionsTaxableForState)
        try c.encode(traditionalIRAContributionsTaxableForState,
                     forKey: .traditionalIRAContributionsTaxableForState)
        try c.encode(otherPreTaxDeductionsTaxableForState,
                     forKey: .otherPreTaxDeductionsTaxableForState)
        try c.encode(pretax401kContributionsTaxableForState,
                     forKey: .pretax401kContributionsTaxableForState)
        try c.encode(capitalLossesClassIsolated, forKey: .capitalLossesClassIsolated)
        try c.encode(verification, forKey: .verification)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let abbreviation = try c.decode(String.self, forKey: .state)
        guard let state = USState.allCases.first(where: { $0.abbreviation == abbreviation }) else {
            throw DecodingError.dataCorruptedError(
                forKey: .state, in: c,
                debugDescription: "Unknown state abbreviation '\(abbreviation)'")
        }
        self.init(
            state: state,
            taxSystem: try c.decode(StateTaxSystem.self, forKey: .taxSystem),
            retirementExemptions: try c.decode(RetirementIncomeExemptions.self,
                                               forKey: .retirementExemptions),
            stateDeduction: try c.decode(StateDeduction.self, forKey: .stateDeduction),
            estimatedPaymentSchedule: try c.decodeIfPresent(
                EstimatedPaymentSchedule.self, forKey: .estimatedPaymentSchedule) ?? .federal,
            safeHarborRule: try c.decodeIfPresent(
                StateSafeHarborRule.self, forKey: .safeHarborRule) ?? .mirrorsFederal,
            currentYearSafeHarborRate: try c.decodeIfPresent(
                Double.self, forKey: .currentYearSafeHarborRate) ?? 0.90,
            hsaContributionsTaxableForState: try c.decodeIfPresent(
                Bool.self, forKey: .hsaContributionsTaxableForState) ?? false,
            traditionalIRAContributionsTaxableForState: try c.decodeIfPresent(
                Bool.self, forKey: .traditionalIRAContributionsTaxableForState) ?? false,
            otherPreTaxDeductionsTaxableForState: try c.decodeIfPresent(
                Bool.self, forKey: .otherPreTaxDeductionsTaxableForState) ?? false,
            pretax401kContributionsTaxableForState: try c.decodeIfPresent(
                Bool.self, forKey: .pretax401kContributionsTaxableForState) ?? false,
            capitalLossesClassIsolated: try c.decodeIfPresent(
                Bool.self, forKey: .capitalLossesClassIsolated) ?? false,
            verification: try c.decodeIfPresent(
                StateVerification.self, forKey: .verification) ?? .unverified
        )
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxCodableRoundTripTests`
Expected: PASS, 10 tests.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/StateTaxCodable.swift RetireSmartIRA/StateTaxData.swift RetireSmartIRATests/StateTaxCodableRoundTripTests.swift
git commit -m "feat(state-tax): Codable for StateTaxConfig with verification metadata"
```

---

### Task 8: Rename the hardcoded table and generate the 51 JSON files

**Files:**
- Modify: `RetireSmartIRA/StateTaxData.swift:470` (rename `configs2026` to `configs2026Legacy`)
- Create: `RetireSmartIRATests/StateTaxDataGeneratorTests.swift`
- Create: `RetireSmartIRA/Resources/StateTaxData/2026/*.json` (51 generated files)

**Interfaces:**
- Consumes: `StateTaxConfig: Codable` from Task 7.
- Produces: 51 files named `<ABBREVIATION>.json`. `StateTaxData.configs2026Legacy` becomes the equivalence oracle used by Task 10 and retained through Phase 3.

The generator lives in the test target because it runs once per data change and must never ship in the app binary.

- [ ] **Step 1: Rename the table**

In `RetireSmartIRA/StateTaxData.swift` line 470, change:

```swift
    static let configs2026: [USState: StateTaxConfig] = {
```

to:

```swift
    /// The original hardcoded table. Retained through Phase 3 as the
    /// equivalence oracle proving the JSON migration changed nothing.
    /// Not the production path after Task 11.
    static let configs2026Legacy: [USState: StateTaxConfig] = {
```

Then add a temporary alias immediately after the closing `}()` of that property so nothing else breaks yet:

```swift
    /// Temporary during Phase 1. Task 11 replaces this with the loader.
    static var configs2026: [USState: StateTaxConfig] { configs2026Legacy }
```

- [ ] **Step 2: Run the full suite to confirm the rename broke nothing**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS'`
Expected: PASS, 1,570 Swift Testing + 503 XCTest, 0 failures.

- [ ] **Step 3: Write the generator**

Create `RetireSmartIRATests/StateTaxDataGeneratorTests.swift`:

```swift
import Testing
import Foundation
@testable import RetireSmartIRA

/// Generates the bundled per-state JSON from the legacy hardcoded table.
///
/// Generated, never hand-written. Transcribing 51 jurisdictions by hand would
/// inject the exact class of error this whole program exists to remove.
///
/// Disabled in the normal loop. Run deliberately with:
///   STATE_TAX_GENERATE=1 xcodebuild test -scheme RetireSmartIRA \
///     -destination 'platform=macOS' \
///     -only-testing:RetireSmartIRATests/StateTaxDataGeneratorTests
@Suite("State tax JSON generator (manual)")
struct StateTaxDataGeneratorTests {

    @Test("Generate all 51 jurisdiction files",
          .enabled(if: ProcessInfo.processInfo.environment["STATE_TAX_GENERATE"] == "1"))
    func generateAll() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // RetireSmartIRATests
            .deletingLastPathComponent()   // repo root
        let outDir = repoRoot
            .appendingPathComponent("RetireSmartIRA/Resources/StateTaxData/2026")
        try FileManager.default.createDirectory(
            at: outDir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        var written = 0
        for state in USState.allCases {
            guard let config = StateTaxData.configs2026Legacy[state] else {
                Issue.record("No legacy config for \(state.abbreviation)")
                continue
            }
            let data = try encoder.encode(config)
            try data.write(to: outDir.appendingPathComponent("\(state.abbreviation).json"))
            written += 1
        }
        #expect(written == 51, "expected 51 jurisdictions, wrote \(written)")
    }
}
```

`.sortedKeys` is required: without it, key order varies between runs and every regeneration produces a meaningless diff, which would destroy the reviewability that motivated moving to JSON.

- [ ] **Step 4: Run the generator**

Run: `STATE_TAX_GENERATE=1 xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxDataGeneratorTests`
Expected: PASS. Then confirm the files exist:

```bash
ls RetireSmartIRA/Resources/StateTaxData/2026/ | wc -l
```

Expected output: `51`

- [ ] **Step 5: Confirm the files reach the app bundle**

**Do not edit `project.pbxproj`.** The target uses `PBXFileSystemSynchronizedRootGroup` (objectVersion 77, Xcode 16+) on `RetireSmartIRA/` with no exception set, so files written under it should be bundled automatically with no project edit at all.

Verify rather than assume. Build, then inspect the produced bundle:

```bash
xcodebuild build -scheme RetireSmartIRA -destination 'platform=macOS' -showBuildSettings 2>/dev/null | grep -m1 "BUILT_PRODUCTS_DIR"
```

Then list what actually landed:

```bash
find "$(xcodebuild build -scheme RetireSmartIRA -destination 'platform=macOS' -showBuildSettings 2>/dev/null | awk -F' = ' '/BUILT_PRODUCTS_DIR/{print $2; exit}')" -name "*.json" -path "*StateTax*" | head -5
```

Record in the report which layout appeared: nested under `StateTaxData/2026/`, or flattened. Task 9's loader resolves both, so either outcome is fine; the report just needs to say which, so the next task does not guess.

If **no** JSON appears in the bundle at all, stop and report `BLOCKED`. Do not attempt a `project.pbxproj` edit. John will add the folder reference in Xcode.

- [ ] **Step 6: Add the table-wide safe-harbor round trip deferred from Task 4**

Now that `configs2026Legacy` exists, add this test inside the suite in `RetireSmartIRATests/StateTaxCodableRoundTripTests.swift`:

```swift
    @Test("Every StateSafeHarborRule used in the real config table round-trips")
    func allConfiguredSafeHarborRulesRoundTrip() throws {
        for (state, config) in StateTaxData.configs2026Legacy {
            let data = try JSONEncoder().encode(config.safeHarborRule)
            let decoded = try JSONDecoder().decode(StateSafeHarborRule.self, from: data)
            #expect(decoded == config.safeHarborRule,
                    "\(state.abbreviation) safe harbor rule lost in round trip")
        }
    }
```

This is the test that matters for safe harbor: it exercises whatever cases the real 51-jurisdiction table actually uses, so an unhandled enum case cannot slip through on a state nobody thought to hand-write a case for.

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxCodableRoundTripTests`
Expected: PASS, 11 tests.

- [ ] **Step 7: Commit**

```bash
git add RetireSmartIRA/StateTaxData.swift RetireSmartIRA/Resources/StateTaxData RetireSmartIRATests/StateTaxDataGeneratorTests.swift RetireSmartIRATests/StateTaxCodableRoundTripTests.swift RetireSmartIRA.xcodeproj
git commit -m "feat(state-tax): generate 51 jurisdiction JSON files from the legacy table"
```

---

### Task 9: `StateTaxDataLoader`

**Files:**
- Create: `RetireSmartIRA/StateTaxDataLoader.swift`
- Create: `RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift`

**Interfaces:**
- Consumes: the bundled JSON from Task 8, `StateTaxConfig: Codable` from Task 7.
- Produces: `enum StateTaxDataLoader` with `static func load(taxYear: Int) throws -> [USState: StateTaxConfig]` and `static let configs2026: [USState: StateTaxConfig]`. Task 11 routes `StateTaxData.config(for:)` through this.

- [ ] **Step 1: Write the failing test**

Create `RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift`:

```swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("State tax JSON loader (Phase 1)")
struct StateTaxJSONLoaderTests {

    @Test("Loader returns all 51 jurisdictions")
    func loadsAllJurisdictions() throws {
        let configs = try StateTaxDataLoader.load(taxYear: 2026)
        #expect(configs.count == 51)
        for state in USState.allCases {
            #expect(configs[state] != nil, "missing \(state.abbreviation)")
        }
    }

    @Test("Loader throws for a tax year with no bundled data")
    func throwsForUnknownYear() {
        #expect(throws: (any Error).self) {
            try StateTaxDataLoader.load(taxYear: 1999)
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxJSONLoaderTests`
Expected: FAIL to compile, "cannot find 'StateTaxDataLoader' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `RetireSmartIRA/StateTaxDataLoader.swift`:

```swift
import Foundation

/// Anchors `Bundle(for:)` to the framework/app bundle that actually contains the
/// resources. `Bundle.main` resolves to the test runner under xcodebuild, where
/// the JSON is not present.
private final class BundleMarker {}

/// Loads per-jurisdiction tax configuration from bundled JSON.
///
/// Replaces the hardcoded table that shipped through v2.3.0. The move exists so
/// that state data is diffable in review, machine-checkable, readable by someone
/// who does not write Swift, and keyed by tax year rather than pinned to one.
enum StateTaxDataLoader {

    enum LoadError: LocalizedError {
        case directoryMissing(taxYear: Int)
        case fileMissing(state: USState, taxYear: Int)
        case incomplete(found: Int, expected: Int, taxYear: Int)

        var errorDescription: String? {
            switch self {
            case .directoryMissing(let year):
                return "No bundled state tax data for tax year \(year)."
            case .fileMissing(let state, let year):
                return "Missing state tax data for \(state.abbreviation) in \(year)."
            case .incomplete(let found, let expected, let year):
                return "Loaded \(found) of \(expected) jurisdictions for \(year)."
            }
        }
    }

    /// Decodes every jurisdiction for `taxYear`.
    ///
    /// Throws rather than substituting a default. The table this replaces
    /// returned California's rules for any missing state, which produced a
    /// confident wrong number attributed to the wrong jurisdiction.
    static func load(taxYear: Int) throws -> [USState: StateTaxConfig] {
        let bundle = Bundle(for: BundleMarker.self)

        // The target uses PBXFileSystemSynchronizedRootGroup (Xcode 16+), which
        // bundles resources automatically but may or may not preserve the
        // StateTaxData/<year>/ directory structure. Resolve either layout rather
        // than depending on which one Xcode produces.
        func url(for state: USState) -> URL? {
            bundle.url(forResource: state.abbreviation, withExtension: "json",
                       subdirectory: "StateTaxData/\(taxYear)")
                ?? bundle.url(forResource: "\(taxYear)", withExtension: nil,
                              subdirectory: "StateTaxData")
                          .map { $0.appendingPathComponent("\(state.abbreviation).json") }
                ?? bundle.url(forResource: "statetax-\(taxYear)-\(state.abbreviation)",
                              withExtension: "json")
        }

        guard url(for: .california) != nil else {
            throw LoadError.directoryMissing(taxYear: taxYear)
        }

        let decoder = JSONDecoder()
        var configs: [USState: StateTaxConfig] = [:]
        for state in USState.allCases {
            guard let fileURL = url(for: state),
                  let data = try? Data(contentsOf: fileURL) else {
                throw LoadError.fileMissing(state: state, taxYear: taxYear)
            }
            configs[state] = try decoder.decode(StateTaxConfig.self, from: data)
        }
        guard configs.count == USState.allCases.count else {
            throw LoadError.incomplete(found: configs.count,
                                       expected: USState.allCases.count,
                                       taxYear: taxYear)
        }
        return configs
    }

    /// Decoded once at first use.
    static let configs2026: [USState: StateTaxConfig] = {
        do {
            return try load(taxYear: 2026)
        } catch {
            // A missing or malformed bundle is a build defect, not a runtime
            // condition. Fail loudly in debug; Task 11 defines release behavior.
            assertionFailure("State tax data failed to load: \(error)")
            return [:]
        }
    }()
}
```

If `Bundle.main` resolves to the test host rather than the app during tests, switch to `Bundle(for:)` via a marker class, or add `Bundle.module` if the target is converted to a Swift package resource. Confirm which applies by running Step 4 before adjusting.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxJSONLoaderTests`
Expected: PASS, 2 tests. If `loadsAllJurisdictions` fails with `directoryMissing`, the resource folder reference from Task 8 Step 5 was added as a group (yellow) rather than a folder reference (blue). Fix it there.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/StateTaxDataLoader.swift RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift
git commit -m "feat(state-tax): add StateTaxDataLoader with throwing, non-substituting errors"
```

---

### Task 10: The equivalence gate

**Files:**
- Modify: `RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift`

**Interfaces:**
- Consumes: `StateTaxDataLoader.configs2026` (Task 9), `StateTaxData.configs2026Legacy` (Task 8), `TaxCalculationEngine.calculateStateTax` (`TaxCalculationEngine.swift:340`).
- Produces: the gate that authorizes Phase 2. Adds one parameter, `configOverride: StateTaxConfig? = nil`, to `calculateStateTax`.

This is the deliverable of Phase 1. It asserts that for all 51 jurisdictions across a scenario grid, the JSON-loaded configuration produces state tax **identical to the last decimal** against the hardcoded table.

The verified signature is `calculateStateTax(income:forState:filingStatus:taxableSocialSecurity:incomeSources:currentAge:enableSpouse:spouseBirthYear:currentYear:scenarioRetirementDistributions:scenarioRothConversionAmount:scenarioRothConversionWithholdingAmount:postExemptionDeduction:localIncomeTaxRate:)` at `TaxCalculationEngine.swift:340`. It resolves its own config at line 355 with `let config = StateTaxData.config(for: state)`.

That single line is the only seam the gate needs. Injecting an override there is a two-line change touching no call site, which is far safer than extracting the body into an overload.

- [ ] **Step 1: Write the failing test**

Append to `RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift`:

```swift
/// A scenario shaped to exercise the dimensions that differ between states:
/// SS taxability, pension and IRA exemptions, filing status, and bracket position.
private struct EquivalenceScenario {
    let name: String
    let income: Double
    let filingStatus: FilingStatus
    let taxableSocialSecurity: Double
    let retirementDistributions: Double
    let rothConversion: Double
    let primaryAge: Int
    let spouseAge: Int
    /// Exercises the NJ personal-exemption path, which is the only current
    /// consumer of postExemptionDeduction and is dropped entirely by the
    /// multi-year engine (backlog I2). Phase 1 only proves the migration is
    /// faithful; I2 itself is corrected in Phase 5d.
    let postExemptionDeduction: Double
}

@Suite("PHASE 1 GATE: JSON configs are behaviorally identical to the legacy table")
struct StateTaxJSONEquivalenceTests {

    /// Deliberately spans the age, income and filing-status boundaries where
    /// the 2026-08-02 audit found defects, so the migration is proven across
    /// the same surface those defects live on.
    private static let scenarios: [EquivalenceScenario] = [
        .init(name: "modest single 67", income: 40_000, filingStatus: .single,
              taxableSocialSecurity: 12_000, retirementDistributions: 20_000, rothConversion: 0,
              primaryAge: 67, spouseAge: 67, postExemptionDeduction: 0),
        .init(name: "modest MFJ 67", income: 80_000, filingStatus: .marriedFilingJointly,
              taxableSocialSecurity: 24_000, retirementDistributions: 40_000, rothConversion: 0,
              primaryAge: 67, spouseAge: 67, postExemptionDeduction: 2_000),
        .init(name: "early retiree 57, below the 59.5 gate", income: 70_000, filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 30_000, rothConversion: 25_000,
              primaryAge: 57, spouseAge: 57, postExemptionDeduction: 0),
        .init(name: "age-tier boundary 63", income: 90_000, filingStatus: .single,
              taxableSocialSecurity: 18_000, retirementDistributions: 40_000, rothConversion: 0,
              primaryAge: 63, spouseAge: 63, postExemptionDeduction: 0),
        .init(name: "mid single + conversion", income: 150_000, filingStatus: .single,
              taxableSocialSecurity: 30_000, retirementDistributions: 40_000, rothConversion: 60_000,
              primaryAge: 66, spouseAge: 66, postExemptionDeduction: 0),
        .init(name: "high MFJ + large conversion", income: 300_000,
              filingStatus: .marriedFilingJointly,
              taxableSocialSecurity: 40_000, retirementDistributions: 60_000, rothConversion: 150_000,
              primaryAge: 70, spouseAge: 68, postExemptionDeduction: 2_000),
        .init(name: "mixed-age MFJ, one spouse under the gate", income: 120_000,
              filingStatus: .marriedFilingJointly,
              taxableSocialSecurity: 0, retirementDistributions: 50_000, rothConversion: 0,
              primaryAge: 61, spouseAge: 56, postExemptionDeduction: 0),
        .init(name: "pension only MFJ", income: 95_000, filingStatus: .marriedFilingJointly,
              taxableSocialSecurity: 0, retirementDistributions: 95_000, rothConversion: 0,
              primaryAge: 68, spouseAge: 68, postExemptionDeduction: 2_000),
        .init(name: "zero income", income: 0, filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 0, rothConversion: 0,
              primaryAge: 65, spouseAge: 65, postExemptionDeduction: 0)
    ]

    @Test("Every jurisdiction computes identical state tax from JSON and from the legacy table",
          arguments: USState.allCases)
    func jsonMatchesLegacy(state: USState) throws {
        let jsonConfigs = try StateTaxDataLoader.load(taxYear: 2026)
        guard let jsonConfig = jsonConfigs[state],
              let legacyConfig = StateTaxData.configs2026Legacy[state] else {
            Issue.record("Missing config for \(state.abbreviation)")
            return
        }

        for scenario in Self.scenarios {
            func stateTax(using config: StateTaxConfig) -> Double {
                TaxCalculationEngine.calculateStateTax(
                    income: scenario.income,
                    forState: state,
                    filingStatus: scenario.filingStatus,
                    taxableSocialSecurity: scenario.taxableSocialSecurity,
                    incomeSources: [],
                    currentAge: scenario.primaryAge,
                    enableSpouse: scenario.filingStatus == .marriedFilingJointly,
                    spouseBirthYear: 2026 - scenario.spouseAge,
                    currentYear: 2026,
                    scenarioRetirementDistributions: scenario.retirementDistributions,
                    scenarioRothConversionAmount: scenario.rothConversion,
                    scenarioRothConversionWithholdingAmount: 0,
                    postExemptionDeduction: scenario.postExemptionDeduction,
                    localIncomeTaxRate: 0,
                    configOverride: config
                )
            }
            let fromJSON = stateTax(using: jsonConfig)
            let fromLegacy = stateTax(using: legacyConfig)
            #expect(
                fromJSON == fromLegacy,
                """
                \(state.abbreviation) / \(scenario.name): JSON \(fromJSON) != legacy \(fromLegacy).
                Phase 1 must change no computed value. This is a migration defect, \
                not a tax correction. Corrections happen in Phase 5.
                """
            )
        }
    }
}
```

`calculateStateTax` currently takes `forState state: USState` and resolves the config internally rather than accepting one. Add a config-accepting overload in Step 3 so both tables can be exercised; do not change the existing signature, because 500+ call sites depend on it.

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxJSONEquivalenceTests`
Expected: FAIL to compile, "extra argument 'configOverride' in call".

- [ ] **Step 3: Add the `configOverride` parameter**

Two lines change in `RetireSmartIRA/TaxCalculationEngine.swift`. No call site is touched, because the parameter is optional and last.

At line 353, add the parameter after `localIncomeTaxRate`:

```swift
        postExemptionDeduction: Double = 0,
        localIncomeTaxRate: Double = 0,
        /// Test-only seam. When non-nil, bypasses the `StateTaxData` lookup so a
        /// caller can exercise this function against a specific configuration.
        /// The Phase 1 equivalence gate uses it to run the JSON-loaded and legacy
        /// tables through identical code. Production always passes nil.
        configOverride: StateTaxConfig? = nil
    ) -> Double {
```

At line 355, change:

```swift
        let config = StateTaxData.config(for: state)
```

to:

```swift
        let config = configOverride ?? StateTaxData.config(for: state)
```

That is the whole change. `applyRetirementExemptions` at line 465 already accepts `config: StateTaxConfig` and `state: USState` as separate parameters, so nothing downstream needs adjusting.

- [ ] **Step 4: Run the gate**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxJSONEquivalenceTests`
Expected: PASS, 51 parameterized cases plus 2 loader tests.

If any jurisdiction fails, do **not** adjust the expected value. A failure means the Codable conformance lost information. Find the lost field by diffing the two configs directly, fix the conformance, regenerate with `STATE_TAX_GENERATE=1`, and re-run.

- [ ] **Step 5: Run the full suite**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS'`
Expected: 1,570 Swift Testing + 503 XCTest, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift RetireSmartIRA/TaxCalculationEngine.swift
git commit -m "test(state-tax): PHASE 1 GATE, JSON configs behaviorally identical across 51 jurisdictions"
```

---

### Task 11: Route production through the loader

**Files:**
- Modify: `RetireSmartIRA/StateTaxData.swift:2068-2069` and the temporary alias from Task 8 Step 1

**Interfaces:**
- Consumes: `StateTaxDataLoader.configs2026` (Task 9), the gate (Task 10).
- Produces: the app reading JSON in production. `configs2026Legacy` survives as the test oracle only.

- [ ] **Step 1: Write the failing test**

Append to `RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift`, inside `StateTaxJSONLoaderTests`:

```swift
    @Test("config(for:) reads JSON, not the legacy table")
    func productionPathUsesJSON() throws {
        let iowa = StateTaxData.config(for: .iowa)
        #expect(iowa.state == .iowa)
        // The loader populates verification metadata; the legacy table cannot.
        let jsonIowa = try StateTaxDataLoader.load(taxYear: 2026)[.iowa]
        #expect(iowa.verification == jsonIowa?.verification)
    }

    @Test("config(for:) no longer substitutes California for an unknown state")
    func noCaliforniaSubstitution() {
        // Every USState case must resolve to itself, never to a stand-in.
        for state in USState.allCases {
            #expect(StateTaxData.config(for: state).state == state,
                    "\(state.abbreviation) resolved to a different jurisdiction")
        }
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxJSONLoaderTests`
Expected: `productionPathUsesJSON` FAILS, because `config(for:)` still reads the legacy alias whose `verification` is `.unverified` for every state while the JSON carries the generated values. `noCaliforniaSubstitution` passes already, since every state has an entry today; it is a regression guard for the fallback removal.

- [ ] **Step 3: Route through the loader**

In `RetireSmartIRA/StateTaxData.swift`, replace the temporary alias added in Task 8 Step 1:

```swift
    static var configs2026: [USState: StateTaxConfig] { configs2026Legacy }
```

with:

```swift
    /// Production path as of Phase 1. Reads bundled JSON.
    static var configs2026: [USState: StateTaxConfig] { StateTaxDataLoader.configs2026 }
```

Then replace lines 2068-2069:

```swift
    static func config(for state: USState) -> StateTaxConfig {
        configs2026[state] ?? configs2026[.california]!
    }
```

with:

```swift
    /// Returns the configuration for `state`.
    ///
    /// The previous implementation substituted California for any missing
    /// jurisdiction, which produced a confident wrong number attributed to the
    /// wrong state with nothing surfaced to the user. Phase 1 removes the
    /// substitution. A missing entry is a build defect: every one of the 51
    /// files is generated and verified present by the loader.
    static func config(for state: USState) -> StateTaxConfig {
        guard let config = configs2026[state] else {
            assertionFailure("No tax configuration for \(state.abbreviation)")
            return configs2026Legacy[state] ?? StateTaxConfig(
                state: state,
                taxSystem: .noIncomeTax,
                retirementExemptions: RetirementIncomeExemptions(),
                stateDeduction: .none,
                verification: .unverified
            )
        }
        return config
    }
```

The release-path fallback is a zero-tax configuration for **that same state**, never another state's rules, so a catastrophic load failure understates rather than silently misattributes. Phase 2 replaces this with the user-visible refusal described in the spec.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxJSONLoaderTests`
Expected: PASS, 4 tests.

- [ ] **Step 5: Run the full suite**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS'`
Expected: 1,570 Swift Testing + 503 XCTest, 0 failures.

- [ ] **Step 6: Verify the iOS build**

Run: `xcodebuild build -scheme RetireSmartIRA -destination 'generic/platform=iOS'`
Expected: BUILD SUCCEEDED. This confirms the bundled resource folder is copied on both platforms, which a macOS-only test run would not catch.

- [ ] **Step 7: Commit**

```bash
git add RetireSmartIRA/StateTaxData.swift RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift
git commit -m "feat(state-tax): route config(for:) through JSON loader, drop California substitution"
```

---

### Task 12: Neutralize the misleading TODO block

**Files:**
- Modify: `RetireSmartIRA/TaxCalculationEngine.swift:479-489`
- Modify: `RetireSmartIRATests/TaxsimOracleTests.swift` (header comment)

**Interfaces:**
- Consumes: nothing. Produces: nothing. Comment-only, zero behavior change.

`applyRetirementExemptions` carries a `TODO(post-1.8.3)` block listing "Verified-2026 exemption value updates." Several entries independently match the 2026-08-02 audit: MD $40,600, MI $67,610/$135,220 with `.full` noted as overstating, GA's $35K 62-64 tier, KY HB146, and the flat 59½ baseline.

**One entry is actively dangerous.** It instructs a future engineer to make Colorado "unlimited (SB25-136, currently $24K)." SB25-136 was postponed indefinitely on 2025-02-27 and is dead. Acting on that TODO would introduce a bug into a jurisdiction that is currently correct. A second entry, "AL $12K age 65+ (HB388, currently $2,500)," misstates the current value: Alabama is configured `.none`, and $2,500 is Arizona's.

This task removes the trap. It does not fix any value.

- [ ] **Step 1: Rewrite the TODO block**

Replace lines 479-489 of `RetireSmartIRA/TaxCalculationEngine.swift` with:

```swift
        // Known gaps, superseded by the 2026-08-02 full 51-jurisdiction audit.
        // Do NOT action items from this comment. The authoritative list is
        // docs/superpowers/specs/2026-08-02-state-tax-verification-and-maintenance-design.md
        // and corrections are gated on Phase 5 of that program, each backed by a
        // golden scenario derived from the state's own form.
        //
        // The prior version of this comment listed "CO unlimited (SB25-136)" as
        // pending work. That is wrong: SB25-136 was postponed indefinitely on
        // 2025-02-27 and never became law. Colorado's $24,000 / $20,000 tiers are
        // CORRECT and must not be changed. It also reported Alabama's current
        // value as $2,500, which is Arizona's; Alabama is configured .none.
        //
        // Still open and confirmed by the audit: per-state age thresholds (this
        // function uses a flat 59.5 baseline for scenarioRetirementDistributions,
        // which is wrong for Iowa at 55), and the inability to apply
        // pensionExemption and iraWithdrawalExemption independently because
        // scenarioRetirementDistributions is not split by source.
```

- [ ] **Step 2: Correct the TAXSIM header**

In `RetireSmartIRATests/TaxsimOracleTests.swift`, the header lists known engine-vs-TAXSIM disagreements including "CO SB25-136" and "AL HB388." Change that sentence to:

```swift
//              divergence is logged as informational (not failing) because
//              TAXSIM's state law is only coded through ~2020 and we KNOW
//              our engine and TAXSIM disagree on several state retirement
//              rules (PA Ans 274 conversions, and the state-specific
//              exemptions catalogued in the 2026-08-02 audit).
```

Removing the bill numbers here is deliberate: SB25-136 never passed, so citing it as a source of divergence propagates the same false premise.

- [ ] **Step 3: Verify nothing changed**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS'`
Expected: 1,570 Swift Testing + 503 XCTest, 0 failures. Comment-only edits cannot change behavior; this run confirms no accidental code edit.

- [ ] **Step 4: Commit**

```bash
git add RetireSmartIRA/TaxCalculationEngine.swift RetireSmartIRATests/TaxsimOracleTests.swift
git commit -m "docs(state-tax): remove the dead-bill TODO that would have broken Colorado"
```

---

## Phase 1 Exit Criteria

All must hold before Phase 2 begins:

- [ ] 51 JSON files exist under `RetireSmartIRA/Resources/StateTaxData/2026/` and are in Copy Bundle Resources for both platforms.
- [ ] The equivalence gate passes for all 51 jurisdictions across all 6 scenarios.
- [ ] Full suite green: 1,570 Swift Testing in 265 suites + 503 XCTest, 0 failures.
- [ ] iOS and macOS both build clean.
- [ ] `config(for:)` no longer returns another state's rules under any input.
- [ ] `configs2026Legacy` still exists and is still referenced only by tests.
- [ ] No computed tax value changed anywhere in the app.
- [ ] The dead-bill Colorado TODO is gone from `TaxCalculationEngine.swift` and `TaxsimOracleTests.swift`.

## What Phase 1 Deliberately Does Not Do

Not one tax value is corrected. Iowa still taxes retirement income, Michigan's exemption is still uncapped, Kansas still has no personal exemption. Those are Phase 5, and every one of them will be gated by a golden scenario derived from a state form.

`knownLimitations` is generated empty for every jurisdiction. Populating it is Phase 5's output and Phase 6's input.

The `verification` metadata is generated as `.unverified` for all 51, including the 26 states carrying a `Verified 2026-05-27` code comment. Those comments are not carried across, deliberately: Wisconsin carried one and was wrong, so importing them would launder an unearned claim into a structured field. Verification dates are earned in Phase 5 against primary sources.
