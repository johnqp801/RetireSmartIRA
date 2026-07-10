# V2.1 Design — Selectable Conversion Approaches + Charitable/QCD Modeling

**Date:** 2026-07-10 (revised after two external reviews + code reconciliation)
**Status:** Design (brainstorm complete; reconciled against source; awaiting final spec review)
**Branch target:** new `2.1/selectable-conversion-approaches` branch off `main` (do NOT build on the stale `2.0/heir-tax-optimizer-objective` docs-only branch)
**Supersedes decision:** `decisions/log.md` 2026-07-08 ("Bracket-filling → build as a COMPARISON view, not a selectable objective"). See §12.

---

## 1. Motivation

Two testers (Tim, then Fred Lucha) independently asked to choose what the Roth-conversion optimizer optimizes for ("convert the most while staying in 22%", "convert up to just under IRMAA"). Shipped V2.0 has a single fixed objective (minimize lifetime tax) and no user-selectable goal. Competitive research (2026-07-09) confirms selectable conversion goals are table stakes among the serious multi-year planners (Boldin, Pralana, RightCapital, ProjectionLab); we are currently below them. Fred's second observation — the optimizer drains the whole traditional IRA pre-RMD — is accurate under a pure lifetime-tax objective and is exactly why a user-set guardrail has value. The feature also closes a real product-integrity gap (a selectable objective was described to Tim and never shipped).

## 2. Guiding decisions

1. **Co-equal selectable conversion approaches**, not a single fixed objective with the others as foils. Reverses the 2026-07-08 decision; justified because the market ships selectable goals as first-class and Kitces / the Bogleheads consensus legitimize bracket-fill as a real strategy (adjusted for IRMAA/SS/state), rather than dismissing it as Kotlikoff does.
2. **Model charitable *intent* separately from *funding method*.** "How much do you intend to give" is separate from "fund it with cash or a QCD." Prevents double-counting; mirrors how retirees think. Central structural principle. (Refined per review: intent itself can be a fixed amount OR a percent of RMD.)
3. **"Conversion approach", not three co-equal "objectives".** Only minimize-lifetime-tax is an optimization objective; fill-to-bracket and stay-under-IRMAA are deterministic policies/guardrails. UI reflects this.
4. **Default unchanged.** Recommended tax-minimizing plan stays the default and recommended path; alternatives are opt-in. Heir optimization stays its own control (Legacy Planning gated).
5. **Dollar-valued consequences, not warning icons** — phased (see §3): path-level dollar deltas across all computed channels in 2.1.0 (nearly free from the three-way comparison); per-conversion incremental *attribution* in 2.1.1.
6. **Approach × heir-frontier precedence.** The heir frontier applies only to `.recommendedTaxMin` (it varies conversions by sweeping `heirWeight`). The deterministic approaches (`.fillToBracket`, `.limitToIRMAA`) fix conversions by rule and therefore **ignore `heirWeight`** — no frontier exists for them. The comparison's recommended-plan anchor may still reflect the user's current heir setting. Surface this precedence explicitly in the UI rather than leaving it implicit.

## 3. Scope & release cut line

The two external reviews plus a source-code reconciliation (§5) showed the feature is more engine work than first assumed (NIIT is absent from the multi-year engine; IRA and 401(k) balances are lumped; deterministic bracket-fill needs root-finding). Decision (2026-07-10): ship a **minimum core (2.1.0)** and defer the heavier accuracy layers to a **2.1.1 fast-follow**.

### 2.1.0 — Minimum core
- **Phase 0 — NIIT foundational fix.** Wire the existing `TaxCalculationEngine.calculateNIIT()` into `ProjectionEngine` (see §5.1). Standalone correctness fix, own tests, own commit — closes a real shipped-engine gap and provides a primitive the later decomposition needs.
- **Phase 1 — Charitable intent + recurring QCD.** Giving-intent model (fixed amount or % of RMD) + QCD funding (IRA-only, per-spouse, capped), QCD applied before conversion sizing, correct AGI / RMD-satisfaction / IRMAA / SS effects.
- **Phase 2 — Selectable conversion approaches + comparison.** The "Conversion approach" control (recommended tax-min / fill-to-bracket / limit-to-IRMAA), three-way comparison, and **path-level dollar consequences**. Because the comparison already computes both the selected-approach path and the no-additional-conversion path, the per-path deltas for federal, state, IRMAA, ACA, and NIIT (NIIT available after Phase 0) are just subtraction of already-computed values — nearly free. What 2.1.1 adds is *per-conversion incremental attribution* (which year's conversion caused which cost) + the SS-inclusion explanatory figure, not these path-level aggregates.

### 2.1.1 — Fast-follow
- Full multi-year **itemized** modeling: non-QCD cash charitable + SALT (replicating the single-year `saltCap` phaseout + endogenous state tax + OBBBA 0.5% floor + 30/60% AGI ceilings; §68 2/37 cap still deferred).
- Full **finite-difference consequence decomposition** — per-conversion incremental attribution (which year's conversion caused which cost) plus the SS-inclusion explanatory figure, with the strict accounting identity in §5.7. This is beyond 2.1.0's path-level aggregate deltas.
- Charitable **carryforward ledger** (2.1.0 discloses the omission; see §5.9).

### Out of scope (later)
Charitable bunching; DAF / appreciated-stock giving; medical & mortgage-interest itemization; per-year editable giving schedule; N-way comparison (fill-22 vs fill-24 side by side); OBBBA §68 2/37 cap in multi-year; a single universal "effective marginal rate" number; a "convert everything" approach; folding heir into this picker; taxable-account-funded conversion tax; a widow/mortality objective.

## 4. Reconciliation summary (what the code review changed)

Both reviews were largely correct in direction. Source verification (file:line in §5) resolved each code-dependent claim:
- **Already handled in code (de-risked):** SALT OBBBA phaseout + endogenous state tax + component SALT (single-year); 2026 QCD limit ($111k); capital-gain stacking; SS-taxability torpedo; OBBBA senior-deduction phaseout; per-spouse RMD/QCD tracking; single-year QCD tax treatment (correct, only the naming is shorthand).
- **Confirmed real work:** NIIT absent from the multi-year engine; taxable-SS computed but not surfaced; IRA vs 401(k) lumped so QCD can't yet be IRA-restricted; deterministic bracket-fill needs root-finding (the naive `top − baseline` delta is corrected only by the optimizer's ranking, which a deterministic ladder doesn't use).
- **Accepted design tightenings:** intent-vs-funding, approach-not-objective terminology, Phase-C accounting identity (cost results vs explanatory drivers), income-year/premium-year modeling, fixed comparison anchors, duplicate-column collapse, baseline-above-target statuses, config-derived bracket picker, narrowed backward-compat claim, CPA briefing selected+recommended.

## 5. Current-state facts (verified against source, 2026-07-10)

### 5.1 Tax-breakdown primitives
`TaxBreakdown` ([MultiYearValueTypes.swift:14](RetireSmartIRA/MultiYearValueTypes.swift#L14)) exposes `federal`, `state`, `irmaa`, `acaPremiumImpact`. `YearRecommendation` exposes `agi`, `taxableIncome`, `acaMagi`, `irmaaMagi`, `medicareEnrolledCount`. **NIIT is never computed in `ProjectionEngine`** (`calculateNIIT()` exists in `TaxCalculationEngine` but is not called) → the shipped multi-year federal total omits NIIT (pre-existing accuracy gap, fixed in Phase 0). **Taxable SS** is computed (`ProjectionEngine` ~L539) but not surfaced on `YearRecommendation` (surface it in Phase 0/2 as a primitive).

**Channel definitions (used consistently everywhere):** `federal` = regular federal income tax *excluding* NIIT; `niit` = its own channel; the lifetime-tax / objective total includes NIIT **exactly once** (through the niit channel). No section describes NIIT as raising the `federal` value.

### 5.2 QCD / RMD domain model
RMD computed independently on the full balance ([RMDCalculationEngine.swift:15](RetireSmartIRA/RMDCalculationEngine.swift#L15)); QCD correctly excluded from AGI (reduces withdrawals, not an itemized deduction); QCD may exceed RMD with excess still excluded (`max(0, RMD−QCD)`, `DataManager.swift` ~L1488); per-spouse amounts + eligibility. The single-year tax math is correct; only the naming (`scenarioAdjustedRMD`, "RMD after QCD offset") is shorthand. **New work adopts a precise domain model:** calculated RMD, eligible QCD, RMD-satisfied-by-QCD, remaining taxable RMD — as distinct quantities. **Corollary (verify in the model):** an excess QCD above the year's RMD is use-it-or-lose-it — it does NOT satisfy any future year's RMD and must not be carried forward.

### 5.3 Account model / IRA-vs-401(k)
`AccountType` distinguishes IRA / 401(k) / Roth / inherited ([AccountModels.swift:51](RetireSmartIRA/AccountModels.swift#L51)). On `main` (this stale branch predates the inherited-IRA work), inherited IRAs with complete beneficiary metadata already get **their own per-account buckets** with beneficiary drain schedules (`MultiYearStaticInputs.inheritedAccounts`, drained per-schedule in `ProjectionEngine`), separate from the owner roll-up. The remaining coarseness is in the **owner** pool: the adapter lumps owner traditional IRA + owner 401(k) into `primaryTrad`/`spouseTrad` via `.isTraditionalType` ([MultiYearInputAdapter.swift:97](RetireSmartIRA/MultiYearInputAdapter.swift#L97)). **Phase 1 must split the owner pool into owner-IRA vs owner-401(k) per spouse.** QCD then sources from **owner traditional IRA + the (already separate) inherited traditional IRA buckets** — never from 401(k)/403(b) (not QCD-eligible). A QCD from an inherited IRA reduces that inherited bucket and interacts with its beneficiary drain schedule. Explicit rule + test: a QCD cannot satisfy a 401(k) RMD (IRA and 401(k) RMD rules differ). **RMD aggregation groups:** QCDs satisfy RMDs only within the group they're distributed from — own IRAs (aggregable across a person's own IRAs), inherited IRAs (a separate group, not aggregable with own IRAs), and 401(k)s (per-plan, not satisfiable by IRA distributions) each need separate RMD-satisfaction logic. A QCD from an own IRA satisfies own-IRA RMDs only; a QCD from an inherited IRA satisfies that inherited account's RMD only.

### 5.4 SALT / state tax (single-year, to replicate in 2.1.1)
`DataManager.saltCap` ([DataManager.swift:1723](RetireSmartIRA/DataManager.swift#L1723)) models the OBBBA phaseout (base $40k × inflation, 30% reduction of MAGI over $500k, $10k floor, 2025–2029). State income tax is endogenous and fed into SALT before the cap, including Roth-conversion income ([:1683](RetireSmartIRA/DataManager.swift#L1683)); SALT is component-tracked (property + state income + prior-year + additional). 2.1.1 replicates this; it does NOT use a flat cap.

### 5.5 Config values
`tax-2026.json` `qcdAnnualLimit` = 111000 (2025 = 108000) — correct. `saltBaseCap` = 40000 with the phaseout fields present.

### 5.6 Bracket-fill nonlinearity + target semantics
`cliffCandidates()` computes `top − baselineTaxableIncome` ([OptimizationEngine.swift:176](RetireSmartIRA/OptimizationEngine.swift#L176)) — naive. The nonlinear stack (SS torpedo, OBBBA senior phaseout, cap-gain stacking) IS modeled during candidate *ranking* via full `ProjectionEngine` runs, so the existing optimizer is fine. A **deterministic** fill-to-bracket ladder does not rank — so Phase 2 must root-find (expect ~$5–15k error from naive subtraction otherwise).

**Target semantics (pin this):** "fill to the 22% bracket" means fill **ordinary** taxable income to the top of the chosen **ordinary** bracket — NOT total taxable income, which includes LTCG/qualified dividends that stack above ordinary income at preferential rates. The target variable is ordinary taxable income. **Solver requirement:** find the largest conversion that lands ordinary taxable income at-or-below the target after a full projection, with a stated tolerance and a fallback when kinks (SS-taxability phase-in, senior-deduction phaseout) prevent an exact hit. The function is monotone with kinks, not discontinuous — IRMAA/ACA affect MAGI and costs, not taxable income directly, so they don't break monotonicity of the taxable-income target. Tests must include LTCG/QD present.

### 5.7 Consequence decomposition — accounting identity (2.1.1)
Additive cost channels: additional federal income tax; additional NIIT; additional state income tax; additional ACA net-premium cost; present value of additional IRMAA premiums. Explanatory context (NOT re-added): additional SS included in taxable income; ordinary bracket crossed; capital-gain bracket affected; IRMAA tier crossed; ACA subsidy reduced. NIIT appears in exactly one place (its own channel, not inside "federal"). Net lifetime effect is a plan-comparison result, shown separately, never part of the annual additive total. The result model preserves both the income year and the premium year (IRMAA 2-year lag). Finite difference yields the total change; the UI presents "cost results" and "reasons the cost changed" as separate lists (finite difference does not by itself produce a causal split).

### 5.8 IRMAA binding (2.1.0)
`irmaaMagi` is nil pre-Medicare and `medicareEnrolledCount` scales the per-enrollee surcharge on the single MFJ MAGI threshold, so the household rule is largely present. `limitToIRMAA` binds only income years whose 2-year-forward premium year has ≥1 spouse Medicare-enrolled; the comparison captures window-tail IRMAA hits (income in years 8–10 landing on premiums outside the window). A user-selectable safety buffer (reuse `cliffBuffer`) rather than filling to $1 under.

### 5.9 Charitable modeling limits (2.1.0 disclosure)
In 2.1.0 only the QCD **exclusion** is modeled. QCDs are excluded from AGI (not deducted), so the AGI ceiling does not apply to them, and non-QCD cash charitable is **not deducted at all** until 2.1.1. So the 2.1.0 disclosure is: non-QCD cash gifts are shown as giving *intent* but are neither deducted nor carried forward until 2.1.1's itemized path lands — the projection may understate future deductions for givers whose intent exceeds their QCD capacity. The AGI-ceiling + carryforward mechanics (a simple 5-year ledger) belong to 2.1.1, where cash charitable actually becomes deductible. (Corrected from an earlier draft that described an AGI-ceiling carryforward limitation that cannot occur in 2.1.0.)

## 6. Phase details (2.1.0)

### Phase 0 — NIIT foundational fix
Wire `calculateNIIT()` into `ProjectionEngine`'s per-year computation; add `niit` to the per-year output (own channel, not folded into `federal` to avoid the double-count). Standalone tests against hand-calcs. Independent commit.

### Phase 1 — Charitable intent + recurring QCD
- **Intent (`GivingIntent`) — a clean two-case model:** `.fixedAnnualAmount` or `.percentOfRMD`. Intent is just how much you plan to give and exists at **any age**; funding (below) is a separate axis, and only *QCD funding* is age-70½-gated. For `.percentOfRMD`, "which RMD" is the **household total RMD across all traditional sources** (owner IRA + owner 401(k) + inherited traditional); note inherited-IRA RMDs — which can begin before the owner's own RMD age — DO count toward that total. `.fixedAnnualAmount`'s inflation treatment ("maintain today's amount after inflation") is an **explicit projection setting**, not silently inherited. Defaults seeded from the single-year charitable + QCD entries (one source of truth). In 2.1.0, any giving not funded by a QCD (pre-70½, or beyond QCD capacity) is intent-only and not deducted (§5.9).
- **Age-70½ convention:** projections assume a year-end (Dec 31) QCD; a spouse is QCD-eligible in any tax year in which they reach 70½ by Dec 31 — NOT integer age ≥ 70/71. The same convention is used in the single- and multi-year engines.
- **Funding method (separate axis):** `.qcdFirst` (fund the target with QCD to the extent eligible — default) or `.fixedQCD(amount)` (cap the QCD routed). QCD is IRA-only per §5.3, per spouse. Eligible QCD = `min(funding-rule amount, remaining giving target, spouse annual QCD limit, spouse eligible IRA balance)`. RMD-satisfied-by-QCD = `min(calculated RMD, eligible QCD)`; remaining taxable RMD = calculated RMD − RMD-satisfied-by-QCD. Excess QCD above RMD is still excluded (up to the limit), reduces the IRA balance, and does NOT satisfy any future RMD (§5.2). Deterministic spouse/account allocation (default: each spouse's QCD from their own IRA first, then their inherited IRA buckets). The non-QCD remainder of the target is carried as *intent only* in 2.1.0 (not deducted — §5.9), and routes to the itemized path in 2.1.1.
- **Ordering (per year):** compute RMD → determine eligible charitable commitment → apply QCD (offset RMD, exclude from AGI) → remaining taxable RMD → baseline AGI/MAGI/taxable → (Phase 2) conversion room on the post-QCD baseline → taxes/IRMAA/SS/ACA/balances/future RMDs.
- **Disclosures:** non-QCD cash charitable is NOT tax-deducted in the multi-year projection in 2.1.0 (rides 2.1.1 itemized) — disclose so it does not silently understate deductions; operational note ("complete QCDs before taking the rest of the RMD"); explicitly unmodeled: IRA basis / nondeductible contributions, the post-70½ deductible-contribution reduction to excludable QCDs, employer-plan-vs-IRA nuances beyond the IRA-only restriction.
- **Reuse:** mirror the single-year QCD tax treatment; normalize both engines onto the precise domain model rather than reproducing the "reduced RMD" shorthand.

### Phase 2 — Selectable conversion approaches + comparison
- **`ConversionApproach` enum** on `OptimizationEngine`: `.recommendedTaxMin` (existing greedy search, unchanged, default); `.fillToBracket(rate)` (deterministic per-year ladder, **root-found** to land **ordinary** taxable income at the top of the chosen ordinary bracket — not total taxable income, per §5.6 — on the post-QCD baseline, after SS-taxability and senior-phaseout kinks); `.limitToIRMAA(tier, buffer)` (deterministic ladder filling to just under the tier, Medicare-age-bound per §5.8).
- **Bracket picker:** options derived from the config bracket table (not a hardcoded list). Show all supported brackets; a bracket already below the year's unavoidable baseline taxable income is labeled "not achievable this year" (zero conversion that year) but the policy stays active for later years. Never filtered solely from year one.
- **Baseline-above-target statuses:** distinguish room-available / at-target / target-exceeded-by-baseline / not-applicable, with exact messaging (e.g. "Baseline income already exceeds the 22% ceiling, so no additional conversion is added this year"). Same for IRMAA.
- **Comparison:** fixed three-way — selected approach vs the **Recommended plan** (the app's current recommendation given the user's settings — legacy-aware if Legacy Planning is on, pure tax-minimizing if off; not labeled "tax-minimizing" to avoid implying heirWeight=0) vs **"No additional Roth conversions"** (exact label: RMDs, QCDs, withdrawals, giving still occur). When the selected approach IS the Recommended plan, collapse to two columns. Not swappable in 2.1.0 (change the selected approach via the primary control).
- **Consequence flags (2.1.0 level):** per approach, **path-level dollar deltas** for federal, state, IRMAA, ACA, and NIIT — selected-approach path minus no-additional-conversion path, both already computed by the comparison, so this is subtraction of existing values. The IRMAA figure shows both income-year and premium-year (2-year lag). Plus explanatory flags: which effects were triggered (SS taxation increased, IRMAA tier crossed, ACA cliff, ordinary bracket crossed, cap-gain bracket affected), and a **"NIIT increased"** flag worded carefully — "NIIT increased because MAGI crossed the threshold and the household has net investment income" — never implying the Roth conversion itself is net investment income. Per-conversion incremental *attribution* is 2.1.1.
- **CPA briefing:** leads with the selected approach and shows how it differs from the recommended plan (Δ lifetime tax, Δ peak conversion, Δ Medicare cost).

## 7. Architecture / units
- `ProjectionEngine`: + NIIT wiring (Phase 0); + surfaced taxable-SS; + per-year QCD application with the IRA/401(k) split (Phase 1); + the deterministic approach ladders with root-finding (Phase 2). All additive; absent charitable/QCD/approach inputs reproduce current behavior, EXCEPT the Phase 0 NIIT fix (which corrects total tax for NII-over-threshold scenarios via the niit channel; see §8).
- `MultiYearStaticInputs` / `MultiYearInputAdapter`: carry IRA-vs-401(k) split balances and a `CharitableGivingPlan` (intent + funding rule).
- `OptimizationEngine`: + `ConversionApproach` parameter alongside `heirWeight`; deterministic approaches bypass the greedy search.
- `PlanComparison`: generalize to the fixed three-way; existing two-way (plan-vs-nothing) consumers remain valid.
- New `ConsequenceDecomposition` module lands in 2.1.1.

## 8. Backward compatibility & risk control
- `ConversionApproach` defaults to `.recommendedTaxMin`. **With charitable/QCD/approach inputs absent, the recommended approach reproduces current V2.0 behavior exactly — EXCEPT for scenarios affected by the Phase 0 NIIT correctness fix.** Any scenario with net investment income above the $200k / $250k-MFJ threshold now produces higher (correct) *total* tax than V2.0 — via the new separate `niit` channel, NOT a change to `federal` (which stays regular income tax excluding NIIT; see §5.1). Those scenarios get new expected-output baselines; the change is a deliberate correctness fix, not a regression. With charitable/QCD/approach inputs enabled, the objective function is unchanged but candidate amounts and projected outcomes appropriately reflect the new tax inputs — so results *do* change, as intended. The same qualification applies to the heir frontier. (This narrows the earlier, too-strong "byte-for-byte unchanged" claim.)
- Each phase leaves the full suite green before the next; TDD throughout; existing objective/frontier tests rerun as a regression gate.
- Phase 0 (NIIT) is a self-contained correctness fix; Phases 1 and 2 are the release. 2.1.1 is separately planned.

## 9. Testing (2.1.0)
- **Phase 0:** NIIT computed per year against hand-calcs; not double-counted in `federal`; zero-NII case unaffected.
- **Phase 1:** QCD IRA-only (never draws from 401(k)); QCD > RMD (full QCD excluded from AGI, only RMD-sized portion satisfies the RMD, full QCD reduces the IRA balance); one spouse eligible, the other not; household target allocation across two spouses/accounts; `.fixedAnnualAmount` vs `.percentOfRMD` intent tested separately from the QCD funding caps; age-70½ (year-end convention) and RMD-age gating; ordering correctness.
- **Phase 2:** fill-to-bracket root-finding lands within tolerance at the target after SS-taxability / senior-deduction / cap-gain bends (explicit bending tests); IRMAA ladder respects the buffer and binds only Medicare-relevant premium years, incl. the window-tail; unachievable-bracket labeling; baseline-above-target statuses; three-way comparison metrics; duplicate-column collapse; QCD-opens-room emerges (more room under a ceiling when giving routes through QCD).
- **Backward-compat:** inputs-absent reproduces current lifetime-tax-min + heir-frontier + standard-deduction/no-QCD projection exactly, EXCEPT scenarios affected by the Phase 0 NIIT fix (new expected baselines for NII-over-threshold cases).
- **Cross-cutting:** NIIT included in the objective/lifetime total exactly once (not double-counted with `federal`); path-level channel deltas sum to the total delta with no double-count; `heirWeight` ignored by the deterministic approaches; the Recommended-plan anchor behaves correctly under a nonzero `heirWeight` (heir-aware when legacy on, pure tax-min when off); a QCD cannot satisfy a 401(k) RMD; an own-IRA QCD cannot satisfy an inherited-IRA RMD (separate aggregation groups, §5.3).

Full suite green at each phase boundary (baseline ~1,211).

## 10. Open implementation questions (resolve in plans)
- Placement of charitable/QCD controls in the Multi-Year tab UI.
- Spouse/account QCD allocation default (own-IRA-first vs pro-rata).
- Root-finding method + tolerance for fill-to-bracket.

## 11. Competitive positioning (2026-07-09 research)
Selectable bracket/IRMAA goals: table stakes (reaching parity). Correct-AGI QCD modeling: table stakes; omitting it is a gap for the 70½+ charitable segment. "Charitable as % of RMD": unmet across the surveyed set (small differentiator). Explicitly showing how QCDs open conversion room: a **presentation** differentiator (not a claim that competitors' engines ignore the interaction — that stronger claim is unverified and must not appear in copy). Dollar consequence decomposition (2.1.1): the main differentiator.

## 12. Decision-log note
Reverses the 2026-07-08 decision (bracket-filling as comparison view, not selectable objective). A new `decisions/log.md` entry records the reversal (market parity + Kitces/Bogleheads legitimacy + closing the Tim gap) plus the 2026-07-10 scoping decisions (minimum core vs 2.1.1; NIIT foundational fix; carryforward disclosure), referencing but not editing the prior entry.
