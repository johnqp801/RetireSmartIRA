# SS Module Audit (1.9 baseline)

**Date:** 2026-05-02
**Audit purpose:** Document the public SS calculation surface for use by the 2.0 multi-year tax strategy engine.

---

## SSCalculationEngine — public static methods

`SSCalculationEngine` is a pure-calculation struct in `RetireSmartIRA/SSCalculationEngine.swift`. It imports only `Foundation`. No SwiftUI, no DataManager dependencies. All methods are `static`.

### FRA Methods

**`fullRetirementAge(birthYear: Int) -> (years: Int, months: Int)`**
- Purpose: Returns FRA as a (years, months) tuple using the official SSA birth-year schedule.
- Input: birth year integer
- Output: tuple, e.g. `(67, 0)` for 1960+, `(66, 2)` for 1955
- Year-dependent: one-time per person (birth year fixed)

**`fraInMonths(birthYear: Int) -> Int`**
- Purpose: FRA expressed as total months for arithmetic convenience
- Output: integer total months (e.g. 804 for age 67)
- Year-dependent: no

**`fraDescription(birthYear: Int) -> String`**
- Purpose: Human-readable FRA string (e.g. "66 and 2 months" or "67")
- Year-dependent: no

---

### Benefit Adjustment Methods

**`benefitAtAge(claimingAge: Int, claimingMonth: Int = 0, pia: Double, fraYears: Int, fraMonths: Int) -> Double`**
- Purpose: Compute monthly benefit at any claiming age given PIA, applying early reduction or delayed credits
- Inputs: claiming age + month offset, PIA (monthly benefit at FRA), FRA components
- Output: adjusted monthly benefit
- Year-dependent: no (operates on ages, not calendar years)

**`applyEarlyReduction(pia: Double, monthsEarly: Int) -> Double`**
- Purpose: Apply SSA early-claim reduction (5/9% per month for first 36 months; 5/12% per month beyond)
- Inputs: PIA, months claimed before FRA
- Output: reduced monthly benefit

**`applySpousalEarlyReduction(maxSpousal: Double, monthsEarly: Int) -> Double`**
- Purpose: Apply SSA spousal-benefit early-claim reduction (different factors than own-record: 25/36% then 5/12%)
- Inputs: max spousal benefit amount, months before FRA
- Output: reduced spousal benefit

**`applyDelayedCredits(pia: Double, monthsDelayed: Int) -> Double`**
- Purpose: Apply delayed retirement credits (2/3% per month past FRA, i.e. 8%/year, capped at 70)
- Output: increased monthly benefit

**`adjustmentPercentage(claimingAge: Int, claimingMonth: Int = 0, fraYears: Int, fraMonths: Int) -> Double`**
- Purpose: Calculate the net adjustment percentage (negative = reduction, positive = increase) for UI display
- Output: percentage as Double (e.g. -25.0, +24.0)

---

### Break-Even / Scenario Analysis Methods

**`claimingScenarios(pia: Double, birthYear: Int, lifeExpectancy: Int, colaRate: Double = 2.5) -> [SSClaimingScenario]`**
- Purpose: Generate one `SSClaimingScenario` for each claiming age 62–70, with cumulative benefit by age and cross-scenario break-even ages
- Inputs: PIA, birth year (for FRA), life expectancy to project through, COLA rate
- Output: 9 scenarios, each with `cumulativeByAge` array and `breakEvenVs` pairs
- Year-dependent: no (age-based projection, COLA compounds from claim age)

**`cumulativeChartData(scenarios: [SSClaimingScenario], maxAge: Int = 95) -> [SSCumulativeChartPoint]`**
- Purpose: Flatten scenario cumulative data into chart-ready points
- Output: flat array of `(age, cumulativeAmount, scenarioLabel)` points for charting

**`breakEvenComparisons(scenarios: [SSClaimingScenario], lifeExpectancy: Int, fraAge: Int = 67) -> [SSBreakEvenComparison]`**
- Purpose: Generate the key break-even pairs: 62 vs FRA, 62 vs 70, FRA vs 70
- Output: array of `SSBreakEvenComparison` with break-even age and advantage-at-life-expectancy

---

### SSA Statement Validation

**`piaFromEstimates(benefitAtFRA: Double) -> Double`**
- Purpose: Trivial — the benefit at FRA IS the PIA (identity function, exists for clarity)

**`benefitFromEstimates(at claimingAge: Int, claimingMonth: Int = 0, benefitAt62: Double, benefitAtFRA: Double, benefitAt70: Double, birthYear: Int) -> Double`**
- Purpose: Calculate benefit at any age using SSA statement estimates for validation/cross-check

---

### Spousal Benefit Methods

**`maxSpousalBenefit(workerPIA: Double) -> Double`**
- Purpose: 50% of worker's PIA — the maximum spousal benefit at FRA

**`spousalBenefit(workerPIA: Double, spouseOwnPIA: Double, spouseClaimingAge: Int, spouseClaimingMonth: Int = 0, spouseBirthYear: Int) -> Double`**
- Purpose: Full deemed-filing spousal benefit calculation: own-reduced-retirement + reduced-excess-spousal (if positive)
- Inputs: worker's PIA, spouse's own PIA, spouse's claiming age/month, spouse's birth year
- Output: combined monthly benefit under deemed filing rules
- Note: models the post-2015 Bipartisan Budget Act rules. No DRCs apply to spousal component.

---

### Effective Monthly Benefit (Year-Aware, Spousal-Aware)

**`effectiveMonthlyBenefit(personPIA, personBirthYear, personClaimingAge, personClaimingMonth, personIsAlreadyClaiming, personCurrentBenefit, spousePIA, spouseBirthYear, spouseClaimingAge, spouseIsAlreadyClaiming, forYear: Int) -> EffectiveBenefitResult`**
- Purpose: Compute the correct monthly SS benefit for one person in a couple for a specific **calendar year**, accounting for: whether the person has reached claiming age, whether the other spouse has filed (spousal top-up eligibility), and already-claiming passthrough
- Inputs: full parameter set for both person and spouse, plus `forYear`
- Output: `EffectiveBenefitResult` with `monthly`, `isCollecting`, `ownMonthly`, `spousalTopUp`, `includesSpousalTopUp`
- **Year-dependent: yes** — age is computed as `forYear - birthYear`

**`effectiveMonthlyBenefitSingle(personPIA, personBirthYear, personClaimingAge, personClaimingMonth, personIsAlreadyClaiming, personCurrentBenefit, forYear: Int) -> EffectiveBenefitResult`**
- Purpose: Simplified version for single filers — own-record only, age-gated by `forYear`
- **Year-dependent: yes**

**`EffectiveBenefitResult` (nested struct)**
- Fields: `monthly`, `isCollecting`, `ownMonthly`, `spousalTopUp`, `includesSpousalTopUp`

---

### Survivor Benefit Methods

**`survivorBenefit(survivorOwnBenefit: Double, deceasedActualBenefit: Double, deceasedPIA: Double? = nil, survivorAge: Int? = nil, survivorFRAYears: Int? = nil) -> Double`**
- Purpose: Survivor benefit with RIB-LIM (if deceased claimed early, survivor gets max of actual or 82.5% of PIA) and survivor age reduction (linear approximation from 71.5% at 60 to 100% at FRA)
- Output: monthly survivor benefit (max of own or deceased's survivor amount)
- Note: survivor age reduction is an approximation (uses years, not months)

**`survivorScenarios(primaryBenefit: SSBenefitEstimate, primaryBirthYear: Int, spouseBenefit: SSBenefitEstimate, spouseBirthYear: Int) -> [SSSurvivorScenario]`**
- Purpose: Generate two `SSSurvivorScenario` entries (primary dies first; spouse dies first), showing household income drop and percent reduction
- Inputs: full `SSBenefitEstimate` objects for each spouse
- Output: 2-element array of `SSSurvivorScenario`

---

### Couples Strategy Matrix

**`couplesMatrix(primaryPIA, primaryBirthYear, primaryLifeExpectancy, spousePIA, spouseBirthYear, spouseLifeExpectancy, colaRate, discountRate, primaryCurrentAge, spouseCurrentAge) -> [SSCouplesMatrixCell]`**
- Purpose: Build the full n×m matrix of combined lifetime benefits for every feasible claiming-age combination (62–70 for each spouse, filtered to ages >= current age)
- Output: `[SSCouplesMatrixCell]`, each cell with `combinedLifetimeBenefit`, per-person monthlies (own and with spousal top-up), survivor amounts, and `isHighestLifetime` flag
- Note: excludes past claiming ages to show only actionable strategies

**`couplesLifetimeBenefit(primaryMonthly, primaryClaimAge, primaryLifeExp, spouseMonthly, spouseClaimAge, spouseLifeExp, primaryOwnMonthly, spouseOwnMonthly, survivorIfPrimaryDies, survivorIfSpouseDies, colaRate, discountRate) -> Double`**
- Purpose: Compute household lifetime benefit across both-alive and survivor phases, weighting both death orderings 50/50. Supports optional PV discounting.
- Note: gap years before the other spouse files use own-only benefit (no spousal top-up during gap)

**`couplesTopStrategy(matrix: [SSCouplesMatrixCell], primaryPIA: Double, spousePIA: Double) -> SSCouplesTopStrategy?`**
- Purpose: Extract the best strategy cell and generate a plain-English rationale string

---

### AIME/PIA from Earnings History

**Static data tables (not methods):**
- `awiTable: [Int: Double]` — National Average Wage Index 1951–2023
- `taxableMaxTable: [Int: Double]` — SS taxable maximum 1951–2026

**`piaBendPoints(yearTurning62: Int) -> (bp1: Double, bp2: Double)`**
- Purpose: Return PIA bend points for the year the worker turns 62 (table covers 1979–2026, then holds at 2026)
- Year-dependent: yes (bend points change each year)

**`calculatePIA(records: [SSEarningsRecord], birthYear: Int, futureEarningsPerYear: Double = 0, futureWorkYears: Int = 0) -> SSPIAResult?`**
- Purpose: Full AIME/PIA calculation from earnings history: index each year's earnings using AWI, select top 35, compute AIME, apply bend-point formula, round to nearest dime
- Output: `SSPIAResult` with `aime`, `pia`, indexed earnings detail, bend points, zero-padded year count
- Note: uses `Calendar.current` internally to get the current year for future earnings projection

**`piaFromAIME(aime: Int, bendPoint1: Double, bendPoint2: Double) -> Double`**
- Purpose: Apply the three-tier PIA formula (90% / 32% / 15%) to an AIME value

---

### Earnings History Parsers

**`parseEarningsHistory(_ text: String) -> Result<SSParseResult, SSParseError>`**
- Purpose: Parse pasted SSA statement text into `[SSEarningsRecord]`. Handles single years, year ranges (e.g. "1966-1980 $48,273"), "not yet recorded" lines, and two-column format
- Output: `SSParseResult` with records, skipped lines, zero-earning years, and capped years

**`parseEarningsXML(_ data: Data) -> Result<SSXMLParseResult, SSParseError>`**
- Purpose: Parse SSA's XML statement file (osss:OnlineSocialSecurityStatementData format); extracts FicaEarnings per year and optionally DateOfBirth
- Output: `SSXMLParseResult` wrapping `SSParseResult` plus optional `dateOfBirth: Date?`

---

### Formatting Helpers

**`birthYear(from date: Date) -> Int`** — extract birth year from Date

**`currentAge(from birthDate: Date) -> Int`** — current age in whole years

**`formatCurrency(_ amount: Double) -> String`** — format as currency with no decimals

**`formatLargeCurrency(_ amount: Double) -> String`** — compact format ($1.2M, $350K)

---

## SS-related fields on DataManager

SS state is owned by a `SocialSecurityManager` sub-object and forwarded via computed properties on `DataManager`. Source: `RetireSmartIRA/DataManager.swift` and `RetireSmartIRA/SocialSecurityManager.swift`.

### SocialSecurityManager (source of truth, `RetireSmartIRA/SocialSecurityManager.swift`)

| Field | Type | Description |
|---|---|---|
| `primarySSBenefit` | `@Published SSBenefitEstimate?` | Primary user's SSA statement estimates + claiming plan |
| `spouseSSBenefit` | `@Published SSBenefitEstimate?` | Spouse's SSA statement estimates + claiming plan |
| `primaryEarningsHistory` | `@Published SSEarningsHistory?` | Primary user's raw earnings records for AIME/PIA |
| `spouseEarningsHistory` | `@Published SSEarningsHistory?` | Spouse's raw earnings records for AIME/PIA |
| `ssWhatIfParams` | `@Published SSWhatIfParameters` | Life expectancy × 2, COLA rate, discount rate |
| `ssAutoSync` | `@Published Bool` | Whether to auto-sync SS benefit into IncomeSource list |

### Forwarded computed properties on DataManager (`DataManager.swift` lines 230–252)

All six fields above are exposed on `DataManager` as get/set computed properties forwarding to `socialSecurity.*`.

### SSBenefitEstimate fields (per owner, `SSModels.swift:13–78`)

| Field | Type | Notes |
|---|---|---|
| `benefitAt62` | `Double` | Monthly benefit at 62 (from SSA statement) |
| `benefitAtFRA` | `Double` | Monthly benefit at FRA — this is the PIA |
| `benefitAt70` | `Double` | Monthly benefit at 70 (from SSA statement) |
| `plannedClaimingAge` | `Int` | 62–70 |
| `plannedClaimingMonth` | `Int` | 0–11 |
| `isAlreadyClaiming` | `Bool` | True if currently receiving SS |
| `currentBenefit` | `Double` | Monthly amount if already claiming |

### SSWhatIfParameters fields (`SSModels.swift:103–116`)

| Field | Type | Default |
|---|---|---|
| `primaryLifeExpectancy` | `Int` | 85 |
| `spouseLifeExpectancy` | `Int` | 87 |
| `colaRate` | `Double` | 2.5% |
| `discountRate` | `Double` | 0 (nominal, no PV discounting) |

### Derived computed properties on DataManager (`DataManager.swift`)

| Property | Line approx. | Purpose |
|---|---|---|
| `primaryFRA` | (bridge method) | Calls `SSCalculationEngine.fullRetirementAge(birthYear:)` |
| `spouseFRA` | (bridge method) | Same for spouse |
| `scenarioTaxableSocialSecurity` | ~1055 | Delegates to `TaxCalculationEngine.calculateTaxableSocialSecurity` |
| `totalSocialSecurityBenefits` | ~1061 | Sum of all IncomeSource entries with type `.socialSecurity` |
| `socialSecurityTaxablePercent` | ~1064 | `scenarioTaxableSocialSecurity / totalSocialSecurityBenefits * 100` |

---

## How SS calculations are currently invoked

### Call site 1: Auto-sync to income sources (`DataManager+SocialSecurity.swift`, `syncSSToIncomeSources`)

This is the bridge between the SS Planner and the tax calculation engine:

1. User changes a claiming age or benefit estimate in the SS Planner UI
2. If `ssAutoSync == true`, `syncSSToIncomeSources()` is called
3. For each active owner, `ssEffectiveMonthlyBenefit(for: owner)` is called, which calls:
   - `SSCalculationEngine.effectiveMonthlyBenefit(...)` (couples) or `effectiveMonthlyBenefitSingle(...)`, passing `forYear: currentYear`
4. Result `monthly * 12` is written to the matching `IncomeSource` entry (or appended if new)
5. The IncomeSource list is what feeds `TaxCalculationEngine.calculateTaxableSocialSecurity(...)`

**Key implication:** The 1.9 engine is year-point (single `currentYear`). SS benefit flows through as a static annual amount in the IncomeSource list, not as a year-by-year stream.

### Call site 2: SS Planner feature (`ssClaimingScenarios`, `ssBreakEvenComparisons`, `ssCouplesMatrix`)

These are called by the SS Planner views directly:

1. View calls `dataManager.ssClaimingScenarios(for: .primary)`
2. `DataManager+SocialSecurity.swift` pulls `primarySSBenefit.benefitAtFRA`, `birthYear`, and `ssWhatIfParams`
3. Passes them to `SSCalculationEngine.claimingScenarios(pia:birthYear:lifeExpectancy:colaRate:)`
4. Returns `[SSClaimingScenario]` consumed by the chart/comparison views

This path is read-only / display-only and does not affect tax calculations.

### Provisional income / SS taxation (`TaxCalculationEngine.swift:478–504`)

`TaxCalculationEngine.calculateTaxableSocialSecurity(filingStatus:additionalIncome:incomeSources:)` implements the provisional-income formula:

- Sums all `IncomeSource` entries with type `.socialSecurity` → gross SS
- Sums all other income sources + additionalIncome (scenario amount) → other income
- Combined income = other income + (SS × 0.5)
- Threshold 1 (single/MFJ), Threshold 2 (single/MFJ) read from a `config` object
- Returns taxable SS: 0%, 50%, or up to 85% of gross SS depending on brackets

**Note:** This method is on `TaxCalculationEngine`, not `SSCalculationEngine`. SS taxation is split across two engines.

---

## What the 2.0 multi-year engine will need (questions, not answers)

1. How should SS income be projected year-by-year given a claim age and COLA rate? The current `effectiveMonthlyBenefit(forYear:)` method is callable per-year, but it returns the benefit at the **original** claiming age, not COLA-adjusted. Where does COLA compounding belong in the per-year projection?

2. For a year before the planned claiming age, the correct result is $0 (not yet collecting). The `effectiveMonthlyBenefit(forYear:)` method already handles this via age-gating — but it uses `forYear - birthYear` as age, which is a whole-year approximation. Is month-precision needed?

3. The provisional-income SS taxation formula (`TaxCalculationEngine.calculateTaxableSocialSecurity`) uses thresholds from a `config` object. Are those thresholds inflation-adjusted year-by-year in the 2.0 engine, or held constant at today's values?

4. The `ssWhatIfParams.colaRate` is a single global assumption used everywhere. Does the 2.0 engine need per-scenario COLA sensitivity (e.g. 0%, 2.5%, and 3% as columns)?

5. Survivor benefit calculation exists and is wired into `couplesMatrix`, but it is not currently fed into any year-by-year tax projection. How does a widow/widower scenario affect the per-year SS income stream and filing status change (MFJ → Single) for tax purposes?

6. The `calculatePIA` method calls `Calendar.current.component(.year, from: Date())` internally. Is PIA calculation expected to be called in the multi-year engine, or does the 2.0 engine always take `benefitAtFRA` (the PIA) as an input?

7. Is the spousal top-up correctly modeled for the **gap year** where one spouse has claimed and the other has not yet? The current engine handles this, but only in the `effectiveMonthlyBenefit(forYear:)` path — not in the `claimingScenarios` single-person path. Does the 2.0 engine need a unified couples projection that stays aware of the gap?

8. The `taxableMaxTable` hardcodes SS taxable maximum through 2026. For long-horizon projections (e.g. 20+ years), what assumption should be used for years beyond the table?
