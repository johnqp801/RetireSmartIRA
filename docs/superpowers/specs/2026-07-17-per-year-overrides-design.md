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

**This release addresses expenses only (parts 1's discoverability + part 2), with the full model designed so income slots in later. Future-year income entry remains necessary to satisfy Alan's complete request** and is called out again in Scope.

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

Legacy `perYearExpenseOverrides: [Int: Double]` decodes into `perYearOverrides[year].livingExpenses = FieldOverride(recurringLevel: nil, oneTimeAmount: value)`. Legacy overrides were spot values for a single year, so they **migrate to a one-time amount, preserving their existing calculation behavior**. (The saved file's bytes change once it is re-written in the new format; the *computed plan* does not.)

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

oneTime(Y) = perYearOverrides[Y].livingExpenses.oneTimeAmount ?? 0

expense(Y) = recurringBaseline(Y) + oneTime(Y)
```

All amounts are **nominal** (actual dollars in year Y), consistent with the existing engine (the override at line 491 already replaces the CPI-grown nominal figure).

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
- Rows with an override show a **badge**.
- The control opens a **`YearDetailEditor`** sheet for that year. In 2.1.2 it shows, for living expenses:
  - the **projected value read-only** (labeled with the year, plus a today's-dollars caption for anchoring),
  - a **separate, empty** override input for the recurring level and one for a one-time amount,
  - a **scope** made explicit by which field is used (recurring vs one-time), and a **Clear** action.
- **No accidental overrides:** opening the sheet and saving without entering anything produces **no** override. Only an explicit entry creates one; Clear removes it.
- The sheet is structured to hold future input fields (income, withdrawals) without restructuring.

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

- **Migration + round-trip:** legacy `[Int: Double]` → `livingExpenses.oneTimeAmount`, preserving the computed plan; encode/decode of the new model.
- **One-time spike:** a `oneTimeAmount` changes that year only; neighbors stay on the prevailing path.
- **Recurring anchor:** a `recurringLevel` re-anchors the CPI baseline from its year until a later anchor; a subsequent recurring anchor takes over; the worked example is pinned.
- **Coexistence:** a recurring anchor and a one-time amount in the same year sum correctly.
- **Downstream recalculation (controlled profiles):** an override changes downstream balances in a profile where the expense is funded; a **traditional-funded** profile where **tax** provably responds; a profile where passive income already covers the expense shows **no** tax change.
- **UI:** open-and-save-without-entry produces no override; badge appears only when an override exists; Clear removes it.
