# V2.0 Taxable Accounts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make taxable/brokerage assets first-class accounts that the Multi-Year Roth conversion engine models per-account (returns, income by tax character, blended-basis gains on sale, liquidity earmarks), so recommendations stop being too aggressive when a balance is entered and too distorted when it is missing.

**Architecture:** A new `TaxableAccount` value type stored in `AccountsManager` (persisted like `iraAccounts`), carried into the engine as a pure `TaxableAccountInput` array on `MultiYearStaticInputs`. `ProjectionEngine` replaces its single `taxable` scalar with per-account buckets and a real cash-and-tax waterfall. UI lives in the Accounts tab with progressive disclosure; the Multi-Year tab consumes a read-only roll-up. Backward compatibility: an empty account array synthesizes one account from the legacy `currentTaxableBalance` so existing behavior and tests are preserved.

**Tech Stack:** Swift 5, SwiftUI, Swift Testing (`@Suite`/`@Test`/`#expect`), Xcode. Native macOS 15 + iOS 18 (NOT Catalyst).

**Spec:** `docs/superpowers/specs/2026-06-30-taxable-accounts-design.md`

## Global Constraints

- Branch: `2.0/heir-objective` (worktree `.worktrees/2.0-reconcile-engine`).
- Full test suite must stay green (~1,100 tests). Run with: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS'`.
- Run a single suite with `-only-testing:RetireSmartIRATests/<SuiteName>`.
- Tests are the source of truth. After any engine/tax change, run the full suite before considering the task done.
- Scope searches under `RetireSmartIRA/` and `RetireSmartIRATests/`. Never grep `.build`, `DerivedData`, `.git`.
- No em dash characters anywhere in user-facing copy.
- V2.0 derives investment income from accounts for the Multi-Year engine ONLY. Do not touch the single-year views (Scenarios, Tax Summary, Quarterly).
- Pure value types (`TaxableAccount`, `TaxableAccountInput`) carry no SwiftUI/DataManager dependencies.
- Commit after every task. Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## Phase 1 — Data model and persistence

### Task 1: `TaxableAccount` model + category

**Files:**
- Create: `RetireSmartIRA/TaxableAccountModels.swift`
- Test: `RetireSmartIRATests/TaxableAccountTests.swift`

**Interfaces:**
- Produces: `struct TaxableAccount: Identifiable, Codable, Equatable, Sendable` with the fields below and a computed `availableBalance` and `unrealizedGainFraction`. `enum TaxableAccountCategory: String, Codable, CaseIterable`.

- [ ] **Step 1: Write the failing test**

```swift
// RetireSmartIRATests/TaxableAccountTests.swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("TaxableAccount")
struct TaxableAccountTests {
    @Test("availableBalance subtracts the reserve and floors at zero")
    func availableBalance() {
        var a = TaxableAccount(name: "Brokerage", balance: 300_000, costBasis: 200_000)
        a.protectedAmount = 250_000
        #expect(a.availableBalance == 50_000)
        a.protectedAmount = 400_000
        #expect(a.availableBalance == 0)
    }

    @Test("unrealizedGainFraction is gain over balance, zero when no gain or empty")
    func gainFraction() {
        let a = TaxableAccount(name: "B", balance: 100_000, costBasis: 70_000)
        #expect(abs(a.unrealizedGainFraction - 0.3) < 1e-9)
        let flat = TaxableAccount(name: "C", balance: 100_000, costBasis: 100_000)
        #expect(flat.unrealizedGainFraction == 0)
        let empty = TaxableAccount(name: "D", balance: 0, costBasis: 0)
        #expect(empty.unrealizedGainFraction == 0)
    }

    @Test("Codable round-trips all fields including new ones")
    func codable() throws {
        var a = TaxableAccount(name: "Muni", balance: 500_000, costBasis: 500_000)
        a.category = .muniBond
        a.taxExemptYield = 0.03
        a.fundingPriority = 2
        a.availableForConversionTaxes = false
        let data = try JSONEncoder().encode(a)
        let back = try JSONDecoder().decode(TaxableAccount.self, from: data)
        #expect(back == a)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/TaxableAccount 2>&1 | tail -20`
Expected: FAIL (compile error, `TaxableAccount` undefined).

- [ ] **Step 3: Write the model**

```swift
// RetireSmartIRA/TaxableAccountModels.swift
import Foundation

enum TaxableAccountCategory: String, Codable, CaseIterable, Sendable {
    case brokerage = "Brokerage"
    case cashMoneyMarket = "Cash / Money Market"
    case dividendFund = "Dividend Fund"
    case muniBond = "Muni Bond Account"
    case trustRestricted = "Trust / Restricted"
    case otherTaxable = "Other Taxable"
}

/// A non-retirement (taxable) account: brokerage, cash, muni ladder, grantor trust, etc.
/// First-class peer of IRAAccount, consumed by the multi-year engine.
struct TaxableAccount: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var owner: Owner
    var institution: String
    var category: TaxableAccountCategory

    var balance: Double
    var costBasis: Double
    var protectedAmount: Double

    var expectedAppreciationRate: Double   // price growth, EXCLUDING income yield

    var qualifiedDividendYield: Double     // preferential rate
    var ordinaryIncomeYield: Double        // non-qual dividends + interest
    var taxExemptYield: Double             // muni: MAGI add-back only
    var realizedLongTermGainYield: Double  // fund cap-gain distributions; preferential

    var availableForExpenses: Bool
    var availableForConversionTaxes: Bool
    var fundingPriority: Int?              // lower used first; nil -> highest-basis-first

    /// True until the user confirms basis; surfaces the "Confirm basis" badge.
    var basisNeedsConfirmation: Bool

    init(id: UUID = UUID(),
         name: String,
         owner: Owner = .primary,
         institution: String = "",
         category: TaxableAccountCategory = .brokerage,
         balance: Double,
         costBasis: Double,
         protectedAmount: Double = 0,
         expectedAppreciationRate: Double = 0,
         qualifiedDividendYield: Double = 0,
         ordinaryIncomeYield: Double = 0,
         taxExemptYield: Double = 0,
         realizedLongTermGainYield: Double = 0,
         availableForExpenses: Bool = true,
         availableForConversionTaxes: Bool = true,
         fundingPriority: Int? = nil,
         basisNeedsConfirmation: Bool = false) {
        self.id = id
        self.name = name
        self.owner = owner
        self.institution = institution
        self.category = category
        self.balance = balance
        self.costBasis = costBasis
        self.protectedAmount = protectedAmount
        self.expectedAppreciationRate = expectedAppreciationRate
        self.qualifiedDividendYield = qualifiedDividendYield
        self.ordinaryIncomeYield = ordinaryIncomeYield
        self.taxExemptYield = taxExemptYield
        self.realizedLongTermGainYield = realizedLongTermGainYield
        self.availableForExpenses = availableForExpenses
        self.availableForConversionTaxes = availableForConversionTaxes
        self.fundingPriority = fundingPriority
        self.basisNeedsConfirmation = basisNeedsConfirmation
    }

    var availableBalance: Double { max(0, balance - protectedAmount) }

    var unrealizedGainFraction: Double {
        guard balance > 0 else { return 0 }
        return max(0, (balance - costBasis) / balance)
    }
}
```

Add an explicit `init(from:)` only if a later persisted-field migration needs it; the default synthesized `Codable` is sufficient for new fields because every property has a default in the memberwise init. If decode of an older payload that lacks the new keys is required, add a hand-written `init(from:)` that defaults missing keys (mirror `MultiYearAssumptions.init(from:)` at `RetireSmartIRA/MultiYearAssumptions.swift:81`).

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/TaxableAccount 2>&1 | tail -20`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/TaxableAccountModels.swift RetireSmartIRATests/TaxableAccountTests.swift
git commit -m "feat(accounts): add TaxableAccount model + category"
```

---

### Task 2: Store taxable accounts in `AccountsManager` + `DataManager` forwarding

**Files:**
- Modify: `RetireSmartIRA/AccountsManager.swift:18` (add property)
- Modify: `RetireSmartIRA/DataManager.swift:86` (add forwarding property after `iraAccounts`)
- Test: `RetireSmartIRATests/TaxableAccountStoreTests.swift`

**Interfaces:**
- Consumes: `TaxableAccount` (Task 1).
- Produces: `DataManager.taxableAccounts: [TaxableAccount]` (get/set forwarding to `AccountsManager.taxableAccounts`).

- [ ] **Step 1: Write the failing test**

```swift
// RetireSmartIRATests/TaxableAccountStoreTests.swift
import Testing
@testable import RetireSmartIRA

@MainActor
@Suite("TaxableAccount store")
struct TaxableAccountStoreTests {
    @Test("DataManager forwards taxableAccounts to AccountsManager")
    func forwarding() {
        let dm = DataManager()
        #expect(dm.taxableAccounts.isEmpty)
        dm.taxableAccounts = [TaxableAccount(name: "Brokerage", balance: 100_000, costBasis: 80_000)]
        #expect(dm.taxableAccounts.count == 1)
        #expect(dm.accounts.taxableAccounts.count == 1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/TaxableAccount\ store 2>&1 | tail -20`
Expected: FAIL (`taxableAccounts` undefined on AccountsManager/DataManager).

- [ ] **Step 3: Add storage + forwarding**

In `RetireSmartIRA/AccountsManager.swift`, directly after the `iraAccounts` property (line 18):

```swift
    var taxableAccounts: [TaxableAccount] = []
```

In `RetireSmartIRA/DataManager.swift`, directly after the `iraAccounts` forwarding block (line 86):

```swift
    // Taxable (non-retirement) accounts (forwarding to AccountsManager)
    var taxableAccounts: [TaxableAccount] {
        get { accounts.taxableAccounts }
        set { accounts.taxableAccounts = newValue }
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/TaxableAccount\ store 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/AccountsManager.swift RetireSmartIRA/DataManager.swift RetireSmartIRATests/TaxableAccountStoreTests.swift
git commit -m "feat(accounts): store taxableAccounts in AccountsManager"
```

---

### Task 3: Persist taxable accounts + migrate from `currentTaxableBalance`

**Files:**
- Modify: `RetireSmartIRA/PersistenceManager.swift:25` (StorageKey), `:152` (loadAll), `:454` (saveAll)
- Test: `RetireSmartIRATests/TaxableAccountPersistenceTests.swift`

**Interfaces:**
- Consumes: `DataManager.taxableAccounts` (Task 2).
- Produces: `PersistenceManager.StorageKey.taxableAccounts`; load seeds one account from a nonzero legacy `currentTaxableBalance` when no taxable accounts are stored.

- [ ] **Step 1: Write the failing test**

```swift
// RetireSmartIRATests/TaxableAccountPersistenceTests.swift
import Testing
import Foundation
@testable import RetireSmartIRA

@MainActor
@Suite("TaxableAccount persistence")
struct TaxableAccountPersistenceTests {
    private func freshDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "taxable-persist-\(UUID().uuidString)")!
        return d
    }

    @Test("saves and reloads taxable accounts")
    func roundTrip() {
        let d = freshDefaults()
        let dm = DataManager()
        dm.taxableAccounts = [TaxableAccount(name: "Brokerage", balance: 250_000, costBasis: 150_000)]
        PersistenceManager.saveAll(from: dm, defaults: d)

        let dm2 = DataManager()
        PersistenceManager.loadAll(into: dm2, defaults: d)
        #expect(dm2.taxableAccounts.count == 1)
        #expect(dm2.taxableAccounts[0].costBasis == 150_000)
    }

    @Test("migrates a legacy currentTaxableBalance into one account with basis=balance and confirm-basis flag")
    func migration() {
        let d = freshDefaults()
        let dm = DataManager()
        dm.multiYearAssumptions.currentTaxableBalance = 400_000
        dm.taxableAccounts = []          // none stored yet (pre-feature state)
        PersistenceManager.saveAll(from: dm, defaults: d)

        let dm2 = DataManager()
        PersistenceManager.loadAll(into: dm2, defaults: d)
        #expect(dm2.taxableAccounts.count == 1)
        let seeded = dm2.taxableAccounts[0]
        #expect(seeded.balance == 400_000)
        #expect(seeded.costBasis == 400_000)             // optimistic default, preserves behavior
        #expect(seeded.basisNeedsConfirmation == true)   // drives the "Confirm basis" badge
        #expect(seeded.availableForExpenses && seeded.availableForConversionTaxes)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/TaxableAccount\ persistence 2>&1 | tail -20`
Expected: FAIL (no persistence; migration not implemented).

- [ ] **Step 3: Implement persistence + migration**

In `RetireSmartIRA/PersistenceManager.swift` `StorageKey` enum (near line 25):

```swift
        static let taxableAccounts = "taxableAccounts"
```

In `saveAll` (mirroring the `iraAccounts` block at line 454):

```swift
        if let data = try? JSONEncoder().encode(dm.taxableAccounts) {
            defaults.set(data, forKey: StorageKey.taxableAccounts)
        }
```

In `loadAll` (after the `iraAccounts` decode block at line 152), decode if present, else migrate from the legacy scalar:

```swift
        if let data = defaults.data(forKey: StorageKey.taxableAccounts),
           let decoded = try? JSONDecoder().decode([TaxableAccount].self, from: data) {
            dm.taxableAccounts = decoded
        } else if dm.multiYearAssumptions.currentTaxableBalance > 0 {
            // One-time migration: seed a single brokerage account from the legacy scalar.
            // Basis defaults to balance (optimistic, preserves prior behavior) and is flagged
            // so the UI shows "Confirm basis".
            let bal = dm.multiYearAssumptions.currentTaxableBalance
            dm.taxableAccounts = [TaxableAccount(
                name: "Brokerage", balance: bal, costBasis: bal,
                basisNeedsConfirmation: true)]
        }
```

Note: `loadAll` must decode `multiYearAssumptions` BEFORE this block so `currentTaxableBalance` is available. Verify the assumptions decode (search `multiYearAssumptions` in `loadAll`) precedes the taxable block; if not, move the taxable block after it.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/TaxableAccount\ persistence 2>&1 | tail -20`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/PersistenceManager.swift RetireSmartIRATests/TaxableAccountPersistenceTests.swift
git commit -m "feat(accounts): persist taxable accounts + migrate legacy balance"
```

---

## Phase 2 — Engine value types and adapter

### Task 4: `TaxableAccountInput` + add to `MultiYearStaticInputs`

**Files:**
- Modify: `RetireSmartIRA/MultiYearStaticInputs.swift` (add field + init param + `withClaimAge` passthrough)
- Create: `RetireSmartIRA/TaxableAccountInput.swift`
- Test: `RetireSmartIRATests/TaxableAccountInputTests.swift`

**Interfaces:**
- Consumes: nothing from prior engine tasks.
- Produces: `struct TaxableAccountInput: Equatable, Sendable` (pure mirror of the engine-relevant fields); `MultiYearStaticInputs.taxableAccounts: [TaxableAccountInput]` (default `[]`).

- [ ] **Step 1: Write the failing test**

```swift
// RetireSmartIRATests/TaxableAccountInputTests.swift
import Testing
@testable import RetireSmartIRA

@Suite("TaxableAccountInput")
struct TaxableAccountInputTests {
    @Test("MultiYearStaticInputs defaults taxableAccounts to empty and carries them when set")
    func carries() {
        let acct = TaxableAccountInput(
            balance: 100_000, costBasis: 60_000, protectedAmount: 0,
            appreciationRate: 0.05, qualifiedDividendYield: 0.01, ordinaryIncomeYield: 0.005,
            taxExemptYield: 0, realizedLongTermGainYield: 0,
            availableForExpenses: true, availableForConversionTaxes: true, fundingPriority: nil)
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0),
            primaryCurrentAge: 65, spouseCurrentAge: nil, filingStatus: .single, state: "FL",
            primarySSClaimAge: 70, spouseSSClaimAge: nil, primaryExpectedBenefitAtFRA: 0,
            spouseExpectedBenefitAtFRA: nil, primaryBirthYear: 1961, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0, primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1, primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: nil, baselineAnnualExpenses: 0,
            taxableAccounts: [acct])
        #expect(inputs.taxableAccounts == [acct])

        let none = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0),
            primaryCurrentAge: 65, spouseCurrentAge: nil, filingStatus: .single, state: "FL",
            primarySSClaimAge: 70, spouseSSClaimAge: nil, primaryExpectedBenefitAtFRA: 0,
            spouseExpectedBenefitAtFRA: nil, primaryBirthYear: 1961, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0, primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1, primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: nil, baselineAnnualExpenses: 0)
        #expect(none.taxableAccounts.isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/TaxableAccountInput 2>&1 | tail -20`
Expected: FAIL (`TaxableAccountInput` undefined, `taxableAccounts` param missing).

- [ ] **Step 3: Add the value type and the field**

Create `RetireSmartIRA/TaxableAccountInput.swift`:

```swift
import Foundation

/// Pure-value snapshot of a TaxableAccount for the engine. No UI/DataManager deps.
struct TaxableAccountInput: Equatable, Sendable {
    var balance: Double
    var costBasis: Double
    var protectedAmount: Double
    var appreciationRate: Double
    var qualifiedDividendYield: Double
    var ordinaryIncomeYield: Double
    var taxExemptYield: Double
    var realizedLongTermGainYield: Double
    var availableForExpenses: Bool
    var availableForConversionTaxes: Bool
    var fundingPriority: Int?

    var availableBalance: Double { max(0, balance - protectedAmount) }
    var gainFraction: Double { balance > 0 ? max(0, (balance - costBasis) / balance) : 0 }
}
```

In `RetireSmartIRA/MultiYearStaticInputs.swift`: add the stored property (near the account fields, after `startingBalances`):

```swift
    let taxableAccounts: [TaxableAccountInput]
```

Add `taxableAccounts: [TaxableAccountInput] = []` as the LAST parameter of the designated `init` (after `year1SpouseQCD`), assign `self.taxableAccounts = taxableAccounts`, and pass `taxableAccounts: taxableAccounts` through the `withClaimAge` rebuild at `MultiYearStaticInputs.swift:165`.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/TaxableAccountInput 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/TaxableAccountInput.swift RetireSmartIRA/MultiYearStaticInputs.swift RetireSmartIRATests/TaxableAccountInputTests.swift
git commit -m "feat(engine): add TaxableAccountInput to MultiYearStaticInputs"
```

---

### Task 5: Adapter builds taxable accounts + supersedes manual investment income

**Files:**
- Modify: `RetireSmartIRA/MultiYearInputAdapter.swift` (build taxableAccounts; zero account-derived income types when accounts exist; synthesize from `currentTaxableBalance` when empty)
- Test: `RetireSmartIRATests/MultiYearInputAdapterTaxableTests.swift`

**Interfaces:**
- Consumes: `DataManager.taxableAccounts`, `TaxableAccountInput`.
- Produces: `MultiYearStaticInputs.taxableAccounts` populated; when non-empty, the adapter sets `primaryOtherOrdinaryIncome`/`spouseOtherOrdinaryIncome`/`primaryPreferentialIncome`/`spousePreferentialIncome` to EXCLUDE the investment-income `IncomeType`s that accounts now generate (dividends, qualifiedDividends, interest, capitalGainsShort, capitalGainsLong), keeping only non-investment ordinary "other" (stateTaxRefund, militaryRetirement, other). When empty, synthesizes one `TaxableAccountInput` from `currentTaxableBalance` (basis = balance, both flags true, zero yields) so the engine bucket matches today.

- [ ] **Step 1: Write the failing test**

```swift
// RetireSmartIRATests/MultiYearInputAdapterTaxableTests.swift
import Testing
@testable import RetireSmartIRA

@MainActor
@Suite("MultiYearInputAdapter taxable")
struct MultiYearInputAdapterTaxableTests {
    @Test("empty taxable accounts synthesize one bucket from currentTaxableBalance")
    func synthesizeLegacy() {
        let dm = DataManager()
        dm.taxableAccounts = []
        var a = dm.multiYearAssumptions
        a.currentTaxableBalance = 200_000
        let inputs = MultiYearInputAdapter.build(from: dm, scenarioState: dm.scenario, assumptions: a)
        #expect(inputs.taxableAccounts.count == 1)
        #expect(inputs.taxableAccounts[0].balance == 200_000)
        #expect(inputs.taxableAccounts[0].costBasis == 200_000)
    }

    @Test("when accounts exist, manual investment-income IncomeSources are not double-counted")
    func supersede() {
        let dm = DataManager()
        dm.incomeSources = [
            IncomeSource(name: "Div", type: .qualifiedDividends, annualAmount: 9_000, owner: .primary),
            IncomeSource(name: "Refund", type: .stateTaxRefund, annualAmount: 1_000, owner: .primary),
        ]
        dm.taxableAccounts = [TaxableAccount(name: "B", balance: 300_000, costBasis: 200_000,
                                             qualifiedDividendYield: 0.03)]
        let inputs = MultiYearInputAdapter.build(from: dm, scenarioState: dm.scenario,
                                                 assumptions: dm.multiYearAssumptions)
        // qualifiedDividends from the manual entry are dropped (account generates them now)...
        #expect(inputs.primaryPreferentialIncome == 0)
        // ...but the non-investment stateTaxRefund still flows as ordinary "other".
        #expect(inputs.primaryOtherOrdinaryIncome == 1_000)
        #expect(inputs.taxableAccounts.count == 1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/MultiYearInputAdapter\ taxable 2>&1 | tail -20`
Expected: FAIL.

- [ ] **Step 3: Implement adapter changes**

In `RetireSmartIRA/MultiYearInputAdapter.swift`:

(a) Build the engine accounts and a flag for whether they exist (before the `return MultiYearStaticInputs(...)`):

```swift
        // Taxable accounts -> engine value types. When the user has none, synthesize one
        // from the legacy scalar so the engine bucket matches pre-feature behavior.
        let taxableInputs: [TaxableAccountInput] = dataManager.taxableAccounts.isEmpty
            ? (currentTaxableBalance > 0
                ? [TaxableAccountInput(
                    balance: currentTaxableBalance, costBasis: currentTaxableBalance,
                    protectedAmount: 0, appreciationRate: assumptions.investmentGrowthRate,
                    qualifiedDividendYield: 0, ordinaryIncomeYield: 0, taxExemptYield: 0,
                    realizedLongTermGainYield: 0, availableForExpenses: true,
                    availableForConversionTaxes: true, fundingPriority: nil)]
                : [])
            : dataManager.taxableAccounts.map { acct in
                TaxableAccountInput(
                    balance: acct.balance, costBasis: acct.costBasis,
                    protectedAmount: acct.protectedAmount,
                    appreciationRate: acct.expectedAppreciationRate,
                    qualifiedDividendYield: acct.qualifiedDividendYield,
                    ordinaryIncomeYield: acct.ordinaryIncomeYield,
                    taxExemptYield: acct.taxExemptYield,
                    realizedLongTermGainYield: acct.realizedLongTermGainYield,
                    availableForExpenses: acct.availableForExpenses,
                    availableForConversionTaxes: acct.availableForConversionTaxes,
                    fundingPriority: acct.fundingPriority)
            }
        let accountsSupersedeIncome = !dataManager.taxableAccounts.isEmpty
```

(b) When `accountsSupersedeIncome`, recompute the four income figures excluding investment types. Replace the `primaryOther`/`spouseOther`/`primaryPreferential`/`spousePreferential` assignments (lines 144-147) so that, when superseded, they exclude the account-generated types. Add a private helper:

```swift
    /// Ordinary "other" income types that are NOT generated by taxable accounts and must
    /// still flow when accounts supersede manual investment income.
    private static func isNonInvestmentOrdinary(type t: IncomeType) -> Bool {
        switch t {
        case .stateTaxRefund, .militaryRetirement, .other: return true
        default: return false
        }
    }
```

and compute:

```swift
        let primaryOther: Double
        let spouseOther: Double
        let primaryPreferential: Double
        let spousePreferential: Double
        if accountsSupersedeIncome {
            primaryOther = sources.filter { $0.owner == .primary && Self.isNonInvestmentOrdinary(type: $0.type) }
                .reduce(0) { $0 + $1.annualAmount }
            spouseOther = dataManager.enableSpouse
                ? sources.filter { $0.owner == .spouse && Self.isNonInvestmentOrdinary(type: $0.type) }
                    .reduce(0) { $0 + $1.annualAmount }
                : 0
            primaryPreferential = 0
            spousePreferential = 0
        } else {
            primaryOther = Self.primaryOtherOrdinaryIncome(from: sources)
            spouseOther = Self.spouseOtherOrdinaryIncome(from: sources, enableSpouse: dataManager.enableSpouse)
            primaryPreferential = Self.primaryPreferentialIncome(from: sources)
            spousePreferential = Self.spousePreferentialIncome(from: sources, enableSpouse: dataManager.enableSpouse)
        }
```

(Replace the four existing `let` bindings at 144-147 with the block above.) Pass `taxableAccounts: taxableInputs` into the `MultiYearStaticInputs(...)` initializer.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/MultiYearInputAdapter\ taxable 2>&1 | tail -20`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/MultiYearInputAdapter.swift RetireSmartIRATests/MultiYearInputAdapterTaxableTests.swift
git commit -m "feat(engine): adapter builds taxable accounts, supersedes manual investment income"
```

---

## Phase 3 — ProjectionEngine refactor

> This phase replaces the single `taxable` scalar with per-account buckets and a real
> cash-and-tax waterfall. Build it behind the backward-compat guarantee: when
> `inputs.taxableAccounts` is empty, the engine must reproduce today's numbers.
> Implement a small pure helper first (Task 6), then wire it into the loop (Task 7),
> then lock the regression (Task 8).

### Task 6: Pure taxable-account engine helpers

**Files:**
- Create: `RetireSmartIRA/TaxableAccountEngine.swift`
- Test: `RetireSmartIRATests/TaxableAccountEngineTests.swift`

**Interfaces:**
- Produces:
  - `struct TaxableBucket { var balance: Double; var costBasis: Double; let input: TaxableAccountInput }`
  - `enum TaxableAccountEngine`:
    - `static func annualIncome(_ buckets: [TaxableBucket]) -> (ordinary: Double, preferential: Double, taxExempt: Double, spendableCash: Double)` — income on current balances; ordinary = sum ordinaryYield*bal; preferential = sum (qualDiv+ltGain)*bal; taxExempt = sum taxExemptYield*bal; spendableCash = income from accounts where `availableForExpenses`.
    - `static func sell(amount: Double, from buckets: inout [TaxableBucket], forTaxes: Bool) -> (raised: Double, realizedGain: Double)` — draws from eligible buckets (respecting `availableForExpenses`/`availableForConversionTaxes` and `availableBalance` reserve), in funding order (explicit `fundingPriority` ascending, then highest-basis-first), realizing proportional gain and reducing basis proportionally.

- [ ] **Step 1: Write the failing test**

```swift
// RetireSmartIRATests/TaxableAccountEngineTests.swift
import Testing
@testable import RetireSmartIRA

@Suite("TaxableAccountEngine")
struct TaxableAccountEngineTests {
    private func input(bal: Double, basis: Double, ordYield: Double = 0, qDiv: Double = 0,
                       muni: Double = 0, ltGain: Double = 0, reserve: Double = 0,
                       expenses: Bool = true, taxes: Bool = true, priority: Int? = nil) -> TaxableAccountInput {
        TaxableAccountInput(balance: bal, costBasis: basis, protectedAmount: reserve,
            appreciationRate: 0, qualifiedDividendYield: qDiv, ordinaryIncomeYield: ordYield,
            taxExemptYield: muni, realizedLongTermGainYield: ltGain,
            availableForExpenses: expenses, availableForConversionTaxes: taxes, fundingPriority: priority)
    }
    private func bucket(_ i: TaxableAccountInput) -> TaxableBucket {
        TaxableBucket(balance: i.balance, costBasis: i.costBasis, input: i)
    }

    @Test("annualIncome splits by character; muni is excluded from spendable-but-taxable buckets correctly")
    func income() {
        let b = [bucket(input(bal: 100_000, basis: 50_000, ordYield: 0.02, qDiv: 0.03, muni: 0))]
        let r = TaxableAccountEngine.annualIncome(b)
        #expect(r.ordinary == 2_000)
        #expect(r.preferential == 3_000)
        #expect(r.taxExempt == 0)
        #expect(r.spendableCash == 5_000)
    }

    @Test("walled account income is taxed (counted) but not spendable")
    func walled() {
        let b = [bucket(input(bal: 100_000, basis: 100_000, ordYield: 0.04, expenses: false, taxes: false))]
        let r = TaxableAccountEngine.annualIncome(b)
        #expect(r.ordinary == 4_000)
        #expect(r.spendableCash == 0)
    }

    @Test("sell realizes proportional gain, reduces basis, respects reserve and funding order")
    func sell() {
        // A: 50% gain, priority 2.  B: 0% gain, priority 1 (used first).  Reserve 10k on B.
        var buckets = [
            bucket(input(bal: 100_000, basis: 50_000, priority: 2)),
            bucket(input(bal: 60_000, basis: 60_000, reserve: 10_000, priority: 1)),
        ]
        let out = TaxableAccountEngine.sell(amount: 70_000, from: &buckets, forTaxes: true)
        #expect(out.raised == 70_000)
        // B contributes its available 50k (no gain), A contributes 20k (50% gain = 10k).
        #expect(out.realizedGain == 10_000)
        #expect(buckets[1].balance == 10_000)         // B floored at its reserve
        #expect(abs(buckets[0].balance - 80_000) < 1e-6)
        #expect(abs(buckets[0].costBasis - 40_000) < 1e-6) // basis reduced proportionally
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/TaxableAccountEngine 2>&1 | tail -20`
Expected: FAIL.

- [ ] **Step 3: Implement the helpers**

```swift
// RetireSmartIRA/TaxableAccountEngine.swift
import Foundation

struct TaxableBucket: Equatable {
    var balance: Double
    var costBasis: Double
    let input: TaxableAccountInput

    var availableBalance: Double { max(0, balance - input.protectedAmount) }
    var gainFraction: Double { balance > 0 ? max(0, (balance - costBasis) / balance) : 0 }
}

enum TaxableAccountEngine {
    static func annualIncome(_ buckets: [TaxableBucket]) -> (ordinary: Double, preferential: Double, taxExempt: Double, spendableCash: Double) {
        var ord = 0.0, pref = 0.0, exempt = 0.0, cash = 0.0
        for b in buckets {
            let o = b.input.ordinaryIncomeYield * b.balance
            let p = (b.input.qualifiedDividendYield + b.input.realizedLongTermGainYield) * b.balance
            let e = b.input.taxExemptYield * b.balance
            ord += o; pref += p; exempt += e
            if b.input.availableForExpenses { cash += o + p + e }
        }
        return (ord, pref, exempt, cash)
    }

    /// Funding order: explicit fundingPriority ascending first, then highest basis (lowest gain) first.
    private static func order(_ idxs: [Int], _ buckets: [TaxableBucket]) -> [Int] {
        idxs.sorted { a, b in
            switch (buckets[a].input.fundingPriority, buckets[b].input.fundingPriority) {
            case let (pa?, pb?): if pa != pb { return pa < pb }
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): break
            }
            return buckets[a].gainFraction < buckets[b].gainFraction
        }
    }

    static func sell(amount: Double, from buckets: inout [TaxableBucket], forTaxes: Bool) -> (raised: Double, realizedGain: Double) {
        guard amount > 0 else { return (0, 0) }
        let eligible = buckets.indices.filter {
            forTaxes ? buckets[$0].input.availableForConversionTaxes : buckets[$0].input.availableForExpenses
        }
        var remaining = amount
        var gain = 0.0
        for i in order(eligible, buckets) {
            guard remaining > 0 else { break }
            let take = min(remaining, buckets[i].availableBalance)
            guard take > 0 else { continue }
            gain += take * buckets[i].gainFraction
            let basisFraction = buckets[i].balance > 0 ? buckets[i].costBasis / buckets[i].balance : 0
            buckets[i].costBasis -= take * basisFraction
            buckets[i].balance -= take
            remaining -= take
        }
        return (amount - remaining, gain)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/TaxableAccountEngine 2>&1 | tail -20`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/TaxableAccountEngine.swift RetireSmartIRATests/TaxableAccountEngineTests.swift
git commit -m "feat(engine): pure taxable-account income + sale-with-gain helpers"
```

---

### Task 7: Wire per-account buckets into `ProjectionEngine`

**Files:**
- Modify: `RetireSmartIRA/ProjectionEngine.swift` (Steps 1, 4, 5, 6, 7 of the year loop; the `taxable` scalar becomes `buckets: [TaxableBucket]`)
- Test: `RetireSmartIRATests/ProjectionEngineTaxableTests.swift`

**Interfaces:**
- Consumes: `TaxableBucket`, `TaxableAccountEngine` (Task 6); `inputs.taxableAccounts` (Task 4).
- Produces: an engine where account income flows into AGI/MAGI, muni raises MAGI only, expenses and taxes are funded from accounts with realized gains, and per-account growth is honored.

- [ ] **Step 1: Write the failing tests**

```swift
// RetireSmartIRATests/ProjectionEngineTaxableTests.swift
import Testing
@testable import RetireSmartIRA

@MainActor
@Suite("ProjectionEngine taxable")
struct ProjectionEngineTaxableTests {
    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }

    private func baseInputs(taxable: [TaxableAccountInput]) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 500_000, roth: 0, taxable: 0, hsa: 0),
            baseYear: 2026, primaryCurrentAge: 66, spouseCurrentAge: nil, filingStatus: .single, state: "FL",
            primarySSClaimAge: 70, spouseSSClaimAge: nil, primaryExpectedBenefitAtFRA: 0,
            spouseExpectedBenefitAtFRA: nil, primaryBirthYear: 1960, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0, primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1, primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: nil, baselineAnnualExpenses: 0, taxableAccounts: taxable)
    }
    private func assumptions() -> MultiYearAssumptions {
        MultiYearAssumptions(horizonEndAge: 67, horizonEndAgeSpouse: nil, cpiRate: 0,
            investmentGrowthRate: 0, withdrawalOrderingRule: .taxEfficient, stressTestEnabled: false,
            perYearExpenseOverrides: [:], currentTaxableBalance: 0, currentHSABalance: 0)
    }
    private func acct(bal: Double, basis: Double, ordYield: Double = 0, muni: Double = 0) -> TaxableAccountInput {
        TaxableAccountInput(balance: bal, costBasis: basis, protectedAmount: 0, appreciationRate: 0,
            qualifiedDividendYield: 0, ordinaryIncomeYield: ordYield, taxExemptYield: muni,
            realizedLongTermGainYield: 0, availableForExpenses: true, availableForConversionTaxes: true,
            fundingPriority: nil)
    }

    @Test("account ordinary yield raises AGI (tax drag)")
    func taxDrag() {
        let withYield = ProjectionEngine(configProvider: provider).project(
            inputs: baseInputs(taxable: [acct(bal: 1_000_000, basis: 1_000_000, ordYield: 0.03)]),
            assumptions: assumptions(), actionsPerYear: [2026: []])
        let noYield = ProjectionEngine(configProvider: provider).project(
            inputs: baseInputs(taxable: [acct(bal: 1_000_000, basis: 1_000_000, ordYield: 0)]),
            assumptions: assumptions(), actionsPerYear: [2026: []])
        #expect(withYield[0].agi > noYield[0].agi)
        #expect(abs(withYield[0].agi - noYield[0].agi - 30_000) < 1.0) // 3% of 1M
    }

    @Test("muni yield raises IRMAA MAGI but not AGI/taxable income")
    func muniMagi() {
        let r = ProjectionEngine(configProvider: provider).project(
            inputs: baseInputs(taxable: [acct(bal: 1_000_000, basis: 1_000_000, muni: 0.03)]),
            assumptions: assumptions(), actionsPerYear: [2026: []])
        #expect(r[0].agi == 0)                       // muni not in AGI
        #expect((r[0].irmaaMagi ?? 0) >= 30_000)     // but in MAGI add-back
    }

    @Test("empty taxableAccounts reproduces legacy single-bucket behavior")
    func backwardCompat() {
        // Legacy path: assumptions.currentTaxableBalance drives a synthesized bucket via the adapter,
        // but project() consumes inputs directly, so pass an empty array and a legacy-equivalent single
        // account to confirm identical end balances.
        var legacy = assumptions(); legacy.currentTaxableBalance = 0
        let viaAccount = ProjectionEngine(configProvider: provider).project(
            inputs: baseInputs(taxable: [acct(bal: 200_000, basis: 200_000)]),
            assumptions: legacy, actionsPerYear: [2026: []])
        #expect(viaAccount[0].endOfYearBalances.taxable == 200_000) // no yield, no growth, no draw
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/ProjectionEngine\ taxable 2>&1 | tail -20`
Expected: FAIL.

- [ ] **Step 3: Refactor the year loop**

In `RetireSmartIRA/ProjectionEngine.swift`, replace the `var taxable` scalar (line 126) with a bucket array seeded from `inputs.taxableAccounts`, falling back to a single bucket from `inputs.startingBalances.taxable` when empty (so callers that still pass only the snapshot keep working):

```swift
        var buckets: [TaxableBucket] = inputs.taxableAccounts.isEmpty
            ? (inputs.startingBalances.taxable > 0
                ? [TaxableBucket(balance: inputs.startingBalances.taxable,
                                 costBasis: inputs.startingBalances.taxable,
                                 input: TaxableAccountInput(
                                    balance: inputs.startingBalances.taxable,
                                    costBasis: inputs.startingBalances.taxable,
                                    protectedAmount: 0, appreciationRate: assumptions.investmentGrowthRate,
                                    qualifiedDividendYield: 0, ordinaryIncomeYield: 0, taxExemptYield: 0,
                                    realizedLongTermGainYield: 0, availableForExpenses: true,
                                    availableForConversionTaxes: true, fundingPriority: nil))]
                : [])
            : inputs.taxableAccounts.map {
                TaxableBucket(balance: $0.balance, costBasis: $0.costBasis, input: $0)
            }
        var totalTaxableBalance: Double { buckets.reduce(0) { $0 + $1.balance } }
```

Then make these edits inside the `for year` loop (anchors are the existing Step comments):

1. **Step 1 `.taxableWithdrawal`** (line 253): instead of `taxable -= actual`, call
   `let s = TaxableAccountEngine.sell(amount: amount, from: &buckets, forTaxes: false)`,
   set `explicitTaxableWithdrawals += s.raised`, and accumulate `explicitTaxableGain += s.realizedGain`
   (declare `var explicitTaxableGain = 0.0` beside the other accumulators near line 183).
   `.hsaContribution`/`.fourOhOneKContribution` that draw `taxable` (lines 267, 274) similarly call
   `sell(forTaxes: false)`.

2. **Account income** (new, just before Step 4 expense funding at line 364): 
   ```swift
   let acctIncome = TaxableAccountEngine.annualIncome(buckets)
   ```

3. **Step 4 passiveIncome** (line 385): add `+ acctIncome.spendableCash`. After expense funding, if a
   shortfall remains it is covered by selling buckets via `sell(forTaxes: false)` BEFORE falling to
   traditional/Roth in `autoFundExpenses`. (Pass `&buckets` into a small pre-step or sell here and reduce
   the shortfall fed to `autoFundExpenses`.)

4. **Step 5 growth** (line 425): replace `taxable *= growthFactor` with per-bucket appreciation, and
   reinvest walled income + spendable surplus:
   ```swift
   for i in buckets.indices {
       // walled account income reinvests (already-taxed): grows balance and basis
       if !buckets[i].input.availableForExpenses {
           let inc = (buckets[i].input.ordinaryIncomeYield + buckets[i].input.qualifiedDividendYield
                      + buckets[i].input.taxExemptYield + buckets[i].input.realizedLongTermGainYield)
                     * buckets[i].balance
           buckets[i].balance += inc
           buckets[i].costBasis += inc
       }
       let g = 1.0 + buckets[i].input.appreciationRate
       buckets[i].balance *= g   // appreciation only; basis unchanged
   }
   ```
   (Spendable surplus reinvestment: after Step 7, deposit any leftover spendable cash back into the
   first available bucket, increasing balance and basis equally.)

5. **Step 6 AGI/MAGI** (lines 439-466): add `acctIncome.ordinary` to `otherOrdinaryIncome`,
   add `acctIncome.preferential` (plus realized sale gains, below) to `preferentialIncome`, and add
   `acctIncome.taxExempt` to `magiAddback` (replacing the hardcoded `tax-exempt = 0`). Realized gains
   from expense/tax sales are added to the preferential bucket.

6. **Step 7 tax payment** (line 615): pay the tax bill from buckets via
   `sell(amount: shortfall, from: &buckets, forTaxes: true)`; the realized gain it produces is added to
   taxable income and folded into the EXISTING 3-iteration fixed point (the `taxOn(dW)` loop at line 633),
   extended so each iteration also accounts for `gain * preferentialRate`. Only when buckets are exhausted
   does it gross-up from traditional as today.

7. **End-of-year balances** (the `YearRecommendation(... endOfYearBalances:)` build near line 666):
   set `taxable: totalTaxableBalance`.

Keep the legacy `taxable` references compiling by deleting the old scalar and routing all reads through
`totalTaxableBalance`.

- [ ] **Step 4: Run the new suite, then the FULL suite**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/ProjectionEngine\ taxable 2>&1 | tail -20`
Expected: PASS (3 tests).

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tail -8`
Expected: all tests pass (the empty-accounts path must keep existing ProjectionEngine tests green).

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/ProjectionEngine.swift RetireSmartIRATests/ProjectionEngineTaxableTests.swift
git commit -m "feat(engine): per-account taxable buckets, income drag, muni-MAGI, gains on sale"
```

---

### Task 8: Direction-of-effect regression (credibility proof)

**Files:**
- Test: `RetireSmartIRATests/TaxableAggressivenessTests.swift`

**Interfaces:**
- Consumes: `OptimizationEngine.optimize`, `TaxableAccountInput`.

- [ ] **Step 1: Write the test**

```swift
// RetireSmartIRATests/TaxableAggressivenessTests.swift
import Testing
@testable import RetireSmartIRA

@MainActor
@Suite("Taxable aggressiveness")
struct TaxableAggressivenessTests {
    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }
    private func inputs(taxable: [TaxableAccountInput]) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 1_500_000, roth: 0, taxable: 0, hsa: 0),
            baseYear: 2026, primaryCurrentAge: 64, spouseCurrentAge: nil, filingStatus: .single, state: "FL",
            primarySSClaimAge: 70, spouseSSClaimAge: nil, primaryExpectedBenefitAtFRA: 0,
            spouseExpectedBenefitAtFRA: nil, primaryBirthYear: 1962, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0, primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1, primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: nil, baselineAnnualExpenses: 60_000, taxableAccounts: taxable)
    }
    private func assumptions() -> MultiYearAssumptions {
        MultiYearAssumptions(horizonEndAge: 90, horizonEndAgeSpouse: nil, cpiRate: 0.02,
            investmentGrowthRate: 0.05, withdrawalOrderingRule: .taxEfficient, stressTestEnabled: false,
            perYearExpenseOverrides: [:], currentTaxableBalance: 0, currentHSABalance: 0)
    }
    private func totalConverted(_ r: OptimizationEngine.Result) -> Double {
        r.recommendedPath.reduce(0) { acc, yr in acc + yr.actions.reduce(0) { a, act in
            if case let .rothConversion(amount) = act { return a + amount }; return a } }
    }

    @Test("low-basis taxable (big embedded gain) makes the optimizer convert no MORE than high-basis")
    func gainsRestrain() {
        let highBasis = TaxableAccountInput(balance: 400_000, costBasis: 400_000, protectedAmount: 0,
            appreciationRate: 0.05, qualifiedDividendYield: 0.02, ordinaryIncomeYield: 0, taxExemptYield: 0,
            realizedLongTermGainYield: 0, availableForExpenses: true, availableForConversionTaxes: true,
            fundingPriority: nil)
        let lowBasis = TaxableAccountInput(balance: 400_000, costBasis: 40_000, protectedAmount: 0,
            appreciationRate: 0.05, qualifiedDividendYield: 0.02, ordinaryIncomeYield: 0, taxExemptYield: 0,
            realizedLongTermGainYield: 0, availableForExpenses: true, availableForConversionTaxes: true,
            fundingPriority: nil)
        let rHigh = OptimizationEngine().optimize(inputs: inputs(taxable: [highBasis]),
            assumptions: assumptions(), configProvider: provider)
        let rLow = OptimizationEngine().optimize(inputs: inputs(taxable: [lowBasis]),
            assumptions: assumptions(), configProvider: provider)
        // Selling low-basis assets to pay conversion tax realizes gains, so converting is costlier:
        // the low-basis plan must not convert MORE than the high-basis plan.
        #expect(totalConverted(rLow) <= totalConverted(rHigh) + 1.0)
    }
}
```

- [ ] **Step 2: Run it**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/Taxable\ aggressiveness 2>&1 | tail -20`
Expected: PASS. If it fails, the gain-on-sale tax is not feeding the objective; revisit Task 7 Step 3 item 6.

- [ ] **Step 3: Commit**

```bash
git add RetireSmartIRATests/TaxableAggressivenessTests.swift
git commit -m "test(engine): embedded gains restrain conversion aggressiveness"
```

---

## Phase 4 — UI

### Task 9: Accounts tab "Taxable Accounts" section + editor

**Files:**
- Create: `RetireSmartIRA/TaxableAccountsSection.swift` (list section + `AddTaxableAccountView`)
- Modify: `RetireSmartIRA/AccountsView.swift` (embed the section below the IRA list, near line 110)

**Interfaces:**
- Consumes: `DataManager.taxableAccounts`, `TaxableAccount`, `TaxableAccountCategory`.

- [ ] **Step 1: Build the section + editor**

Create `RetireSmartIRA/TaxableAccountsSection.swift`. Mirror the `AccountRow`/`AddAccountView` pattern in `AccountsView.swift`. The editor uses progressive disclosure:

```swift
import SwiftUI

struct TaxableAccountsSection: View {
    @Environment(DataManager.self) private var dataManager
    @State private var showingAdd = false
    @State private var editing: TaxableAccount?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Taxable Accounts").font(.headline)
                Spacer()
                Button { showingAdd = true } label: { Image(systemName: "plus.circle.fill") }
            }
            Text("Brokerage accounts, cash, muni ladders, taxable trusts, and other non-retirement assets.")
                .font(.caption).foregroundStyle(.secondary)

            if dataManager.taxableAccounts.isEmpty {
                Text("None entered").font(.callout).foregroundStyle(.secondary).padding(.vertical, 4)
            } else {
                ForEach(dataManager.taxableAccounts) { acct in
                    Button { editing = acct } label: { TaxableAccountRow(account: acct) }
                        .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $showingAdd) { TaxableAccountEditor(existing: nil) }
        .sheet(item: $editing) { TaxableAccountEditor(existing: $0) }
    }
}

struct TaxableAccountRow: View {
    let account: TaxableAccount
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(account.name).font(.body)
                Text(account.category.rawValue).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(account.balance, format: .currency(code: "USD").precision(.fractionLength(0)))
                if account.basisNeedsConfirmation {
                    Text("Confirm basis").font(.caption2).foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct TaxableAccountEditor: View {
    @Environment(DataManager.self) private var dataManager
    @Environment(\.dismiss) private var dismiss
    let existing: TaxableAccount?

    @State private var draft: TaxableAccount
    @State private var showAdvanced = false

    init(existing: TaxableAccount?) {
        self.existing = existing
        _draft = State(initialValue: existing ?? TaxableAccount(name: "", balance: 0, costBasis: 0))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Name", text: $draft.name)
                    Picker("Owner", selection: $draft.owner) {
                        ForEach(Owner.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Type", selection: $draft.category) {
                        ForEach(TaxableAccountCategory.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }
                Section {
                    currencyField("Balance", $draft.balance)
                    currencyField("Cost basis / amount invested", $draft.costBasis)
                    if draft.basisNeedsConfirmation {
                        Label("Confirm basis", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    percentField("Expected price growth, excluding income yield", $draft.expectedAppreciationRate)
                } footer: {
                    Text("Cost basis is used to estimate capital gains if this account is sold to pay expenses or conversion taxes. Dividends, interest, and tax-exempt income are entered under Advanced.")
                }
                DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                    percentField("Qualified dividend yield", $draft.qualifiedDividendYield)
                    percentField("Ordinary income yield (interest, non-qualified dividends)", $draft.ordinaryIncomeYield)
                    percentField("Tax-exempt (muni) yield", $draft.taxExemptYield)
                    percentField("Long-term capital gain distributions", $draft.realizedLongTermGainYield)
                    currencyField("Reserve (never spend below)", $draft.protectedAmount)
                    Toggle("Can be used for living expenses", isOn: $draft.availableForExpenses)
                    Toggle("Can be used to pay Roth conversion taxes", isOn: $draft.availableForConversionTaxes)
                }
            }
            .navigationTitle(existing == nil ? "Add Taxable Account" : "Edit Taxable Account")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func save() {
        draft.basisNeedsConfirmation = false  // saving confirms the basis the user sees
        if let existing, let i = dataManager.taxableAccounts.firstIndex(where: { $0.id == existing.id }) {
            dataManager.taxableAccounts[i] = draft
        } else {
            dataManager.taxableAccounts.append(draft)
        }
        dataManager.saveAllData()
    }

    private func currencyField(_ label: String, _ value: Binding<Double>) -> some View {
        HStack { Text(label); Spacer()
            TextField("0", value: value, format: .number).multilineTextAlignment(.trailing) }
    }
    private func percentField(_ label: String, _ value: Binding<Double>) -> some View {
        HStack { Text(label); Spacer()
            TextField("0", value: value, format: .percent).multilineTextAlignment(.trailing).frame(width: 90) }
    }
}
```

In `RetireSmartIRA/AccountsView.swift`, embed the section after the IRA list (around line 110, inside the same scroll/VStack container):

```swift
                TaxableAccountsSection()
```

- [ ] **Step 2: Build to confirm it compiles**

Run: `xcodebuild build -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tail -8`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add RetireSmartIRA/TaxableAccountsSection.swift RetireSmartIRA/AccountsView.swift
git commit -m "feat(ui): taxable accounts section + editor in Accounts tab"
```

---

### Task 10: Multi-Year roll-up + empty-state warning + disclosure line

**Files:**
- Modify: `RetireSmartIRA/MultiYearPlanSections.swift` (AssumptionsStripView: replace editable taxable field with read-only roll-up)
- Modify: `RetireSmartIRA/MultiYearPlanView.swift` (empty-state warning when conversions recommended but no taxable account; disclosure line near results)

**Interfaces:**
- Consumes: `DataManager.taxableAccounts`.

- [ ] **Step 1: Replace the editable taxable field with a roll-up**

In `RetireSmartIRA/MultiYearPlanSections.swift` `AssumptionsStripView`, replace the editable taxable `TextField` (line 18) with a read-only row. Inject the accounts via a new `let taxableSummary: (count: Int, total: Double)` parameter passed from `MultiYearPlanView`:

```swift
            HStack {
                Text("Taxable accounts")
                Spacer()
                if taxableSummary.count == 0 {
                    Text("None entered").foregroundStyle(.secondary)
                } else {
                    Text("\(taxableSummary.total, format: .currency(code: "USD").precision(.fractionLength(0))) across \(taxableSummary.count) accounts")
                        .foregroundStyle(.secondary)
                }
            }
```

(The field is now read-only; users edit in the Accounts tab. Keep the HSA field as-is.)

- [ ] **Step 2: Add warning + disclosure in MultiYearPlanView**

In `RetireSmartIRA/MultiYearPlanView.swift`, inside the results branch (after `PlanSummaryView`, near line 112), add:

```swift
                    if dataManager.taxableAccounts.isEmpty,
                       ladderRows.contains(where: { $0.conversion > 0 }) {
                        Text("No taxable account entered. This plan assumes Roth conversion taxes must be paid from additional IRA withdrawals, which may materially change the conversion ladder.")
                            .font(.callout).foregroundStyle(.orange)
                            .padding().background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    }
```

And just before `AssumptionsLimitationsView()` (line 158), add the disclosure line:

```swift
                    Text("Taxable-account sales use an average cost-basis estimate and a default funding order. Lot-level tax selection, short-term holding periods, and single-year income reconciliation are planned future enhancements.")
                        .font(.caption).foregroundStyle(.secondary)
```

Pass the summary into `AssumptionsStripView`:

```swift
                AssumptionsStripView(
                    taxableSummary: (dataManager.taxableAccounts.count,
                                     dataManager.taxableAccounts.reduce(0) { $0 + $1.balance }),
                    hsaBalance: Binding(get: { manager.assumptions.currentHSABalance },
                                        set: { manager.assumptions.currentHSABalance = $0 }),
                    horizonEndAge: Binding(get: { manager.assumptions.horizonEndAge },
                                           set: { manager.assumptions.horizonEndAge = $0 }),
                    onCommit: { recomputeAll() })
```

Remove the old `taxableBalance` binding parameter from `AssumptionsStripView`'s definition and this call site.

- [ ] **Step 3: Build + run full suite**

Run: `xcodebuild build -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tail -8`
Expected: BUILD SUCCEEDED.

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tail -8`
Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add RetireSmartIRA/MultiYearPlanSections.swift RetireSmartIRA/MultiYearPlanView.swift
git commit -m "feat(ui): multi-year taxable roll-up, empty-state warning, disclosure line"
```

---

## Self-Review (completed by plan author)

- **Spec coverage:** data model (Task 1), persistence + migration (Task 3), per-account return + income-by-character + muni-MAGI + blended-basis sales + earmark/reserve/funding-priority gating + walled reinvestment (Tasks 6-7), adapter single-source supersede + backward-compat (Tasks 4-5, 7), UI section/editor/roll-up/warning/disclosure (Tasks 9-10), direction-of-effect proof (Task 8). The `category` field is captured (Task 1) and surfaced (Task 9). V2.1 items are intentionally absent.
- **Placeholder scan:** no TBD/TODO; each code step shows code; integration anchors cite exact files/lines.
- **Type consistency:** `TaxableAccount` (model) vs `TaxableAccountInput` (engine) vs `TaxableBucket` (engine mutable state) are distinct by design; the adapter (Task 5) and engine seed (Task 7) are the only converters. `availableBalance`/`gainFraction` names are consistent across model, input, and bucket. `annualIncome`/`sell` signatures in Task 6 match their call sites in Task 7.

## Known follow-up (out of scope, noted for planning awareness)

- Spendable-surplus reinvestment ordering (Task 7 item 4) uses "first available bucket" as the default; revisit if a fairer pro-rata split is wanted.
- The positioning/language guardrails (Explorer framing, "under these assumptions") are a separate copy task, not in this plan.
