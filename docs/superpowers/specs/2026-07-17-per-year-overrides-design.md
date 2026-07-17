# Per-Year Input Overrides — Design

**Date:** 2026-07-17
**Status:** Design (approved in brainstorm; pending spec review)
**Ships in:** 2.1.2 — **expenses only** (see Scope)
**Origin:** Alan's 2nd-round feedback — *"It would be fantastic if I can put in numbers for future years and project income, taxes, RMD… The numbers I am putting in are for 2026. I would love to put in numbers for 2027 and beyond."*

---

## 1. Problem & framing

The Multi-Year plan projects every future year forward from the user's Year-1 inputs. Users want to enter their own numbers for specific future years and have the plan recalculate around them.

Alan's request decomposes into three parts:

1. **See** future-year projections (income, taxes, RMD). **Already exists** — the Multi-Year tab renders these per year across the whole horizon. This is a discoverability matter, not a missing feature.
2. **Enter** future expenses. Engine already supports a per-year expense map; only the editing UI is missing.
3. **Enter** future income (wages, pension, other). **Does not exist** — no per-year income model. This is the larger, still-required piece.

**This release addresses part 2 (per-year expense entry), with the full model designed so income slots in later.** The per-year edit affordances make the projection rows more interactive, but 2.1.2 adds **no dedicated discoverability feature** for part 1 — surfacing "the tab already projects your future years" (onboarding / a nudge) remains a **separate open item**. **Future-year income entry (part 3) remains necessary to satisfy Alan's complete request** and is called out again in Scope.

The feature also lays groundwork for Fred's "recommend / commit / explain" workflow, without conflating planning overrides with committed actuals (see Provenance).

---

## 2. Overridable = inputs, never computed outputs

A first-class principle: users override **inputs**, and the engine keeps computing **outputs** from them.

- **Overridable inputs:** living expenses (2.1.2); later — income by type (wages, pension, other-ordinary, preferential, per spouse), discretionary withdrawals above RMD, QCD, charitable.
- **Never overridable (computed):** tax, IRMAA, AGI, account balances, and the **RMD amount**.
  - Nuance: RMD is a computed *minimum*. A user may take *more* via a discretionary-withdrawal override (a future input field), but can never lower the required RMD.

---

## 3. Data model

Replace the expense-only map with a generalized per-year override structure. Each overridable field distinguishes a **recurring baseline change** from a **one-time adjustment** — the two are orthogonal and can coexist in the same year.

The recurring-vs-one-time distinction *is* the scope: a `recurringLevel` is "this year and after," a `oneTimeAmount` is "this year only." No separate scope enum is needed.

```swift
struct FieldOverride: Codable, Equatable, Sendable {
    /// Step-change to the recurring baseline for this field, effective THIS year onward
    /// (CPI-grown from this year until a later recurring anchor supersedes it). nil = unchanged.
    var recurringLevel: Double?
    /// One-time adjustment for THIS year only, added on top of the recurring baseline. nil = none.
    var oneTimeAmount: Double?
}

struct YearOverride: Codable, Equatable, Sendable {
    var livingExpenses: FieldOverride?
    // v2.2: var wages: FieldOverride?; var pension: FieldOverride?; var extraWithdrawal: FieldOverride?; …
}

// MultiYearAssumptions:
//   was:  var perYearExpenseOverrides: [Int: Double]
//   now:  var perYearOverrides: [Int: YearOverride]
```

Per-**field** override structs (not one scope per year) so a permanent expense shift and a one-time income event can coexist once income lands.

### Migration (behavior-preserving)

**Critical:** the legacy value is an *absolute total* for that year (`expense(Y) = legacy`), while the new `oneTimeAmount` is *additive* (`expense(Y) = recurringBaseline(Y) + oneTime(Y)`). Migrating the legacy value directly into `oneTimeAmount` would **double-count** the baseline (a $120k legacy over a $100k baseline would resolve to $220k).

The migration must convert the absolute legacy total into the equivalent additive delta:

```
oneTimeAmount(Y) = legacyValue(Y) − originalBaseline(Y)
originalBaseline(Y) = baselineAnnualExpenses × (1 + cpiRate)^(Y − baseYear)
```

Example: legacy $120k over an original baseline of $100k → `oneTimeAmount = $20k` → resolves to `$100k + $20k = $120k`. Behavior preserved. Legacy overrides carry **no** `recurringLevel` (they were single-year spots), so they never re-anchor the baseline.

**Where it runs:** computing `originalBaseline(Y)` needs `baselineAnnualExpenses`, `cpiRate`, **and** `baseYear`. `MultiYearAssumptions` (home of the override map) has the first two but not `baseYear` (it comes from the inputs / plan base year). Migration therefore runs at a **load-time upgrade step that has access to all three**, not as a bare `Codable` decode. Until that step runs, a decoded plan is not yet in the new representation — the upgrade step is the single point that rewrites legacy → new.

**Test with materially different values** (legacy ≫ baseline, legacy ≪ baseline, and multiple legacy years at once) — a round-trip test alone would not catch the double-count.

### Persistence version

- The **new app reads legacy plans** (via the upgrade step above) and reads its own new format.
- Migration is **one-way**: once a plan is saved in the new `perYearOverrides` shape, an **older app version can no longer read the per-year overrides** (its decoder expects `perYearExpenseOverrides`). This is acceptable for a single-user app that updates in place, but is stated explicitly so it's a conscious choice.
- Add a **schema version marker** to the persisted plan (e.g. `perYearOverridesSchema = 1`) so future migrations can branch on version rather than sniffing keys, and so an older app can at least detect (and safely ignore) an unreadable newer block instead of failing to load the whole plan.
- Decode is defensive: a missing/legacy key path yields no overrides (never a decode failure), matching the existing `decodeIfPresent` pattern used elsewhere in the models.

---

## 4. Engine — expense resolution

Replaces the single lookup at `ProjectionEngine.swift:490`. For year `Y`:

```
recurringBaseline(Y) =
    let anchors = { k : perYearOverrides[k].livingExpenses.recurringLevel != nil, k <= Y }
    if anchors nonempty:
        let a = max(anchors);  value(a) * (1 + cpi)^(Y - a)
    else:
        baselineAnnualExpenses * (1 + cpi)^(Y - baseYear)

oneTime(Y) = perYearOverrides[Y].livingExpenses.oneTimeAmount ?? 0    // may be negative

expense(Y) = max(0, recurringBaseline(Y) + oneTime(Y))               // floored at zero
```

A `oneTimeAmount` may be **negative** (e.g. an unusually cheap year); the resolved expense is floored at **zero** so a large negative adjustment can never produce a negative expense. All amounts are **nominal** (actual dollars in year Y), consistent with the existing engine (the override at line 491 already replaces the CPI-grown nominal figure).

### Worked precedence example

- **2028** `recurringLevel = $90k` → baseline re-anchors; 2028, 2029, … grow from $90k at CPI.
- **2030** `oneTimeAmount = +$40k` → 2030 = (2028 anchor grown to 2030) + $40k.
- **2031** → resumes the 2028 anchor's CPI path; no residue from the 2030 spike.
- **2032** `recurringLevel = $75k` → new anchor; 2032 onward grows from $75k.

---

## 5. Downstream effects (verified, stated carefully)

Setting an override causes the plan to **recalculate**. Changing a year's expense changes its **funding shortfall** (`ProjectionEngine.swift:527`), which **ordinarily** changes auto-funded withdrawals/deposits and therefore downstream balances.

It is **not** an absolute guarantee — an already-unfunded expense, insufficient assets, plan constraints, or rounding can leave a balance unchanged. Effects are therefore asserted with **controlled profiles**, not assumed:

- The **tax** effect is *conditional on funding*: a shortfall covered from the **traditional IRA** raises ordinary income and tax; from **taxable** it realizes LTCG; and it is **unchanged** when passive income (SS / pension / RMD / account income) already covers the expense.

---

## 6. UI

The Multi-Year projection already lists every year (the ladder / projection rows).

- **Explicit edit affordance** on each year row (an edit icon / "Customize" control) — never a hidden tap, which would repeat the discoverability problem this feature partly addresses.
- A row shows a **badge only when it has a real override** (see Empty records below) — not merely because a dictionary entry exists.
- The control opens a **`YearDetailEditor`** sheet for that year. For living expenses it shows:
  - the **effective projected value, read-only**, as reference — defined as the baseline **incorporating earlier recurring anchors but excluding this year's own one-time adjustment** (the "what this year would be without a one-time change" figure), labeled with the year and a today's-dollars caption for anchoring;
  - two **clearly-labeled** override inputs, e.g. **"Ongoing annual expenses beginning in {year}"** (the recurring level) and **"One-time adjustment in {year} (+/−)"** (the one-time amount) — so a one-time entry is never misread as "the total for the year";
  - a note that a **negative** one-time adjustment is allowed (the resolved expense is floored at $0);
  - a **Clear** action.

**Edit-vs-new state.** The override inputs are **empty only when no override exists** for that year. Reopening a customized year **pre-populates the saved recurring level and one-time amount** so the user edits their real values, not a blank form.

**No accidental overrides.** Opening the sheet and saving **without entering anything** produces **no** override. Only an explicit entry creates one.

**Empty records.** A `FieldOverride` with neither `recurringLevel` nor `oneTimeAmount` is not an override; empty `FieldOverride`s, empty `YearOverride`s, and their dictionary entries are **pruned on save and on clear**, so `perYearOverrides` never carries dead keys and the badge reflects **actual** override values.

The sheet is structured to hold future input fields (income, withdrawals) without restructuring.

---

## 7. Provenance (designed, not built)

All 2.1.2 overrides are **planning** overrides. The model stays open to a future `provenance` axis — *projected → planned-override → actual-committed* — for Fred's "commit this year's actuals" workflow. 2.1.2 does **not** build actuals and does **not** conflate them with planning overrides.

---

## 8. Scope (this is a larger slice than "expose an existing capability")

Adding the recurring / one-time model is **new projection semantics, new persistence shape, a migration, and broader testing** — not merely surfacing `perYearExpenseOverrides`. It is still appropriate for 2.1.2, but the added surface is acknowledged.

**In scope (2.1.2):** the generalized data model + migration; the expense resolver (recurring anchors + one-time spikes); the `YearDetailEditor` with the expense fields, badge, read-only reference, and clear; persistence; tests.

**Out of scope (v2.2):** per-year **income** entry (required for Alan's full request), discretionary-withdrawal / QCD / charitable overrides, the provenance/actuals axis, and any "recommend / commit / explain" round-trip with the Scenarios tab.

---

## 9. Testing

**Migration (the critical case):**
- Legacy `[Int: Double]` → additive delta via `legacy − originalBaseline(Y)`, verified with **materially different** values: legacy ≫ baseline (double-count would be caught), legacy ≪ baseline, and a legacy value equal to the baseline (→ `oneTimeAmount == 0`).
- **Multiple** legacy years migrate together, each preserved.
- The migrated plan's **computed expenses equal the pre-migration computed expenses** (behavior-preserving assertion on the resolved values, not just the stored representation).
- New-model encode/decode round-trip; defensive decode of a plan with no override block.

**Resolution semantics:**
- **One-time spike** changes that year only; neighbors stay on the prevailing path.
- **Recurring anchor** re-anchors the CPI baseline from its year until a later anchor takes over; the §4 worked example is pinned end-to-end.
- **Coexistence:** a recurring anchor and a one-time amount in the same year resolve to their sum.

**Validation / edge cases:**
- **Zero** values (recurring $0, one-time $0) resolve correctly and are treated as real overrides (distinct from "no override").
- **Negative** one-time adjustment reduces the year; a negative larger than the baseline **floors the resolved expense at $0**.
- **Non-finite** inputs (NaN/∞) from the UI are rejected/sanitized, never stored.
- **Horizon boundaries:** an override on the first year, the last year, and a year outside the horizon (ignored) behave correctly.
- **Clearing one of two** same-year values (clear the one-time but keep the recurring, and vice-versa) leaves the other intact; clearing both **prunes** the entry.

**Downstream recalculation (controlled profiles):**
- An override changes **downstream balances** in a profile where the expense is funded.
- A **traditional-funded** profile where **tax** provably responds.
- A profile where passive income already covers the expense shows **no** tax change (the conditional stated in §5).

**UI:**
- Open-and-save-without-entry produces **no** override; reopening a customized year **pre-populates** the saved values; the **badge** appears only when a real override exists; **Clear** removes it and prunes the entry.
