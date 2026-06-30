# V2.0 Taxable Accounts — Design Spec

**Date:** 2026-06-30
**Branch:** `2.0/heir-objective` (worktree `.worktrees/2.0-reconcile-engine`)
**Status:** Design approved (brainstorm). Next step: implementation plan via writing-plans.

## Problem

The Multi-Year Roth conversion planner depends heavily on where the money to pay
conversion taxes comes from, what tax that funding creates, and what income the
household's non-retirement assets throw off every year. Today the engine models
none of that as a real account:

- There is **no taxable/brokerage account type** in the Accounts tab. `AccountType`
  ([AccountModels.swift:51](../../../RetireSmartIRA/AccountModels.swift)) has only
  IRA/401(k) traditional/Roth/inherited cases.
- Taxable money is a **single scalar**, `MultiYearAssumptions.currentTaxableBalance`,
  defaulting to **$0**, editable only in the Multi-Year assumptions strip
  ([MultiYearPlanView.swift:83](../../../RetireSmartIRA/MultiYearPlanView.swift)).
- That balance is the engine's source for paying conversion taxes
  ([ProjectionEngine.swift:615](../../../RetireSmartIRA/ProjectionEngine.swift),
  `.taxableThenGrossUp`), but it grows **untaxed** (no tax drag,
  [ProjectionEngine.swift:425](../../../RetireSmartIRA/ProjectionEngine.swift)) and
  its sales realize **zero gains**
  ([ProjectionEngine.swift:253](../../../RetireSmartIRA/ProjectionEngine.swift)).
- Investment income (dividends, interest, muni, cap gains) is entered as separate
  flat `IncomeSource` line items, disconnected from any balance. Muni (tax-exempt)
  interest is modeled as **0 in MAGI**
  ([ProjectionEngine.swift:466](../../../RetireSmartIRA/ProjectionEngine.swift)).

Net effect on credibility: when a taxable balance is entered it makes conversions
look too cheap (no drag, free sales); when it is missing (the default) the engine
funds conversion taxes by grossing up IRA withdrawals, distorting the ladder the
other way. For a credibility-first product this is the gap a serious competitor
(Pralana, ProjectionLab, Boldin-in-its-full-planner) would not cut. It is the
"credibility floor" the 2026-06-24 competitive four-way already named.

## Goal and non-goals

**Goal:** the minimum first-class taxable-account model that (a) the author trusts
for his own planning, (b) users trust both up front and after going deep, and
(c) bridges cleanly to V2.1 with no tear-out.

**Non-goals for V2.0:** lot-level basis, ST/LT holding periods, specific-lot
selection, withdrawal-order *optimization*, single-year views consuming these
accounts, time-varying income streams. All deferred with bridges in place
(see "V2.0 / V2.1 line").

## Decisions locked during brainstorm

1. **Approach B — per-account taxable buckets in the engine** (not aggregate-at-boundary).
   Only this honors per-account returns, models a walled trust correctly, fixes
   tax-drag and muni-MAGI for real, and gives V2.1 the per-account structure
   withdrawal-order needs.
2. **Cap gains on sale: blended-basis approximation.** One `costBasis` per account;
   a sale realizes a proportional gain taxed at the LTCG schedule. No lots, no
   holding periods. Field upgrades to lots in V2.1.
3. **Source-of-truth: multi-year only, single source by design.** Accounts generate
   investment income and feed only the Multi-Year engine in V2.0. Single-year views
   keep their manual income entries for now. When accounts exist, the Multi-Year
   adapter derives investment income from them (and discloses it), so no double-count
   inside the planner. V2.1 extends accounts to single-year views and pre-populates
   the Income tab from account projections for user validation.
4. **Income character: per-account yield breakdown** (qualified dividend / ordinary /
   tax-exempt / long-term gain distribution).

## Data model

New first-class `TaxableAccount`, stored in `DataManager.taxableAccounts: [TaxableAccount]`
beside `iraAccounts`, entered in the Accounts tab. Separate from `IRAAccount` (no
RMD/inheritance fields).

```swift
struct TaxableAccount: Identifiable, Codable {
    let id: UUID
    var name: String
    var owner: Owner
    var institution: String
    var category: TaxableAccountCategory   // UI/organization only; no engine effect in V2.0

    var balance: Double
    var costBasis: Double            // unrealizedGain = balance - costBasis; "Confirm basis" badge until set
    var protectedAmount: Double      // reserve floor; availableBalance = max(0, balance - protectedAmount)

    var expectedAppreciationRate: Double   // annual price growth, EXCLUDING income yield

    // income yield as % of balance, by tax character:
    var qualifiedDividendYield: Double     // preferential rate
    var ordinaryIncomeYield: Double        // non-qual dividends + interest, ordinary rate
    var taxExemptYield: Double             // muni: in MAGI, out of taxable income
    var realizedLongTermGainYield: Double  // fund cap-gain distributions; preferential bucket

    var availableForExpenses: Bool         // UI: "Can be used for living expenses"
    var availableForConversionTaxes: Bool  // UI: "Can be used to pay Roth conversion taxes"
    var fundingPriority: Int?              // optional; lower used first; nil -> highest-basis-first
}

enum TaxableAccountCategory: String, Codable, CaseIterable {
    case brokerage, cashMoneyMarket, dividendFund, muniBond, trustRestricted, otherTaxable
}
```

Total expected return is `expectedAppreciationRate` + the four yields, so there is no
redundant total-return field.

The four examples map cleanly:
- **Brokerage:** mixed yields, both flags true.
- **Grandchild revocable trust:** yields set, both flags false (grantor-taxed to owner,
  principal and cash walled off). `category = trustRestricted`. Availability is a
  user planning choice, not a legal determination.
- **Tim's preferred-dividend fund:** high `qualifiedDividendYield`. `category = dividendFund`.
- **Muni ladder:** `taxExemptYield`, available-for-taxes per the user's choice.
  `category = muniBond`.

**Migration:** the legacy `currentTaxableBalance` scalar is superseded. On first load it
seeds one "Brokerage" `TaxableAccount` (both flags true, zero yields). Its `costBasis`
defaults to **balance** (zero gain) to preserve today's behavior, paired with a visible
**"Confirm basis"** badge so the optimistic default never hides silently. HSA stays its
own scalar in V2.0.

## Engine changes (ProjectionEngine)

The single `taxable` scalar becomes an array of mutable account states (balance + basis).
The per-year loop gains a real cash-and-tax waterfall, replacing the current Steps 1, 4,
5, 6, 7 behavior for taxable money.

Per-year sequence:

1. **Income generation** on each account's start-of-year balance:
   - `ordinaryIncomeYield` -> ordinary AGI
   - `qualifiedDividendYield` + `realizedLongTermGainYield` -> preferential bucket
   - `taxExemptYield` -> MAGI add-back only (muni-MAGI fix; replaces hardcoded 0)
2. **Spendable cash** = SS + pension + wages + RMDs + income from **available** accounts.
   A **walled** account's income is taxed to the owner but reinvested into that account
   (basis steps up by the reinvested, already-taxed amount) and is never spendable.
3. **Fund expenses, then taxes** by selling from available accounts respecting
   `protectedAmount`, in funding order (explicit `fundingPriority` first, else
   highest-basis-first), then the existing traditional/Roth ordering.
4. **Blended-basis realized gains** on every sale:
   `realizedGain = sale * (balance - costBasis) / balance`, added to the preferential
   bucket; basis reduced proportionally. Selling to pay tax realizes gains that create
   more tax, so this folds into the **same 3-iteration fixed point** the engine already
   runs for the traditional gross-up
   ([ProjectionEngine.swift:633](../../../RetireSmartIRA/ProjectionEngine.swift)).
5. **Growth**: each account grows at its own `expectedAppreciationRate` (basis unchanged,
   unrealized gain compounds). Leftover spendable surplus reinvests into available accounts.

**AGI/MAGI** then picks up account ordinary income, account preferential income + realized
sale gains, and muni in the add-back. The **optimizer objective is unchanged**; it simply
now sees realistic (higher) conversion-year AGI plus hard liquidity limits, which is what
pulls recommendations back from over-aggressive.

**Adapter (`MultiYearInputAdapter`):** `MultiYearStaticInputs` gains a pure-value
`[TaxableAccountInput]`. When non-empty, the adapter derives investment income from
accounts and stops pulling dividend/interest/qualified-dividend/LTCG/tax-exempt from
`IncomeSource` (no double-count); non-investment "other" income (state refund, military
retirement, other) still flows.

**Backward compatibility:** if `taxableAccounts` is empty, the adapter synthesizes one
account from `currentTaxableBalance` (basis = balance, both flags true, zero yields),
reproducing today's behavior so the existing ~1,100 tests stay green.

## UI changes

**Accounts tab** gains a **"Taxable Accounts"** section beside the IRA list, reusing the
existing row/editor pattern. Helper/empty text: "Brokerage accounts, cash, muni ladders,
taxable trusts, and other non-retirement assets." Progressive disclosure:

- **Basic (always visible):** name, owner, balance, **cost basis / amount invested**
  (helper: "Used to estimate capital gains if this account is sold to pay expenses or
  conversion taxes"; **"Confirm basis"** badge until set), **expected price growth,
  excluding income yield** (helper: "Dividends, interest, and tax-exempt income are
  entered below"; pre-filled from the plan's global growth rate).
- **Advanced (collapsible, sane defaults):** yield breakdown (the four slices, default 0),
  `protectedAmount` (default 0), the two availability toggles in plain English (both
  default on), optional `fundingPriority`, and `category`.

**Multi-Year tab:** the editable taxable-balance field in the assumptions strip becomes a
**read-only roll-up**: "Taxable accounts: $X across N accounts" (deep-links to the Accounts
section) or "Taxable accounts: None entered." HSA stays as-is.

**Credibility touches:**
- **Empty-state warning** when conversions are recommended but no taxable account exists:
  "No taxable account entered. This plan assumes Roth conversion taxes must be paid from
  additional IRA withdrawals, which may materially change the conversion ladder."
- **"Plan inputs / not yet modeled"** line near the results, plain language. Visible text:
  "Taxable-account sales use an average cost-basis estimate and a default funding order.
  Lot-level tax selection, short-term holding periods, and single-year income
  reconciliation are planned future enhancements." Technical detail (blended basis) lives
  in a popover.

## V2.0 / V2.1 line

**In V2.0:** everything above.

**Deferred, bridge already in place:**
- Lot-level basis, ST/LT holding periods, specific-lot selection -> `costBasis` upgrades to
  lots; the sale-order function is already an isolated seam.
- Withdrawal-order **optimization** across accounts -> V2.0 uses default order +
  `fundingPriority`; per-account structure already present, so it is a hook not a rebuild.
- Single-year views reading taxable accounts -> accounts already the single source; V2.1
  derives single-year investment income from them and pre-populates the Income tab for user
  validation.
- Category-driven smart toggle defaults (trust auto-walled) -> `category` captured now.
- Time-varying income streams (consulting that ends, pension that starts) -> separate V2.1
  item, not taxable-account-specific.
- Short-term gain distributions, return-of-capital, in-state vs out-of-state muni -> later
  refinements on the same slices.

## Testing

Built test-first. Suite must stay green (~1,100 tests); backward-compat is a tested guarantee.

**Pure-model:** `TaxableAccount` Codable round-trip; `availableBalance = max(0, balance -
protectedAmount)`; gain-fraction math.

**ProjectionEngine (core):**
- Two accounts at different `expectedAppreciationRate` diverge correctly (per-account growth).
- Income by character: ordinary slice -> ordinary AGI; qualified-dividend + LT-gain slices ->
  preferential; **muni slice raises MAGI but not taxable income** (dedicated regression).
- Walled account: income taxed in AGI, not spendable, reinvested; principal never sold for
  taxes/expenses.
- Blended-basis sales: sale realizes `sale * gainFraction` at LTCG; basis drops
  proportionally; gross-up fixed point still converges when sales create their own gain tax.
- `protectedAmount`: engine never draws an account below its reserve.
- Funding priority: explicit order respected; unset falls back to highest-basis-first.
- **Empty `taxableAccounts` reproduces today's behavior** (regression guard).

**Adapter:** account-derived investment income supersedes manual `IncomeSource` investment
income (no double-count); non-investment "other" income still flows; legacy
`currentTaxableBalance` migrates to one account (basis = balance, both flags on).

**Direction-of-effect:** a scenario where tax-drag + realized gains make recommended
conversions **less aggressive** than the no-taxable-modeling baseline, proving the
credibility fix moves the answer as expected.

## Open question to resolve in planning

The basis-defaults-to-balance migration is optimistic by construction. The "Confirm basis"
badge mitigates it, but decide during planning whether the empty-state/disclosure should
also nudge migrated users specifically (not just new accounts).

## Related, separate workstream (not in this spec)

Positioning/language guardrails (Explorer-vs-Planner framing, "under these assumptions"
phrasing, softening "Recommended") were discussed and are real, but are a separable
copy/positioning task tracked outside this engine spec.
