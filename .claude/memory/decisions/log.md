# Decision Log

Append-only. Newest entries at top. Each entry: `## YYYY-MM-DD: <Title>` + decision + one-sentence rationale.

---

## 2026-07-17: V2.1.2 scope — engine batch + four Alan/Fred-driven items

**Decision:** V2.1.2 (branch `fix/multiyear-state-tax-heir-frontier`) ships the engine batch already on the branch — I1 (PA/IL/MS conversion state tax), I3 (heir-frontier de-domination), B2 (deferred-tax-on-remaining-IRA row), the cross-λ Pareto repair (25f47f5), the wealth-consistent objective (900ba6d: all tax flows discount at the growth rate — cures λ=0 over-conversion + opens the heir frontier), and the widow-banner nominal-tax fix (7a08419) — PLUS four newly-approved user-driven items:
1. **State withholding as a percent** (Alan #2) — mirror the 3 federal withholding fields (`stateWithholdingMode`/`Percent`/`effectiveStateWithholding`) for state; `stateWithholding` is currently a flat `Double`.
2. **Phantom-conversion + gross-up disclosure** (B4 + A4) — stop the ladder/CPA export showing never-executed conversions after the IRA drains (cap `upperBoundCap` at current-year convertible trad + route consumers to an `executedRothConversion`), and disclose the gross-up IRA withdrawal taken to pay conversion tax. Fixes the CPA report Fred reviews.
3. **Local/city income tax** (Alan #1, backlog E9) — add a local income-tax line to the engine (e.g. NYC 3.88%); today only the itemized SALT deduction exists.
4. **Per-year expense override UI** (Alan #3a) — expose UI writing the existing `perYearExpenseOverrides` (engine already reads it at `ProjectionEngine.swift:490`).

**Rationale:** Alan's items were verified-real gaps he reported and never got a reply; B4/A4 fix a correctness/credibility bug in the artifact Fred reviews; all four fit a coherent "accuracy + user-requested refinements" release without the v2.2-sized decumulation workflow. **Explicitly deferred to v2.2:** Fred's full recommend/commit/explain + withdrawal-ordering vision, and per-year INCOME overrides + Scenarios↔Multi-Year integration. Release verified live in the demo profile 2026-07-17 (moderate conversion ladder, clean frontier, coherent charts) before this scope was set.

## 2026-07-11: Phase 2c UI decisions — no "Recommended" label; selected approach is the active plan

**Context:** Brainstormed the Phase 2c (SwiftUI) design for the conversion-approach UI. Decisions locked with the user via the visual companion + terminal.

**Decisions:**
1. **No "Recommended" anywhere — the app does not make recommendations** (companion tool, not advisor). The anchor comparison column + the picker's first segment are labeled by the objective the engine actually optimized, **dynamically on the Legacy Planning setting**: "Minimize lifetime tax" (legacy off / heir weight 0) vs "Optimize tax + legacy" (legacy on). Supersedes the frozen 2026-07-10 spec's "Recommended plan" label while preserving its reasoning (never imply heir weight = 0; never call the legacy-on anchor "tax-minimizing"). Rationale: "Recommended" is advice framing the product avoids; "minimize lifetime tax" alone is inaccurate when the legacy-aware objective is in force.
2. **Three-way comparison REPLACES the two-way `PlanComparisonView`** as the tab's single comparison block (three-column table). The `PlanComparison` model stays (CPA briefing + TaxImpactChart still use it).
3. **Selected approach becomes the ACTIVE PLAN everywhere** (charts, balances, Year-1 levers, CPA briefing), not just a comparison lens.
4. **Year-1 rule = mutual exclusion:** a deterministic approach and a manual Year-1 Roth override cannot both hold; editing Year-1 reverts the approach to the objective optimizer (`.recommendedTaxMin`) with the override applied (existing off-plan/"Custom" state).
5. **Giving = light refinement only** (surface the already-seeded charitable amount + funding QCD-first + cash-not-deducted disclosure); no new giving data model in 2.1.0.

**Spec:** `docs/superpowers/specs/2026-07-11-v2.1.0-phase2c-approach-ui-design.md`.

## 2026-07-10: BUILD selectable conversion approaches (reverses 2026-07-08) + V2.1 scoping

**Trigger:** Fred Lucha (tester) asked, in his own words, for exactly the selectable objective promised to Tim ("convert the most while staying in 22%" / "without triggering IRMAA"), plus he observed the optimizer drains the whole traditional IRA pre-RMD. Competitive research (2026-07-09) confirmed selectable bracket/IRMAA conversion goals are TABLE STAKES among serious multi-year planners (Boldin, Pralana, RightCapital, ProjectionLab) and that Kitces / the Bogleheads consensus legitimize bracket-fill as a real (IRMAA/SS/state-adjusted) strategy — only Kotlikoff (who sells the competitor) calls it a "rule of dumb."

**Decision (reverses 2026-07-08):** Build the alternatives as **co-equal, user-selectable "conversion approaches"**, not merely a comparison foil. The 2026-07-08 "comparison view only" call was made on Kotlikoff's argument alone, before the market-parity + Kitces/Bogleheads evidence and before Fred's second data point. Terminology fix (per review): only minimize-lifetime-tax is an *objective*; fill-to-bracket and stay-under-IRMAA are deterministic *policies*. Central structural principle: model charitable **intent** separately from **funding method** (cash/itemized vs QCD) to prevent double-counting. Recurring QCD (IRA-only) + %-of-RMD intent + QCD-aware conversion room are in scope (QCD modeling is table stakes; %-of-RMD and surfaced QCD-opens-room are differentiators).

**Scoping (after two external reviews + a 5-thread source reconciliation):**
- **Minimum core 2.1.0**: Phase 0 NIIT foundational fix → Phase 1 charitable-intent + recurring QCD → Phase 2 selectable approaches + three-way comparison + path-level dollar consequences. **Full itemized (cash charitable + SALT), the per-conversion finite-difference decomposition, and the carryforward ledger defer to 2.1.1.** Rationale: verification exposed more engine work than assumed (NIIT absent from the multi-year engine; owner IRA/401(k) lumped so QCD can't yet be IRA-restricted; deterministic bracket-fill needs root-finding), so ship a leaner, lower-risk core first.
- **NIIT is a pre-existing gap**: the multi-year `ProjectionEngine` never calls `calculateNIIT()`, so shipped multi-year totals omit NIIT — fix as a standalone Phase 0 correctness commit.
- **Carryforward**: disclosed in 2.1.0 (non-QCD cash is intent-only, not deducted until 2.1.1), simple 5-year ledger in 2.1.1.

**Spec:** `docs/superpowers/specs/2026-07-10-selectable-conversion-approaches-charitable-modeling-design.md` (branch `2.1/selectable-conversion-approaches`, commit `26d391c`). Verified code facts + competitive research in `reference/2026-07-10-*`. See [[optimizer-objective-not-selectable]].

## 2026-07-08: Bracket-filling → build as a COMPARISON view, not a selectable objective (Tim/2.1 debt reframed)

**Trigger:** Kotlikoff's "Federal Bracket-Filling to Roth Convert" (substack) argues bracket-filling is the naive Wall-Street heuristic because it ignores SS taxation, IRMAA, and state tax; his alternative is global lifetime-tax/consumption optimization. That's essentially the app's existing design — the optimizer minimizes LIFETIME tax and already models SS taxability, IRMAA (2-yr lag), state, ACA, and NIIT.

**Decision:** Recast the long-standing "we promised Tim a selectable objective / bracket-smoothing" debt ([[optimizer-objective-not-selectable]]). Rather than build bracket-filling as an alternative *objective* to optimize toward (optimizing for a heuristic a serious economist calls catastrophic), build it as a **comparison / explanation view**: "here's what naive bracket-filling would do, here's what the optimizer found, here's the gap." Cheaper, more honest, and turns the critique into a selling point. Not yet scheduled; candidate for 2.x.

**Rationale:** bracket-filling deserves to exist in the product as the thing we beat, not the thing we chase.

## 2026-07-08: Optimizer confirmed "go-big," not bracket-hugging; $500k/yr candidate cap is a known boundary

**Trigger:** empirical diagnostic (Kotlikoff-shaped profile: $2M trad / $2M taxable, 62, single, OR) through `MultiYearTaxStrategyEngine`.

**Finding (verified, not a decision to change anything yet):** the optimizer goes aggressive — year-1 conversion $400k into the 35% bracket, later years $445k/$495k, ~$2.5M total, trad fully drained. It does NOT bracket-hug. The `cliffCandidates` `cap = 500_000` (`OptimizationEngine.swift:128`) is binding, so it can't propose a single-year >$500k "blitz" like Kotlikoff's $810k year-1; it spreads aggression across ~8 years and stays ≤35% (never 37%). **Decision: leave as-is for now** — plausibly benign or better for a lifetime-tax objective (spreading to stay ≤35% likely beats blitzing into 37%). Flagged as a 2.x revisit (raise/remove the cap for very large balances) and as a candidate `MultiYearReferenceScenariosTests` regression ("we don't bracket-hug") to add once the inherited-IRA multi-year session (task_7c045c0a) lands. Detail: reference/2026-07-08-inherited-ira-drawdown-model.md + the 2026-07-08 session note.

## 2026-07-07: Charitable AGI ceilings (30% LT stock / 60% cash) built — completes the itemized-charitable stack

**Trigger:** the OBBBA 2026 coverage audit (`reference/2026-07-07-obbba-2026-coverage-audit.md`) flagged as its top gap (G1, HIGH) that itemized charitable was uncapped — the app's own stock-donation feature could over-deduct a large long-term gift (e.g. $60k stock on $150k AGI: law allows $45k this year, app deducted $60k), understating tax.

**Decision (user-chosen: build it):** Model the AGI ceilings on the itemized path: long-term appreciated stock (FMV) limited to 30% of AGI; cash + short-term/basis stock to 60% of AGI. `DataManager.ceilingLimitedCharitable` applies them, feeding the existing `deductibleCharitableDeductions` so the ceilings run BEFORE the 0.5% floor. `totalItemizedDeductions` was left textually untouched (routes through the charitable helper) specifically to avoid colliding with the concurrent §68-cap session. Config rates `charitableCashAGICeilingRate` (0.60) / `charitableLTStockAGICeilingRate` (0.30) — no year gate (ceilings are longstanding; the 60% cash limit was made permanent by OBBBA). Itemized-breakdown UI split into an "AGI Ceiling" line + a "0.5% AGI Floor" line so it foots.

**Simplifications (disclosed in code):** the 5-year carryforward of excess and the cross-category overall-60% interaction are not modeled (excess is treated as not-deductible this year — conservative).

**State:** TDD, 7-test `CharitableAGICeilingTests`. Built on a branch off `main`, HELD unmerged while the §68 "35% cap" session was concurrently editing the same files; after that session merged (`11cf855`), rebased onto it (config/JSON conflicts resolved, order-of-ops verified correct without engine changes, one fallback arg-order fixup), full suite green **1203**, merged `main` (`45fff75`). Federal single-year only. Not in the shipped 2.0.1/build 59 — rides 2.0.2/build 60 with the rest of the charitable stack. Remaining audit gaps: QBI §199A (MED-LOW), HSA-on-bronze content, estate disclosure (both LOW).

## 2026-07-07: OBBBA §68 overall itemized-deduction limitation (2/37 rule) built — the "35% cap" that was filed

**Decision (user-directed):** Built the 2/37 rule that was *filed* in the entry below (`task_bf6c96bd`). §68 as amended by OBBBA caps the tax value of itemized deductions for top-bracket taxpayers, TY 2026+. **Rationale:** without it the app overstated itemized-deduction value (understated tax) for filers with taxable income above the 37% threshold (~$640,600 single / $768,700 MFJ, 2026) — a narrow but real slice.

**Statutory mechanism (confirmed against IRC §68 text + Thomson Reuters/Greenleaf before coding, per CLAUDE.md):** reduction = `2/37 × min( total itemized deductions, taxable-income-BEFORE-itemized-deductions − 37%-bracket threshold )`. The "before itemized deductions" measure is the subtle part — pinned by the statute's own "increased by such amount of itemized deductions" clause and the Thomson Reuters Max & Penny worked example ($850k income, $41,750 post-floor itemized → reduction $41,750 × 2/37 = $2,257). Applied AFTER all other floors/phaseouts, including the already-modeled 0.5% charitable AGI floor. Federal only; does not touch AGI or state.

**Implementation (on `claude/blissful-lehmann-34cb01`, full suite 1196 tests green):** new `DataManager.itemizedOverallLimitationReduction` (gated on itemizing + year ≥ config first-year + income over the 37% threshold) subtracted from `effectiveDeductionAmount` on the itemized path only, flowing into `scenarioTaxableIncome`; private `topOrdinaryBracketThreshold` reads the top bracket from `federalBracketsSingle/MFJ` (no new threshold field). Config fields `itemizedOverallLimitationRate` (2/37) + `itemizedOverallLimitationFirstYear` (2026) added to `TaxYearConfig` schema, the hardcoded fallback, and all four `tax-*.json`. TDD: 7-test suite `ItemizedDeductionOverallLimitationTests` (itemized-is-lesser, excess-is-lesser [pins the before-itemized reading], below-threshold, pre-2026, standard-path, MFJ-threshold, post-charitable-floor interaction). **Design notes:** amount (1) uses `totalItemizedDeductions` incl. senior bonus per spec, but the senior bonus is always fully phased out to $0 at 37%-bracket income so it is a numeric no-op; `recommendedDeductionType` still compares the gross itemized total vs standard (the ~5.4% haircut never flips the itemize-vs-standard choice in the 37% bracket). No existing itemizer test encoded 37%-bracket pre-cap behavior, so none needed updating.

## 2026-07-07: OBBBA itemized-charitable 2026 changes — 0.5% AGI floor built; 35% benefit cap filed

**Trigger:** researching a comment made during the non-itemizer fix. Web-verified (Thomson Reuters, Greenberg Traurig, Tax Foundation, Fidelity Charitable, Journal of Accountancy) that OBBBA adds two itemized-charitable changes for TY2026+: (1) a **0.5%-of-AGI floor** — only charitable gifts exceeding 0.5% of the contribution base (AGI) are deductible when itemizing; (2) a **35% benefit cap** — but that's actually a **broad limitation on ALL itemized deductions** (not charitable-specific) for **37%-bracket** taxpayers, reducing itemized deductions by **2/37 of the lesser of (total itemized) or (income above the 37% threshold)**. (My earlier note called #2 "35% cap on itemized charitable" — imprecise; corrected here.) Code audit confirmed the app modeled **neither** (`totalItemizedDeductions` summed charitable at full face value, no floor/cap logic).

**Direction note:** these are the OPPOSITE error from the non-itemizer gap — without them the app *overstates* itemized deductions → *understates* tax for itemizing donors (0.5% floor: broad) and top-bracket filers (35% cap: narrow).

**Decision (user-chosen: both):**
- **Built the 0.5% floor now.** `DataManager.charitableAGIFloor` (0.5% × AGI, 2026+) + `deductibleCharitableDeductions` (= max(0, charitable − floor)); `totalItemizedDeductions` now uses the floored amount (federal only; AGI/state unaffected). Config fields in all 4 JSONs + fallback. Itemized-breakdown UI line ("0.5% AGI Floor" + "Deductible Charitable"), mirroring the medical-floor display so the breakdown foots. TDD: 5 new `ItemizedCharitableAGIFloorTests`; updated 2 tests that encoded the pre-floor behavior (cash-in-itemized, senior-bonus-on-itemized). Full suite green (1,189). Merged to `main` (`e68f0bf`).
- **Filed the 35% cap** as a spawned background task (`task_bf6c96bd`) — low priority (only 37%-bracket, ~$640k+ single / $768k+ MFJ; narrow for a retiree audience). Formula + sources captured in the task prompt.

**Rationale:** the 0.5% floor is broadly applicable and correctness-relevant; the 35% cap is narrow and more complex, so defer.

**State:** single-year engine only (multi-year `ProjectionEngine` stays standard-deduction-only). Not in the submitted 2.0.1/build 59 — future build. The non-itemizer §170(p) $1,000/$2,000 deduction is NOT subject to the 0.5% floor (verified). Interaction handled: flooring runs before the auto itemize-vs-standard pick, so a filer flipped to standard correctly gets the non-itemizer deduction instead. See [[optimizer-objective-not-selectable]] neighbors in this log (2026-07-07 non-itemizer entry below).

---

## 2026-07-07: OBBBA non-itemizer cash charitable deduction (§170(p)) modeled + surfaced

**Trigger:** working a tax-scenario question (single filer "Jill," 2026), the correct hand-calc diverged from what the engine would produce. Code audit confirmed a real gap: cash donations only flowed into `totalItemizedDeductions` (`scenarioCharitableDeductions` → `totalItemizedDeductions`), so a **standard-deduction filer's cash gift produced $0 federal benefit** — but 2026+ OBBBA §170(p) allows non-itemizers up to **$1,000 (single/HoH/MFS) / $2,000 (MFJ)** for **cash** gifts on top of the standard deduction. Not previously logged as known/deferred (the "M4 standard-deduction-only" note is about the separate multi-year engine).

**Decision (user-chosen: build it now):** Model it in the single-year engine. Added `DataManager.nonItemizerCharitableDeduction` (cash only — stock gifts excluded; non-itemizers only; year-gated to 2026+; capped) and subtracted it in `scenarioTaxableIncome` **but not `federalAGI`** (below-the-line, so SS/IRMAA/ACA/NIIT are unaffected). Config fields (`nonItemizerCashCharitableCapSingle/MFJ`, `...FirstYear`) added to all four `tax-*.json` + the hardcoded fallback. UI: a "Cash Charitable (OBBBA)" line in the Dashboard deduction breakdown (so Taxable Income foots) + a self-hiding `NonItemizerCharitableCard` in the Scenarios charitable step.

**Rationale:** same shape as the senior-bonus itemize bug (a deduction the law grants to non-itemizers that the engine only applied on the itemized path); it silently overstated tax for a very common case (most filers take the standard deduction and many donate cash).

**State:** TDD, 7 new tests + 1 corrected (a test had encoded the pre-2026 zero-benefit premise). Full suite green (1,184). Merged to `main` (`2e52aa5`). **Single-year engine only** — the multi-year `ProjectionEngine` stays standard-deduction-only (separate limitation). **Not in the submitted 2.0.1/build 59** — needs a future build (2.0.2/2.1). Jill's tax: ~$1,910 → ~$1,640 (the $1,000 deduction is worth ~$270 for her because it also drops LTCG under the 0% cap-gains ceiling). Follow-up candidate: the OBBBA 0.5% AGI floor + 35% benefit cap on *itemized* charitable (2026) is likely also unmodeled — separate itemized-side task.

---

## 2026-06-18: Multi-state tax-completeness audit (CA, NY, PA) — NY $20k double-exemption bug fixed into 1.9; rest tracked

**Trigger:** after the NJ audit, ran the same worksheet/config audit for CA, NY, PA. Verified against configs (CA `StateTaxData.swift:1008-1045`, NY `:1715-1759`, PA `:893-905`).

**NY — has a real bug + gaps:**
- 🔴 **$20,000 exclusion applied TWICE (over-exemption bug).** NY config has `pensionExemption: .partial(20_000)` AND `iraWithdrawalExemption: .partial(20_000)` with NO `pensionAndIRAShareSingleCap`, so the engine subtracts $20k for pension AND another $20k for IRA (up to ~$40k/person, ~$80k MFJ both-qualifying). NY Tax Law §612(c)(3-a) is **ONE combined $20,000 per individual** across pension+annuity+IRA. **DECISION: fix in 1.9** via `pensionAndIRAShareSingleCap: true` (same one-flag fix as NJ). **Limitation:** the combined-cap branch sums HOUSEHOLD pension+IRA and applies `min(combined, 20k×perIndividualMultiplier)`; NY's cap is truly PER-SPOUSE ($20k each), so a concentrated-income MFJ couple (one spouse holds most pension/IRA) may still slightly over-exempt. Full per-spouse attribution is a follow-up; the flag still fixes the egregious double-count.
- 🟠 **Government/federal/military pension FULL exclusion not modeled.** NY fully exempts NY State/local, federal civil-service, and military pensions (no $20k cap); we cap all `.pension` at $20k → over-taxes public retirees. Needs a pension subtype/input. (Military may be handled via `MilitaryRetirementExemption` — verify it exempts NY.) Defer past 1.9.
- 🟠 **NYC / Yonkers local income tax** (~3.08–3.88% NYC) not modeled at all. Big for NYC residents. Scope item, defer.

**CA — mostly correct.** SS exempt ✓; pension/IRA fully taxable ✓ (CA has no retirement exclusion); cap gains `.taxedAsOrdinary` ✓; std deduction $5,706/$11,412; HSA contribution add-back ✓. Gaps: CA **itemized deductions** (differ from federal, no SALT cap at state level — confirm we support CA itemized vs standard-only); CA **exemption credits** (~$149/person, credit not deduction, not modeled); CA **HSA earnings** also taxable (niche); confirm std-deduction is current-year. All defer.

**PA — best-modeled for retirees.** Flat 3.07%; all retirement income exempt (`.full`) ✓; SS exempt ✓; cap gains at flat rate; `capitalLossesClassIsolated: true` (Class-3 isolation) ✓; early-distribution basis partially modeled. Gaps low-priority: Tax Forgiveness/Schedule SP (mostly moot — retiree PA taxable income ~$0 after exemption); early-dist basis rarely hit for 60+ audience.

**Cross-cutting (CA/NY/PA/NJ):** out-of-state municipal-bond interest reversal = already-tracked `TODO(v1.8.4)` ([DataManager.swift:473](RetireSmartIRA/DataManager.swift:473)).

**Status:** NY $20k combined-cap fix **DONE** in 1.9 — commit `41364ac` (`pensionAndIRAShareSingleCap: true` on NY; 4 TDD tests; TaxsimOracle + consistency green; concentrated-income MFJ limitation documented in-code). Everything else (NY government-pension full exclusion, NYC local tax, CA itemized/exemption-credits/HSA-earnings, PA Tax Forgiveness, cross-state out-of-state-muni TODO) logged for a future multi-state completeness pass.

---

## 2026-06-18: NJ 1.9 scope DECIDED — add Worksheet D + personal exemptions (resolves the OPEN item below)

**Decision (John, 2026-06-18):** Add to 1.9, on top of the already-built pension-exclusion phaseout: (1) **Worksheet D — Other Retirement Income Exclusion**, and (2) **NJ personal exemptions**. Defer IRA basis, medical, property-tax, and the tax-exempt-interest flag to a later release.

**Precise Worksheet D mechanic (worked out against the official 2025 chart Bob sent):**
- Chart "maximum exclusion" (line 1) = **% of line 27 (TOTAL income)** and is the ceiling for pension **+ other** combined: $100k (≤$100k) / 50%×total ($100,001–125k) / 25%×total ($125,001–150k) / $0 (>$150k). Single: $75k / 37.5% / 18.75% / $0.
- Pension exclusion (line 28a) = tier% × pension/IRA income.
- Unused (line 3) = chartMax − pension exclusion → shelters OTHER income (interest/dividends/cap gains) **iff** age 62+ AND total ≤ $150k AND earned income (wages+business+partnership+S-corp, NJ lines 15+18+21+22) ≤ $3,000.

**Consequence — changes our existing 1.9 worked example (correctly):** $50k div + $100k pension, MFJ, $150k total, no wages → chartMax 25%×$150k = $37,500; pension excl $25,000; unused $12,500 shelters $12,500 of dividends → **NJ taxable $125,000 → $112,500** (then −~$4,000 exemptions = $108,500). The `NJPensionPhaseoutTests` $150k assertion must be updated to the new correct value.

**Also fix (narrow):** the existing phaseout applies the $100k cap BEFORE the tier % (`min(pension,$100k)×tier%`), under-excluding pension > $100k MFJ inside a band. Correct form: `min(pension×tier%, chartMax)`. Agrees with current results for pension ≤ cap (e.g., the $100k example stays $25k), only changes the >$100k-in-band corner.

**Personal exemptions:** NJ $1,000 regular per filer (+spouse if MFJ) + **$1,000 each age 65+**. Subtract from NJ taxable income (currently `stateDeduction: .none` applies none). 65+ MFJ couple = $4,000.

**Status: DONE — built, TDD-tested, independently reviewed, full suite green. Commit `b61ba23` on `1.9/drawdown`.** Implementation: `chartMax`/`tierPercent` accessors on `ExemptionLevel`; exclusion = `min((pension+IRA)×tier%, chartMax)`; `otherRetirementIncomeExclusion: Bool` flag (NJ-only) gating the unused-exclusion spill onto other income (other = remaining taxable − earned, where earned = `.consulting`); NJ personal exemptions via a `postExemptionDeduction` applied AFTER the income-gated bands. Reviewer recomputed all values to the penny vs NJ-1040 Worksheet D; engine and `stateTaxBreakdown` mirror agree (`StateTaxConsistencyTests` green); TaxsimOracle NJ fixture unchanged. **Follow-up (minor, latent):** a future direct caller of `calculateStateTax(income:forState:...)` that omits `postExemptionDeduction` would silently drop NJ exemptions — all current production callers route through wrappers, so not a live bug; consider consolidating so it can't be dropped. Original findings retained below.

---

## 2026-06-18: NJ tax-completeness audit — Worksheet D (Bob) + broader NJ gaps; scope decision for 1.9 PENDING

**Status: SUPERSEDED by the scope decision above (2026-06-18).** Findings retained for reference.

**Trigger:** Tester Bob (on shipped 1.8.7 build 55, profile ages 69 & 68) challenged our NJ position, citing **NJ-1040 Worksheet D (Other Retirement Income Exclusion)**. Verified: **Bob is right.**

**What NJ models today** (verified [StateTaxData.swift:1566-1633](RetireSmartIRA/StateTaxData.swift:1566)): progressive brackets 1.4%→10.75%; `socialSecurityExempt: true`; pension+IRA exclusion as `steppedPhaseoutByFilingStatus` + combined cap (the 1.9 phaseout work); age-62 gate; `hsaContributionsTaxableForState: true`; safe harbor. That is the entire NJ surface — everything below is NOT modeled.

**Confirmed / likely gaps, by retiree $ impact:**
1. **NJ IRA basis** (NJ-1040 IRA Worksheet / Worksheet C, General Rule) — NJ never allowed a traditional-**IRA** contribution deduction, so withdrawals have NJ basis and only the **earnings** portion is NJ-taxable; we tax the full withdrawal. Biggest dollar error. IRA-specific (401(k) deferrals were NJ-excluded since 1984 → fully taxable, no basis). Needs a new **IRA-basis input** → bigger design item.
2. **Other Retirement Income Exclusion — Worksheet D** (Bob): unused pension exclusion spills onto interest/dividends/cap gains, gated on **total income ≤ $150k AND earned income ≤ $3,000** (NJ-1040 lines 15+18+21+22). Confirmed not modeled — we only exclude `.pension` + IRA/RMD ([TaxCalculationEngine.swift:516-563](RetireSmartIRA/TaxCalculationEngine.swift:516)), no $3,000 gate. Pure-logic fix.
3. **NJ personal exemptions** (NJ-1040 lines 6–13): $1,000 regular per filer/spouse **+ $1,000 each at 65+** + blind/disabled. `stateDeduction: .none` applies none → over-tax a senior couple by ~$4,000 of exemptions. Easy add.
4. **NJ medical-expense deduction** (line 31): expenses over **2% of NJ gross** (vs federal 7.5%) — frequently real for retirees w/ Medicare. Needs medical input.
5. **Property-tax deduction/credit** (Worksheet F): up to ~$18k senior deduction or refundable credit. Needs property-tax input.
6. **Tax-exempt interest, NJ reversal — CONFIRMED, already-tracked.** All `.taxExemptInterest` is treated as state-exempt for ALL states; out-of-state munis (which NJ taxes) are under-billed. Known gap with a plan: `TODO(v1.8.4)` at [DataManager.swift:473-481](RetireSmartIRA/DataManager.swift:473); full plan in `docs/.../2026-05-19-qualified-dividends-ltcg-state-tax-audit.md` (Bug #3). Needs a per-row issuer-state flag. (Verified 2026-06-18 once Bash recovered.)
7. **Capital gains — VERIFIED, not a bug.** The per-state `capitalGainsTreatment` / `CapGainsTreatment` flag is set in configs and stored in `StateTaxBreakdown` (TaxModels.swift:110) but is **never read in any tax computation** (no switch/case/if consumes it). So `.followsFederal` does NOT apply federal preferential LTCG rates at the state level — NJ gains are taxed at ordinary NJ bracket rates via `adjustedTaxableIncome`. The enum/label is **misleading dead code** (cleanup candidate), not an accuracy gap. Separately, whether cap gains / qualified dividends are correctly INCLUDED in state gross income is covered by the 2026-05-19 LTCG/state-tax audit — re-confirm there, not via this flag.
8. **Special Exclusion** (never-received-SS/Railroad) — niche, low priority.

**Tractable as pure engine logic (1.9 candidates): #2 Worksheet D, #3 personal exemptions, #6 tax-exempt interest.** Need new inputs (bigger): #1 IRA basis, #4 medical, #5 property tax.

**Docs to review with John:** NJ-1040 Worksheets A/C/D, Worksheet F, lines 6–13 / 15–22 / 31, Schedule NJ-DOP, and GIT-1 & GIT-2 bulletins.

**Rationale:** our entire target user is the NJ-style retiree; Bob's challenge surfaced a real gap, and the audit shows several more. Concede Worksheet D to Bob. **TODO when Bash is back:** verify #6 and #7 in code.

---

## 2026-06-18: 2.0 branch audit + product principle (single-year Scenarios/Tax Summary stay core; multi-year gets its own home)

**Audit finding (verified on `2.0/v2.0.1-path-3-polish`, the furthest 2.0 branch):** the multi-year Roth-optimization engine and Plan-B year-by-year UI are **substantially built and tested** (~27,500 lines; `MultiYearTaxStrategyEngine`, `OptimizationEngine` + DP spike, `ProjectionEngine`, `MultiYearStrategyManager`, full `Year*` UI suite; 43 new test files, ~163+ engine test cases). **But all three 2.0 branches are ~190 commits behind main** (branched ~2026-05-02, before the 1.8.x healthcare bundle, the ACA/Medicare engines that landed May 9–17, the SS-taxability + stock-gain fixes, the 26-state tax refresh, the 2026 config corrections). The engine was built against an **old tax engine**.

**Therefore the dominant cost of 2.0 is reconciliation, not greenfield:** forward-porting the 27k-line engine onto current main, whose 190 commits changed the exact tax-engine surfaces the multi-year engine consumes. Not built at all: plan history / year snapshots (only an `AccountSnapshot` stub), HSA full-account modeling, and the entire 2.1 decumulation set (brokerage, withdrawal-order). Revised shape of "2.0" = **expensive merge + finish plan-history + HSA + (2.1) decumulation**, not the old "3-4 weeks" estimate.

**Product principle (decision):** the existing **single-year "Scenarios" and "Tax Summary" tabs are core to the product and must NOT be replaced or removed by 2.0/2.1.** The multi-year tax + Roth-conversion planning capabilities are **additive** and need their own home — **possibly a brand-new tab** (e.g., "Multi-Year Plan") — sitting alongside the single-year tools, not on top of them. When the 2.0 reconciliation happens, verify the Plan-B UI augments rather than supplants Scenarios/Tax Summary.

**Implication for V1.9:** the small per-year income projector for V1.9's Medium IRMAA overlay overlaps conceptually with the stranded 2.0 `ProjectionEngine`. Build V1.9's projector **standalone and tiny on current main** — do NOT build V1.9 atop the 2.0 engine, which would drag the 190-commit reconciliation into a small feature. Reconciling 2.0 is a separate, deliberately-scheduled project; V1.9 does not depend on it.

**Rationale:** evidence over assumption (the audit corrected the "3-4 weeks" estimate the same way the healthcare-bundle audit corrected "1.9 is unbuilt"); and the single-year workflow is what users like Tim already value, so multi-year must extend the product, not replace its foundation.

---

## 2026-06-18: V1.9 = NJ phaseout + contained drawdown (1.8.8 folded in; "1.9" label reassigned)

**Decision:** No standalone 1.8.8. The next App Store release is **V1.9**, combining (a) the NJ pension-exclusion AGI phaseout (former 1.8.8 scope) and (b) a new **contained pre-RMD drawdown projection** feature. One submission, one Apple review (the reason for folding: avoid two back-to-back reviews).

**"1.9" label reassigned.** Audit 2026-06-18 confirmed the original "1.9 features bundle" (ACA subsidy, Medicare plan-type, contribution levers, Reduce-AGI dashboard, ScenarioWarningEngine, AGI strong types) **never shipped as 1.9** — it landed incrementally inside 1.8.2–1.8.7 and is live now (wired in DashboardView; ~80 Swift Testing cases across ACASubsidyEngineTests/MedicareCostEngineTests/ScenarioWarningEngineTests/ContributionLeverTests/StateTaxHSATests/AGITypesTests; config keys `acaSubsidy2026`/`medicare2026`/`contributionLimits*` in tax-2026.json). Minor spec deltas only: the two-panel cost-spike chart was simplified (reuses existing acaSubsidyChart + irmaaTierChart), and the marginal-sensitivity "+Medicare/ACA effects" second figure was dropped. Since no 1.9 ever reached users, the version slot is free and is assigned to the drawdown feature. The old spec [docs/superpowers/specs/2026-05-01-1.9-features-bundle-design.md] is now historical (header note added).

**Contained drawdown scope (V1.9):** planned annual withdrawal / target-spending input for pre-RMD years; balance drawn down year by year at the growth rate; after RMD age take `max(planned, RMD)`; balance-over-time graph; 40-year horizon; single inflation input; pro-rata household split. Lives in the **RMD Calculator tab, display-only**. Does NOT touch Scenarios or Tax Summary (verified: `growthRate`/`projectBalance` not consumed there; those tabs use current-year `calculatePrimaryRMD()`). Legacy planning is the only adjacent system sharing the projection machinery — decide whether drawdowns propagate there. Open seam: optionally show projected IRMAA/ACA exposure per year by reusing the already-shipped `MedicareCostEngine`/`ACASubsidyEngine`. Traditional-focused; multi-bucket (brokerage/Roth) sequencing stays 2.0/2.1.

**2.0 (target unchanged, now informed by Tim Lucas 2026-06-18 email):** full decumulation engine — multi-bucket pro-rata vs sequential drawdown, withdrawal-order optimization, Roth-conversion optimizer, plan history (per docs/2.0-scope.md), budget-gap drawdown net of guaranteed income, inflation-indexed thresholds, and a **selectable objective** (Tim is explicitly NOT optimizing for max longevity value). Competitive benchmark: RetIQ (native iOS, on-device, $69.99, already ships tax-aware drawdown + 5 buckets).

**Rationale:** drawdown is a real feature deserving a minor bump and a marketable moment (1.9 can finally market the quietly-shipped healthcare bundle too); folding NJ avoids a second review; the big decumulation engine stays 2.0.

---

## 2026-06-14: NJ pension-exclusion AGI phaseout — tracked gap (Phase E follow-up)

**Decision:** Track and fix the New Jersey pension/retirement-exclusion AGI phaseout, currently not modeled. Surfaced by user feedback (Brian relaying his friend Bob's NJ review, 2026-06-14).

**The gap (engine *over*-exempts in the $100K–$150K window):** NJ is configured `pensionExemption/iraWithdrawalExemption: .partial(maxExempt: 100_000)` ([StateTaxData.swift:1538-1539](RetireSmartIRA/StateTaxData.swift:1538)) with no total-income gate. Real NJSA 54A:6-15 phases the exclusion out by **total NJ gross income**:

| Total income | MFJ | Single |
|---|---|---|
| ≤ $100,000 | 100% | 100% |
| $100,001–$125,000 | 50% | 37.5% |
| $125,001–$150,000 | 25% | 18.75% |
| > $150,000 | 0% (cliff) | 0% (cliff) |

**Worked example (the one Bob may test):** $50K dividends + $100K pension = $150K total, MFJ. App exempts the full $100K pension → taxes only the $50K dividends (~$805). Real NJ: 25% tier → only $25K pension excluded → tax on ~$125K (~$4,100). App under-taxes by ~$3,300.

**Two related NJ approximations also open (documented in code at [StateTaxData.swift:1530-1537](RetireSmartIRA/StateTaxData.swift:1530)):**
- Single filers use the MFJ $100K cap instead of the correct $75K.
- No $150K eligibility cliff (engine exempts even above $150K).

**Implementation note:** Phase E already added `.partialWithAGIPhaseout(maxExempt, singleStart, singleEnd, mfjStart, mfjEnd)` (CT/RI). NJ does **not** fit cleanly: NJ's phaseout is **stepped** (50%/25%), not linear, AND uses **different caps per filing status** ($75K single / $100K MFJ). A linear ramp $100K→$150K matches at the $125K midpoint (50%) but under-exempts across the $125K–$150K band (linear→0% vs NJ's flat 25%), and the single-value `maxExempt` can't carry the $75K/$100K split. Needs either a stepped variant or per-filing-status caps on the case.

**Rationale:** All three issues cause *under*-taxation (opposite of Bob's original over-tax complaint) but matter for accuracy; the engine API mostly exists, so this is a contained Phase E follow-up rather than new architecture.

**Release target (decided 2026-06-14):** Next release is **1.8.8** (an .8.x state-tax accuracy patch), NOT the 1.9 feature bundle. NJ phaseout is committed scope for 1.8.8. See `roadmap/current.md`.

---

## 2026-06-12: V1.8.7 iOS approved and live — both platforms on 1.8.7

**Decision (status):** iOS 1.8.7 (build 54) cleared App Review and is live. Both iOS and macOS now on 1.8.7.

**Rationale:** Closes the 1.8.7 review thread. Next release will be 1.9 or a data patch.

---

## 2026-06-10: TY2026 config audit — ACA/IRA/401k values were stale; annual refresh ritual needed

**Decision:** Fixed `tax-2026.json` + hardcoded fallback on `fix/aca-2026-config` (pushed): ACA FPL was 2024 guidelines (cliff showed $60,240/$81,760 instead of $62,600/$84,600), applicableFigures were placeholders (0/4/6/8% → Rev. Proc. 2025-25 2.10–9.96%), IRA $7,000→$7,500/+$1,100, 401k $23,500→$24,500/+$8,000. Suite green: 1,271/0. Ship vehicle TBD (1.8.7 data update or fold into 1.9).

**Rationale:** Found while auditing the article-3 CTA claim ("app models the ACA cliff") — the app had the same stale-FPL error as the article draft. **Process lesson: every November when IRS/HHS publish next-year figures (FPL, Rev. Proc. applicable %s, Notice COLA limits, Rev. Proc. HSA), do a full tax-config refresh audit — the 2026 file was seeded from 2025 and never refreshed.**

---

## 2026-06-09: Article #3 topic — Fred Lucha's suggestion (2026 MAGI → 2028 Medicare premiums)

**Decision:** Article #3 will cover how 2026 income decisions set 2028 Medicare premiums for people starting Medicare in 2028 — Fred Lucha's suggestion after reading the IRMAA article. Fred reviews the draft before publication and gets the first copy.

**Rationale:** Engaged-reader ownership strategy — acting on Fred's idea and involving him in the draft turns a responsive tester into a proactive promoter; the topic is also the natural actionable companion to the IRMAA article. Exchange saved at `drafts/emails/2026-06-09-fred-lucha-irmaa-article-exchange.md`.

---

## 2026-06-10: Sequencing — ConvertKit setup before media outreach

**Decision:** Tomorrow's priority is ConvertKit email capture setup (triggered by article 3). Media/press outreach follows after ConvertKit is live.

**Rationale:** Email capture compounds on every future article and visitor; setting it up before outreach means any press-driven traffic builds the list from day one.

---

## 2026-06-08: Advisor market — open question, not yet a roadmap commitment

**Decision:** Treat the advisor market as an open strategic question requiring validation before any build commitment. Bryan Jepson's response (loves app, wants multi-client folders, wants web/screen-share access, asked about vision) is the strongest advisor signal to date but one advisor is not a market. Next step is a structured conversation with Bryan and 3–5 other advisors to test whether the gap is real and payable.

**Rationale:** Native Mac/iOS multi-client version is tractable (3–4 months, $50–90K) but should not redirect V2.0. Validate first.

---

## 2026-06-08: Outreach to Bryan Jepson — IRMAA article + advisor tool positioning

**Decision:** Sent Bryan Jepson the IRMAA article with a note framing RetireSmartIRA as a tool that sits with the advisor and client together to work numbers in real time — complementary to advisor strategy, not a replacement for it.

**Rationale:** Bryan is a strong retirement tax planning advisor; the pitch is that clients need both the advice layer and the analytical layer, and the app provides the latter.

**Next step:** Await Bryan's response. If positive, explore whether he'd refer clients or use it in client meetings.

---

## 2026-06-07: Articles section added to retiresmartira.com — ConvertKit at article 3

**Decision:** Add `/articles` section to retiresmartira.com (Next.js TSX pages, no CMS).
First article: IRMAA Brackets 2026. Nav link "Articles" added. ConvertKit email capture
deliberately deferred — add it when article count reaches 3.

**Reminder:** At 3 articles → set up ConvertKit free tier, add email capture form to
ArticleLayout bottom, update privacy policy.

**Spec:** `retiresmartira-website/docs/superpowers/specs/2026-06-07-articles-section-design.md`

---

## 2026-06-07: Google Search Console verified for retiresmartira.com

**Decision (status):** GSC property `https://www.retiresmartira.com` verified via HTML file
method. File `google88c45cac05ff1a4a.html` added to `public/` in the Next.js website repo
(`johnqp801/retiresmartira-website` on GitHub), deployed via Vercel auto-deploy.

**Website infrastructure confirmed:**
- Domain registration: Namecheap (account: johnqp)
- Hosting/deploy: Vercel (project: `retiresmartira-website`)
- Source: GitHub `johnqp801/retiresmartira-website` (Next.js, auto-deploy on push to main)
- DNS: Namecheap nameservers → Vercel

**Follow-up:** Check GSC on Wednesday June 10 for index coverage + first search query data.
See session `sessions/2026-06-07-google-search-console-setup.md` for full GA analysis and
what to look for on June 10.

**Rationale:** GA showed only 2 Google organic visitors in 28 days — GSC is needed to
diagnose whether the site isn't indexed or just isn't being clicked in results.

---

## 2026-06-07: V1.8.6 approved & live — both iOS and macOS

**Decision (status, not a choice):** 1.8.6 (build 51) cleared App Review and is live in the
App Store on both iOS and macOS. Both platforms now on 1.8.6.

**What shipped:** SS taxability fix (Pub 915 line-14 cap) + stock-gain-avoided double-count
fix (gross income, NII, 4 impact counterfactuals) + in-app review prompt (ReviewPromptManager,
value-event trigger, per-version gate) + TY2024/2025 tax configs + IRS golden-case test suite
(1,269 tests total).

**Rationale:** All three engine accuracy bugs found during real-2025-tax-return dogfooding;
bundled with review prompt to ship one release instead of two review queue waits.

---

## 2026-06-05: 1.8.6 release notes — Option B approved

**Decision:** Approved release-notes Option B ("Accuracy Improvements") for 1.8.6.
Text: "Improved Social Security taxability calculations for scenarios where benefit amounts
are modest relative to other income / Refined how charitable stock donations interact with
net investment income and MAGI — more accurate IRMAA tier and NIIT projections / Added
'Rate RetireSmartIRA' in Settings for easy App Store reviews."
**Rationale:** Forward-looking, specific enough to be meaningful to power users, does not
imply prior dishonesty. Saved to `drafts/release-notes/2026-06-05-1.8.6-release-notes.md`.

## 2026-06-05: Bundle SS fix + stock-donation fix + review prompt into 1.8.6

**Decision:** All work from this session (3 engine accuracy fixes + in-app review prompt +
IRS golden-case suite + TY2024/2025 configs) ships as one release, 1.8.6 / build 51.
**Rationale:** One submission, one review queue wait; all fixes are independent and
individually tested; review prompt was always planned as the next release anyway.

## 2026-06-04: ImprovMX API key rotated — ✅ RESOLVED (security)

**Decision (executed):** Rotated/revoked the exposed ImprovMX API key. The leaked
`sk_2edc0c…b7b1067` (live on a PUBLIC GitHub repo via committed memory files + the
`v1.8.5-build50` tag, confirmed HTTP 200) was deleted in the dashboard → verified dead
(401). A replacement `sk_c6e05…04406` was generated but immediately exposed in a shared
screenshot, so it was deleted too → verified dead (401). **Account now holds ZERO API
keys** (none needed — the original was a one-off alias-creation call). Leaked string
redacted from 3 memory session files (commit 5576940).

**Rationale:** A live secret on a public repo is an active leak; the only real fix is
revocation (working-file redaction and history rewrites don't neutralize copies already
public — a dead key does). Keeping zero standing keys removes the leak surface entirely;
generate one ad-hoc only when actually needed, and never screenshot/paste it.

## 2026-06-04: Reconciled `main` to shipped 1.8.5 — ✅ EXECUTED

**Decision (executed):** `main` now equals the shipped App Store code. New `main` = `c45327f`
(on origin) = the `v1.8.5-build50` tree (v1.8.5 / build 49) + latest memory. Old main's V2.0
planning docs preserved on `archive/v2.0-planning` (local + origin). `feature/multi-year-planning`
deleted; old tip kept as `backup/feature-myp` (local). Force-pushed `main`; fully reversible via
`git checkout -B main archive/v2.0-planning && git push --force-with-lease`. See
`reference/git-topology.md` "Post-reconciliation state."

**Rationale:** `main` was a 207-commit-stale orphaned V2.0-planning fork with no app release and
no memory; the live app lived only on a tag. Now `main` is the canonical shipped line again.

## 2026-06-04: Plan to reconcile `main` to shipped 1.8.5 (SUPERSEDED — see entry above; executed)

**Decision:** Adopt a concrete plan to make `main` equal the shipped App Store code and
retire the confusing branches — but **do NOT execute yet** (user wants to think first; this
session changed nothing in git). When ready, the steps are: (1) rescue the newest
`.claude/memory/` commits off `feature/multi-year-planning` — they exist nowhere else and
are unpushed; (2) point `main` at the `v1.8.5-build50` tree + memory on top; (3) archive
`main`'s 10 V2.0-planning-doc commits to an `archive/v2.0-planning` branch (roadmap links to
those docs — preserve, don't delete); (4) force-push `main` (safe — solo dev), then delete
`feature/multi-year-planning`.

**Rationale:** Releases shipped from worktree branches/tags and were never merged back, so
`main` (1f43de2, May 4, reports v1.8.0) is an orphaned V2.0-*planning* fork with no app
release and no memory. The current branch `feature/multi-year-planning` is NOT release work —
it's an ancient 1.1/build-14 experiment missing ~37k lines vs shipped; its only value is the
newest memory. The App Store truth lives on the tag `v1.8.5-build50`. Full topology captured
in `reference/git-topology.md`. ⚠️ Until reconciled: never build/tag/submit from
`feature/multi-year-planning` — release only from worktree branches or the shipped tag.

## 2026-06-04: macOS 1.8.5 build 48 approved & live

**Decision (status, not a choice):** macOS 1.8.5 build 48 cleared App Review and is live in
the App Store. Both platforms now on 1.8.5. Closes the lingering Mac-review-queue thread.

## 2026-06-01: Always review the SHIPPED tree, never `main` (multi-model review hygiene)

**Decision:** When running external/multi-model code reviews, feed every model the same
*current shipped* tree — the release tag / active worktree (or a `git archive` of it),
explicitly NOT `main`. Confirm the model can see release-only files (e.g.
`ACASubsidyEngine.swift`) before trusting any "feature X is missing" finding.

**Rationale:** This session, Perplexity/ChatGPT concluded "ACA cliff is not built" — they
were correctly reading `main`, which is 204 commits / ~3 weeks stale and missing every
release 1.8.1→1.8.5 (incl. ACA). The shipped `v1.8.5-build50` tag has ACA built + tested.
The divergence was a stale-branch artifact, not analysis quality. Separately flagged:
`main` should be reconciled to the shipped line so it stops misleading clones/tools.

## 2026-06-01: In-app review prompts — value-event trigger, exploration-loop anchor (direction, not built)

**Decision (directional):** Add native `requestReview` prompting (none exists today on any
branch — all 5 ratings are organic). Trigger on a **value-event = the what-if exploration
loop** (scenario recalcs + Scenario↔TaxPlanning round-trips), NOT raw session counting and
NOT PDF export. Never fire mid-loop; defer to a calm moment (return to Dashboard / next
launch). Add a manual "Rate us" Settings button deep-linking to `?action=write-review`.
Version-gate; lean on iOS's built-in throttle.

**Rationale:** PDF export is rare even for the power user; the app's actual delight is the
iterative scenario↔tax-planning back-and-forth, so that's the satisfaction signal worth
catching. Session counting is a weaker proxy and partly duplicates OS throttling — keep
only a thin maturity floor. NOT finalized: release vehicle (leaning 1.8.6 off the shipped
tag, not 1.9) and the exact "payoff micro-moment" to count are still open. No code written.

## 2026-05-26 (very late evening): Phase E TY 2026 — MA $1M surtax + CT/RI AGI phaseouts

**Decision:** Complete Phase E by addressing the two non-moot items from the original audit. (HoH brackets and MFS routing were moot — the app's FilingStatus enum only has Single + MFJ.)

**Phase E Step 1 (`ea407a0`):** Convert MA from flat 5% to 2-bracket progressive 5%/9% modeling the constitutional 4% Millionaire's Tax surtax on income >$1M. Same $1M threshold for single + MFJ (constitutional amendment specifies no doubling).

**Phase E Step 2 (`0d9057f`):** Engine API change — added `.partialWithAGIPhaseout(maxExempt, singleStart, singleEnd, mfjStart, mfjEnd)` case to `ExemptionLevel` enum. Threaded `filingStatus` through `applyRetirementExemptions`. Phaseout ratio applies to the exemption FRACTION (not just cap) to correctly model CT's "100% below threshold, ramping to 0%" rule. Setting `start == end` produces cliff behavior (RI).

**Per-state config updates:**
- CT pension exemption: `.none` → `.partialWithAGIPhaseout` (75K-100K single linear, 100K-150K MFJ linear)
- RI pension + IRA exemptions: unconditional `.partial(50K)` → cliff at $107K/$133.75K AGI

**Initial test failure caught a logic bug:** original implementation applied phaseout to the $ cap only, not to the exemption fraction. Re-implemented to apply ratio to `min(incomeAmount, maxExempt)`. CT linear midpoint test then passed correctly.

**Engineering rigor:** Required updating 2 switch statements in `StateComparisonView.swift` (UI badge color + human-readable status text) for exhaustiveness. Both updated.

**Limitations still documented:**
- CT SS exemption phaseout — not modeled (`socialSecurityExempt: Bool` lacks AGI awareness)
- RI SS exemption FRA+AGI — not modeled
- Age-based conditions (RI requires FRA) — engine doesn't check age
- Other states with similar phaseouts not yet identified

**Reference:** `decisions/2026-05-26-50-state-bracket-freshness-audit.md`

---

## 2026-05-26 (late late late evening): Phase D TY 2026 fixes shipped — MS, OH, IN, KY, NC

**Decision:** Apply Phase D corrections for the 5 "ahead-of-schedule" flat-rate states. Under Path 1, most were already on TY 2026 statutory rates — but MS needed the actual rate cut, OH needed a structural change (new zero-bracket), and KY/NC needed std deduction refresh.

**Phase D applied (`221235b`):**
- MS: rate 4.4% → 4.0% (HB 531/2022 statutory)
- OH: **STRUCTURAL** — flat 2.75% → 2-bracket (0% on $0-$26,050; 2.75% above) per HB 96. Materially fixes overstatement for low-income OH retirees.
- IN: verified no-change at 2.95%
- KY: std deduction MFJ bug fix ($3,360 → $6,540, 2× per-person); rate 3.5% verified. Pension exclusion $31,110 kept conservatively (TODO verify HB 146 $41,110 bump)
- NC: std deduction $12,750/$25,500 → $13,000/$26,000

7 pinning tests added. **All passed.**

**FINAL Combined Phase A+B+C+D totals: 20 states corrected to TY 2026, 41 pinning tests.**

| Status | Count |
|---|---|
| TY 2026 actuals applied | 20 |
| TY 2025 latest (CA only) | 1 |
| TY 2026 verified no-change | 1 (MO) |
| Deferred to Phase C2 | 5 (NE, NM, WI, VT, OR) |
| Originally CURRENT | ~14 |

**Phase D unlocks an important fix:** Ohio's $26,050 zero-bracket means typical low-income OH retirees ($20K-$26K) now correctly pay $0 state tax instead of having every dollar taxed at 2.75%. That's a material accuracy improvement.

**Reference:** `decisions/2026-05-26-50-state-bracket-freshness-audit.md`

---

## 2026-05-26 (late late evening): Phase C TY 2026 fixes shipped — MN, ME, DE, SC, WV (+5 deferred)

**Decision:** Apply 5 high-confidence TY 2026 corrections (MN, ME, DE, SC, WV); defer 5 to Phase C2 where primary-source verification needed (NE, NM, WI, VT, OR); verify MO no-change.

**Phase C applied (`d5bcb42`):**
- MN: bracket refresh +2.37% (MN DoR press release)
- ME: bracket refresh (Maine Revenue Services PDF)
- DE: std ded $3,250/$6,500 → $5,700/$11,400 (HB 89 statute)
- SC: **MAJOR restructure** — 3-bracket (0/3/6.3) → 2-tier (1.99/5.21) per H.4216 (March 2026)
- WV: new 5-bracket schedule from 5% cut signed June 2026, retroactive Jan 1

**Why defer NE/NM/WI/VT/OR:**
- NE: top 5.20%→4.55% confirmed, but lower brackets show non-monotonic data from agent (likely error)
- NM: MFJ thresholds need NM PIT-1 primary source
- WI: code thresholds may already be MORE current than agent's research (suspicious)
- VT: agent couldn't parse primary VT PDF; secondary sources could be off
- OR: lower brackets and std ded approximate; top thresholds statutory and confident

Better to defer than ship uncertain data. Phase C2 should be a focused per-state primary-source verification pass.

**Combined Phase A+B+C totals:** 15 states corrected to TY 2026, 34 pinning tests, 7 tests added in this Phase C cycle. Federal already TY 2026; CA on TY 2025 (latest CA FTB published).

**Reference:** `decisions/2026-05-26-50-state-bracket-freshness-audit.md` (now with Phase A+B+C tables, deferred-state details, and Phase C2 scope)

---

## 2026-05-26 (late evening): Phase B TY 2026 fixes shipped — HI, CT, AR, MD, RI

**Decision (continuing Path 1):** Apply TY 2026 corrections for the 5 high-severity non-structural states identified in the audit, per the Path 1 policy adopted earlier today.

**Phase B applied (`379aa99`):** Five bracket/rate/exemption corrections from verified primary sources:
- HI: Act 46 widened brackets (12 thresholds updated)
- CT: bottom 2 rates 3%→2%, 5%→4.5% (missed 2024 reform)
- AR: top rate 4.4%→3.9%, new 0% first bracket, std ded bump
- MD: new 6.25%/6.50% top brackets, std ded rule changed to flat $3,350/$6,700
- RI: bracket thresholds refreshed, pension exclusion $0→$50K

12 new pinning tests added. Verified passing on iOS Simulator.

**Phases A + B combined deliver:** 10 states corrected to TY 2026 with 22 pinning tests preventing silent regression. Federal already on TY 2026. CA on TY 2025 (most recently published).

**Engine limitations now documented in code comments per-state** for future Phase E work (AGI phaseouts, HoH brackets, MA $1M surtax, MD county tax).

**Remaining phases queued:**
- Phase C: 11 MEDIUM 1-yr-stale states (WV, MO, MN, VT, OR, WI, ME, NE, DE, SC, NM)
- Phase D: TY policy edge cases (IN/KY/NC/OH ahead-of-schedule)
- Phase E: Engine API for granular filing statuses + AGI phaseouts (HoH, MFS, MA surtax)

**Reference:** `decisions/2026-05-26-50-state-bracket-freshness-audit.md` (full triage + per-phase scope, now updated with both A and B sections)

---

## 2026-05-26 (evening): State tax data — Path 1 policy adopted + Phase A TY 2026 fixes shipped

**Decision (Path 1 policy):** Going forward, `StateTaxData.swift` aims for **TY 2026 actuals where published; latest published (TY 2025) elsewhere, with explicit per-state vintage** in code comments. Refresh quarterly as remaining states publish TY 2026 (most progressive states publish Sep/Oct of TY).

**Rationale:** User direction "100% correct for TY 2026." Federal already TY 2026; state engine needs to align. Path 1 is the only honest approach — projecting unpublished state brackets introduces estimation errors worse than admitting some states aren't out yet.

**Phase A applied (`ac883ce`):** Five structural/rate corrections to LA, KS, MT, ND, MI from verified primary sources:
- LA: progressive → flat 3% (HB 10)
- KS: 3-bracket → 2-bracket (SB 1)
- MT: was wrongly modeled as flat — actually 2-bracket; HB 337 reduced top to 5.65%
- ND: was wrongly modeled as flat — actually 3-bracket with $0 first bracket
- MI: rate corrected 4.05% → 4.25%

10 new pinning tests added. Sources cited per-state in code comments.

**Phases queued:**
- Phase B (~2 hrs): HI, CT, AR, MD, RI — high-severity bracket/rate refresh
- Phase C (~2 hrs): 11 medium 1-yr-stale states (WV, MO, MN, VT, OR, WI, ME, NE, DE, SC, NM)
- Phase D: TY policy edge cases — IN/KY/NC/OH (using TY 2026 scheduled but officially TY 2025 actuals differ)
- Phase E: MA $1M surtax + HoH brackets (engine API change required)

**Recurring task:** Set up quarterly `/schedule` agent to re-run the audit (Jul/Oct 2026, Jan 2027).

**Press claim impact:** "All 50 states · 2026 IRS limits" now defensible at federal level. State claim should soften to "TY 2026 where published, latest TY 2025 elsewhere" until most states publish in fall 2026.

**Reference:** `decisions/2026-05-26-50-state-bracket-freshness-audit.md` (full triage + per-phase scope)

---

## 2026-05-26: CA bracket data refresh (TY 2023 → TY 2025) + scoped 3 follow-up gaps

**Decision:** Fix `RetireSmartIRA/StateTaxData.swift` California `single` and `married` bracket thresholds to TY 2025 (CA FTB Schedule X / Y). Patch shipped on `feature/multi-year-planning` as `b9d6413`. Update tests with new expected tax values, and add pinning tests for the MFJ case the user surfaced.

**Rationale:** UI screenshot from John showed MFJ bracket boundaries at $21K/$49K/$78K/$108K/$137K/$698K — those are TY 2023 single brackets doubled. Code was three inflation cycles stale. CA users were seeing wrong "room before next bracket" and inaccurate Roth conversion sizing recommendations. Standard deduction was already at TY 2025 — only brackets had drifted.

**Source verified:** 2025 Form 540 Tax Rate Schedules, CA FTB (`https://www.ftb.ca.gov/forms/2025/2025-540-tax-rate-schedules.pdf`) via independent research-agent triangulation against official FTB 2025 Form 540 instructions.

**Three follow-up gaps logged for separate work** (see `decisions/2026-05-26-CA-bracket-freshness-audit.md` for full detail):
1. **HoH brackets missing** — CA Schedule Z is meaningfully different from Single/MFJ; current `StateTaxConfig.progressive(single:, married:)` API doesn't model HoH at all. HoH filers map to married brackets (wrong).
2. **MFS bracket mapping wrong** — CA Schedule X covers Single AND MFS, but engine maps MFS → married brackets. MFS filers see ~half the rate they should.
3. **50-state bracket freshness audit needed** — If CA was 3 years stale, other states may be too. Press kit claims "All 50 states · 2026 IRS limits" — federal is true, state engine not uniformly current. Dispatch research-agent audit before next press push.

**Process change scoped:** Annual January checklist task to audit state tax data against newly published TY brackets. No such cadence currently exists — that's why this drifted unnoticed.

**Branch hygiene:** Fix lives on `feature/multi-year-planning`. **Must cherry-pick to `1.8.4/incremental` (or next release branch) before next App Store submission** — CA users on currently-shipped 1.8.4 still see TY 2023 brackets. Severity: moderate (off by ~10-12% in marginal-rate display at certain incomes; not illegal calculations). Suggest 1.8.5 patch release rather than waiting for 1.9.

---

## 2026-05-25: First press outreach wave — credibility-ladder approach, three pitches in flight

**Decision:** Launch first press outreach with Karsten Jeske (Early Retirement Now), Fritz Gilbert (Retirement Manifesto), and Chris Mamula (Can I Retire Yet?) as the opening wave. Deferred Christine Benz / WSJ / NYT-tier targets until coverage at Tier 1 (Substacks/FIRE blogs) and Tier 2 (niche podcasts) compounds first.

**Rationale:** Each piece of coverage makes the next pitch easier — "as featured in" lines and lifted quotes ladder up. Direct pitch to summit targets without prior coverage is the harder ask. Three pitches per wave is the right pace; more in flight than that dilutes attention to each thread.

**Follow-up schedule (hard dates):**
- **Tue 6/2 or Wed 6/3** — day-7 bump to any non-responder
- **Mon 6/8** — day-14 final email, then mark cold permanently (no third email)

**Operating rule:** Three-touch maximum (send → bump → final → dead). The Bryan Jepson "warm-but-stalled" pattern is the trap — don't let said-yes-three-times-never-followed-through prospects occupy mental space that should go to new outreach.

**Audience tailoring:** Pitches were not copy-paste. Karsten = analytical/edge-cases vocabulary, Fritz = warm-storyteller framing, Chris = ecosystem/tool vocabulary. Hooks dropped per audience (no "950+ tests" for Fritz; ACA-cliff-at-401%-FPL only for Karsten; 2027-subscription-pricing hook only for Chris). Don't carry template language across audiences in future waves.

**Reference:** `sessions/2026-05-25-press-outreach-karsten-fritz-chris.md` (verbatim from parallel Claude chat session)

---

## 2026-05-21: iCloud cross-device sync via NSUbiquitousKeyValueStore, opt-in by default

**Decision:** Add iCloud cross-device sync as a future feature (v1.9 or v2.x). Backend: `NSUbiquitousKeyValueStore` (iCloud Key-Value Store). Default state: **off** (device-only mode preserved as the default experience). Build behind a `PlanStorage` abstraction protocol so the backend can be swapped without touching app code.

**Rationale:** App is already UserDefaults-shaped, so KVS is the natural drop-in (almost identical API). Worst-case data footprint over the next 5–10 years projects to ~550 KB — well inside the 1 MB / 1,024-key KVS budget — given the explicit fidelity assumption below. Opt-in default preserves the absolute "your data stays on this device" promise for users who want it; sync becomes an explicit, transparent choice. TriSTAR triangulation: Claude proposed the approach, ChatGPT and Gemini independently concurred, and ChatGPT caught an overclaim about Advanced Data Protection coverage of KVS that I retracted.

**Fidelity assumption this depends on:** Position-level brokerage tracking only (no tax-lot history). If this changes — i.e., the app ever needs to handle tax-lot-aware cap gains projection on real portfolios — the brokerage data alone could approach 800 KB and KVS becomes the wrong long-term backend. At that point: revisit, migrate to CloudKit + Core Data/SwiftData. Roadmap currently does not include lot-level fidelity.

**Privacy commitment change:** With sync off, the existing "your data never leaves your device" promise stands unchanged. With sync on, the promise becomes: *"Your data syncs privately through your own Apple iCloud account so you can use RetireSmartIRA across your Apple devices. It is never sent to us, never sold, never used for profiling, and never processed on our servers. RetireSmartIRA does not operate servers and cannot view your data. Sync is protected by Apple's iCloud security."* The phrase "end-to-end encrypted" is **not** to be used until Apple's docs are verified to confirm `NSUbiquitousKeyValueStore` falls under Advanced Data Protection's covered categories.

**Spec:** `.claude/memory/roadmap/icloud-sync.md`

---

## 2026-05-13: Adopt persistent project memory in `.claude/memory/`

**Decision:** Create `.claude/memory/` with subfolders for decisions, drafts, sessions, and roadmap. Update CLAUDE.md to instruct Claude to read it at session start.

**Rationale:** Three+ prior sessions failed because Claude had no recall of earlier LinkedIn drafts, screenshot picks, or roadmap conversations. In-repo persistent memory eliminates that failure mode and survives across worktrees and machines.

---

## 2026-05-13: Final App Store description opens with "Plan your retirement taxes like a pro — and stay on top of them all year long"

**Decision:** Use the year-round-usefulness framing instead of "in minutes, not hours" or "in hours with powerful what-if scenario planning."

**Rationale:** "In hours" alone sells against the app (sounds slow). "Powerful" is filler. Year-round framing captures real value and reads neutral.

---

## 2026-05-13: App Store description names CPA workload explicitly

**Decision:** Second sentence of description reads "RetireSmartIRA answers the questions that take a CPA hours to model."

**Rationale:** Concrete, name-drops the actual problems users search for (Roth, SS, RMDs, IRMAA, ACA), and implies speed without using a time-promise that could be undercut.

---

## 2026-05-12: V1.8.1 ships with 11 fixes from Ron Park's May 11 feedback

**Decision:** Build 37, marketing version 1.8.1. F1-F5 correctness bugs + U1-U6 UX changes. Submit to App Store same day.

**Rationale:** Real beta feedback from Ron (sub-$1M MFJ retiree, ACA-focused user) surfaced 5 correctness issues and 6 UX gaps that were ship-blockers. All committed, full test suite passes, archived.

---

## 2026-05-12: Defer 17 BLOCK items to 1.8.2

**Decision:** Items beyond Ron's feedback (analyst critique L1-L4, higher-earner additions H1-H5, deferred items D1-D6, code quality C1-C3) move to a separate 1.8.2 release per `docs/superpowers/specs/2026-05-12-1.8.2-incremental-design.md`.

**Rationale:** 1.8.1 must ship today for Apple review. 1.8.2 is a coherent next release, ~19 days of effort, with its own coverage matrix.

---

## 2026-05-12: ACA cliff messaging emphasizes REPAYMENT, not "lost subsidy"

**Decision:** Cliff warnings now say "Crossing the cliff means **repaying** advance credits of ~$X/yr at tax time" instead of "costs $17K/yr in lost subsidy."

**Rationale:** Ron's most important catch. Advance Premium Tax Credits are received during the year; crossing the cliff triggers full repayment THIS year, not just future-year subsidy loss. No repayment cap under post-IRA 2022 rules.

---

## 2026-05-12: Scenarios sections reorder to AGI-reducers-first

**Decision:** New order: Pre-tax Contributions → Charitable → Withdrawals → Roth Conversions. Step numbers renumber dynamically based on visible sections.

**Rationale:** Tells a coherent strategic story whether the user is a MAGI-minimizer (Ron's case) or a Roth-maximizer. You'd never want to set conversions before knowing your contribution-adjusted starting point.

---

## 2026-05-09: V1.7 release notes do NOT use "Honesty Improvements" framing

**Decision:** Reject "Honesty Improvements" or any wording implying prior version was dishonest. Use "Accuracy Improvements," "Refinements," or "Enhanced Calculations."

**Rationale:** Undermines trust in prior releases. Existing users would read "we lied to you before."

---

## 2026-05-02: V2.0 engine locked on `2.0/multi-year-engine` branch with 951 passing tests

**Decision:** Phase 0+1 + 3 OptimizationEngine bug fixes (IRMAA Medicare count, RMD basis timing, ACA gating) locked. UI work (Plan B) is the next major chapter.

**Rationale:** Engine math is correct and external-Gemini-reviewed. Building UI on top of an unstable engine is wasted work.

---

## 2026-05-14: V1.8.1 build 37 LIVE in App Store

**Decision:** Released to both iOS and macOS App Store.

**Status change:** Submitted (2026-05-12) → Approved → Released.

**Outreach completed same day:**
- Email sent to Tim (retired military beta tester) per draft at `drafts/texts/2026-05-13-tim-military-features.md`
- Email sent to Fred (retired 3PL executive beta tester) per draft at `drafts/texts/2026-05-13-fred-executive-outreach.md`

**Why this matters:**
- 1.8.1 is the first release with the full 1.8.1 launch refresh (military features, ACA cliff repayment warnings, Scenario Builder reorder, 11 marketing screenshots, etc.)
- Website at retiresmartira.com is already live with matching positioning
- This is the moment promotion can begin — every paid click now lands on a working install button
- Real-user feedback from this release will shape 1.8.2 scope decisions

---

## 2026-05-17: V1.8.2 Phase 2 plan-review design calls

Plans for Phases 1-3 written by parallel writing-plans agents. Phase 2 agent surfaced four design questions; all resolved post-review:

- **A — L3 spouse-heir gating:** Gate heir-bracket card on non-spouse heir (return EmptyView for spouse). Rationale: 10-year drain assumption is wrong for spouses, who can roll over and use their own RMD timeline.
- **B — L3 "per $X" display:** Hybrid — live amount when `scenarioTotalRothConversion >= $10K`, illustrative `$100K` constant otherwise. Rationale: most useful when user has a real plan, still informative when they haven't set one.
- **C — L4 widow lifetime tax delta:** Ship coarse 0.85 single-filer approximation with tooltip noting "V2.0 will model year-by-year through multi-year engine." Rationale: avoids over-engineering 1.8.2; sets up V2.0 anticipation; multi-year engine already solves this properly.
- **D — L2 taxable-brokerage gate:** Add `hasTaxableBrokerage: Bool` toggle to user profile (default false); gate L2 0% LTCG card on it. Adds ~0.25d to Phase 2 (revised to ~8d). Rationale: clean signal, unlocks future surfaces, removes "card always visible" awkwardness.

**Phase plans status:**
- Phase 1 (`2026-05-17-1.8.2-phase-1-ron-segment-polish.md`): 9 tasks, ~57 steps, ~5-6d actual (vs 7.75d estimate)
- Phase 2 (`2026-05-17-1.8.2-phase-2-analyst-critique.md`): 8 tasks, ~53 steps, ~8d with decisions A-D
- Phase 3 (`2026-05-17-1.8.2-phase-3-higher-earner-and-housekeeping.md`): 8 tasks, ~70 steps, lighter than spec implied (most items are surfacing existing engine math)

**Build number verified:** Currently at 38; Phase 3 release task bumps 38→39 and marketing version 1.8.1→1.8.2.

---

## 2026-05-17: V1.8.2 phasing — Option A (strategic-bundle phases)

**Decision:** Phase 1.8.2 work into 4 strategic bundles, each shippable independently:

1. **Phase 1 — Ron-segment polish** (~7.75d): R1-R4 + D1-D3. Closes 1.8.1 smoke-test deferrals.
2. **Phase 2 — Analyst critique** (~7.75d): L1-L4 + D4 + D5. Higher-earner credibility lift.
3. **Phase 3 — Higher-earner additions + housekeeping** (~4.5d): H1, H2, H4 + C1-C3. Natural 1.8.2 release cut here (~20 days / ~4 weeks total).
4. **Phase 4 — SEP IRA** (~6d): H6. Candidate for 1.8.3 if 1.8.2 needs to ship faster (purely additive, no migration risk).

**Rationale:** Each phase tells a coherent story. Phase 1 first to close 1.8.1 commitments on low-risk surfaces. Phase 2 second when engine-touching modeling work is added (after Phase 1 testing rigor established). Phase 3 third because H1/H2/H4 are surface-level viz on existing engine math + C1-C3 are pure refactors. Phase 4 last/separable because SEP is the largest single-item scope with the most novel integration.

**Status:** Spec is now complete (decisions resolved, SEP added, phasing approved). Next: generate implementation plan via writing-plans skill, then execute via subagent-driven development.

---

## 2026-05-17: V1.8.2 spec — four pending decisions resolved + SEP IRA folded in as H6

**Decisions:**
- **D4 — Default planning horizon 85 → 95:** ✅ Yes (change default). Rationale: audience self-selects for longevity-conscious planning; conservative default was silently penalizing SS-delay recommendation. Preserve existing user values on migration.
- **D5 — Open Social Security cross-reference tooltip:** ✅ Yes (surface in close-call cells, within ~$50K). Rationale: reinforces integrative positioning; Open SS is a single-purpose calculator, not a competitor.
- **H3 — State residency timing optimization:** ❌ Defer to V2.x. Rationale: multi-year sequencing problem; belongs alongside V2.0 SS↔Roth cross-decision UI. Optional lightweight 1.8.2 callout possible (not BLOCK).
- **H5 — Withdrawal sequencing playbook:** ❌ Defer to V2.x. Rationale: multi-year problem already solved by V2.0 engine; 1.8.2 version would create user confusion at upgrade. Optional tooltip possible (not BLOCK).

**SEP IRA folded in as H6:** Full 9-part scope (account model, contribution limits, contributions, distributions, RMDs, Roth conversion, inherited, UI, tests) added to spec at `.worktrees/1.8.1-incremental/docs/superpowers/specs/2026-05-12-1.8.2-incremental-design.md`. Effort: 6 days (range 4-8).

**Net effect on 1.8.2 scope:**
- 16 BLOCK items (was 17 ? )
- ~25.75 days (~5 weeks) — was ~19 days (~4 weeks)
- SEP IRA can split into 1.8.3 sub-release if needed

**Status:** Spec is now decision-complete. Next: phasing the 16 items into 3-4 coherent shippable phases, then generating implementation plan via writing-plans skill.

---

## 2026-05-15: Add SEP IRA support to V1.8.2 scope

**Decision:** SEP IRA (Simplified Employee Pension) accounts must be supported in V1.8.2 with full tax treatment, not just as a label.

**Why now:** The current app supports Traditional IRA and Roth IRA, but a meaningful population of retirees/pre-retirees have SEP IRAs from prior self-employment or small-business ownership. Without SEP, the app forces these users to either misclassify their account as "Traditional IRA" (which works for withdrawal/RMD math but loses contribution-side semantics) or skip the app entirely. For 1.8.2's higher-earner / executive-segment focus (per existing 1.8.2 spec), SEP IRA is table stakes.

**Adds to 1.8.2 spec:** Insert as a new BLOCK item alongside the existing 17 (L1-L4, R1-R4, D1-D6, H1-H5, C1-C3 framework). Could fold into the H-series (higher-earner additions) since SEP is most common in self-employed high earners.

---

## SEP IRA — full tax-treatment scope

To say "SEP IRA is supported" with the right depth, V1.8.2 needs to address all of:

### 1. Account model
- Add `IRAAccount.type = .sepIRA` enum case alongside `.traditional`, `.roth`, `.inherited`
- Most withdrawal/RMD logic mirrors Traditional IRA — could share code paths with a single `isTraditionalLike` predicate
- Storage / persistence migration: existing users have `.traditional` and `.roth` — new `.sepIRA` is purely additive, no migration needed

### 2. Contribution limits (2026)
- SEP IRA limit: lesser of **$70,000** or **25% of compensation** (2026 figures, IRS Rev. Proc. 2025-19 and 2025-33)
- For self-employed: 25% calculation uses NET earnings (after deducting half of SE tax + the SEP contribution itself, requiring iterative or closed-form calc)
- For W-2 employees of own S-corp: 25% of W-2 wages
- This is meaningfully more complex than Traditional IRA's flat $7K limit — need helper to compute max SEP contribution given user's self-employment income

### 3. Tax treatment — contributions
- Contributions are deducted from business income on Schedule C (sole prop) or as a business expense on the S-corp's books → reduces AGI
- Treat same as Traditional IRA contributions in scenarioTaxableIncome calculation, but bucket separately in UI ("SEP Contribution" vs "Traditional IRA Contribution")
- Above-the-line deduction status: yes, deducted from gross income to arrive at AGI

### 4. Tax treatment — distributions
- Withdrawals taxed as ordinary income, same as Traditional IRA
- Subject to 10% early-withdrawal penalty before age 59½
- State tax: same treatment as Traditional IRA distributions (most states tax identically; states with retirement-income exemptions usually apply them equally)
- Verify MilitaryRetirementExemption table treats SEP IRA correctly (probably doesn't apply — military retirement exemption is for military pensions specifically, not all retirement income)

### 5. RMDs
- RMDs required starting at age 73 (or 75 under SECURE 2.0 depending on birth year)
- Use Uniform Lifetime Table (same as Traditional IRA)
- Combine with Traditional IRA RMD calculations for the household total — SEP IRA balance is added to Traditional IRA aggregate for RMD calculation purposes (this is IRS rule, not optional)
- Verify `RMDCalculationEngine` treats SEP as Traditional-equivalent

### 6. Roth conversion eligibility
- SEP IRA can be converted to Roth IRA — same rules as Traditional → Roth
- Pro-rata rule applies if user has any after-tax basis in Traditional or SEP IRAs
- Scenarios builder slider for Roth conversion should accept SEP IRA as a source account

### 7. Inherited SEP IRA
- Same beneficiary rules as Traditional IRA: SECURE Act 10-year drain for non-eligible designated beneficiaries, spousal continuation options, etc.
- Pre-RBD vs post-RBD decedent treatment same as Traditional IRA
- Verify `RMDCalculationEngine.calculateInheritedIRARMD` accepts SEP IRA accounts (probably already does if it's account-type-agnostic for traditional-like types)

### 8. UI changes
- Account creation form: add "SEP IRA" as a selectable account type
- Account display: show as "SEP IRA" with traditional-like styling (orange/yellow rather than green for Roth)
- Scenario Builder contributions section: add "SEP Contribution" row if user has self-employment income
- IRMAA / ACA / QCD logic: same treatment as Traditional IRA throughout
- Tax projection breakdown: show SEP contributions in the pre-tax deduction line
- /features and App Store description: mention SEP IRA support in retirement-account coverage list

### 9. Tests
- `IRAAccount.sepIRA` round-trip persistence
- Contribution limit calculation for various SE income levels
- RMD aggregation: SEP + Traditional IRA combined balance feeds aggregate RMD
- Roth conversion from SEP behaves identically to Roth conversion from Traditional
- Inherited SEP IRA 10-year drain matches inherited Traditional behavior
- State tax treatment for SEP distributions (verify CA, NY, TX, FL coverage at minimum)

### 10. Plan/spec deliverable
When implementation kicks off, generate `docs/superpowers/plans/2026-05-XX-sep-ira-support.md` with task breakdown. Could be 4-8 tasks depending on whether we share code paths with Traditional or duplicate.

---

**Status:** Logged for 1.8.2 implementation. Do NOT implement during this session (1.8.2 work hasn't started; user is on 48h pause; needs spec finalization first). Resume when full 1.8.2 planning session happens.

**Suggested sequence:** add SEP IRA to the existing 1.8.2 spec at `docs/superpowers/specs/2026-05-12-1.8.2-incremental-design.md` as item H6 or a new SEP-series, before kicking off implementation.

---

## 2026-06-26 — PV display made CPI-consistent; optimizer-objective CPI deferred behind IRMAA-cliff hardening

**Context:** The "Present value" toggle on the Multi-Year Plan tab discounted NOMINAL projected dollars (8% nominal growth, 2.5% CPI) at a 3% REAL rate — a units mismatch that under-discounted and made PV figures rosier than correct.

**Decisions:**
1. **DONE — display PV fixed.** Added `EngineMath.realPresentValue(_:yearsFromBase:cpiRate:realDiscountRate:)` = deflate by CPI to today's dollars, then discount at 3% real (combined Fisher factor `(1+cpi)(1+r)`). Wired into PlanComparison, PlanSummary, and HeirFrontierCoordinator's display factor. Optimizer untouched.
2. **DONE — toggle relabeled.** "Today's $" → "Future $" (it shows nominal future dollars); "Present value" now is the true today's-dollars view.
3. **REVERTED — optimizer-objective CPI discounting.** Making the optimizer objective CPI-consistent (~5.6% effective) was implemented then reverted: it destabilized the optimizer and broke the IRMAA safety-buffer guarantee — in the reference scenario it parked MAGI in the (cliff−$5k, cliff) dead zone in 4 years, most dangerously 2031 at $273,789, just $212 below the $274,001 cliff. Also drifted the Kitces widow reference scenario from >$40k to $38.2k.

**Rationale:** The objective's discount rate is an internal ranking tuning parameter, not user-visible. The current 3%-real-on-nominal is conservative and keeps IRMAA buffers intact; "consistency" gained nothing user-facing while breaking a real quality guarantee.

**Future work (ordered):**
- (a) Add a HARD optimizer rule: never intentionally land MAGI within ~$5k below an IRMAA cliff (the cliffBuffer dead zone) unless the user explicitly disables the buffer. Today buffer respect is "soft" (relies on cliff candidates usually winning); the CPI experiment proved it can be violated.
- (b) ONLY AFTER (a) ships, make the optimizer objective CPI-consistent (use `realPresentValue` in `discountedInHorizon` / `computeObjectiveCost` / inner objective / rationale / Result, threading `cpiRate`; update SSClaimNudge call sites). Re-baseline goldens then.

---

## 2026-06-26 — External CPA-style tax review (ChatGPT + Gemini + Perplexity), reconciled against source

Three independent AI "CPA" reviews of the V2.0 tax constants/logic, reconciled per the CLAUDE.md rule (cite source before agreeing/rejecting) and web-verified against primary/CMS/IRS sources.

**Net result: exactly ONE real engine error across all three reviews.**
- **FIXED:** IRMAA Part D Tier 4 surcharge 83.50 → 83.30 (`tax-2026.json` + `TaxYearConfig.hardcoded2026` + test re-baseline). Confirmed via CMS 2026 Part D schedule. Commit on `2.0/heir-objective`.

**Flagged but verified CORRECT (no change):**
- IRMAA Part D Tier 3 = $60.40 (Perplexity's $57.00 was wrong).
- QCD 2026 = $111,000 (Perplexity's $108,000 was wrong; IRS Notice 2025-67 confirms $111k; also UNUSED by the multi-year optimizer — no `.qcd` lever).
- IRMAA Part B field stores TOTAL premium; engine computes surcharge = partB - $202.90 (`TaxCalculationEngine.calculateIRMAA`). Not a double-count.
- OBBBA senior bonus is below-the-line (folded into stdDed; MAGI uses federalAGI, not taxableIncome) — does NOT reduce IRMAA/ACA/NIIT/SS MAGI. Correct.
- ACA MAGI == IRMAA MAGI (identical addback); SS provisional income uses 0.5×gross SS (no double-count).
- RMD born-1959 → 73 (correct per IRS proposed regs); IRMAA tier matching `>= threshold` with "+1" values is correct for tiers 1-4 (off by $1 only at the exact tier-5 entry — negligible).

**Doc-only / negligible (not actioned):** RMD pre-1949 returns Int 70 not 70½ and doesn't split July 1 1949 — zero projection impact (that cohort is age 76+ in 2026, already taking RMDs). Optional born-1959 "proposed regs" user-facing disclosure.

**Real limitation logged (see [[multi-year-muni-magi-gap]] memory):** the multi-year engine models tax-exempt (muni) interest as 0 in ALL MAGI-sensitive calcs (IRMAA, ACA, SS provisional). Consistent, not an ACA-specific bug, but UNDERSTATES IRMAA/ACA MAGI and SS taxation for users with muni interest. v2.x enhancement.

---

## 2026-06-27 — V2.0 UI launch scope locked (focused Roth/tax-optimizer release, NOT a full planner)

After a scope reconciliation against the live engine + a multi-round product debate, the "full V2.0 UI" launch bar is **locked**. Decision: **ship V2.0 as a focused, honestly-scoped Roth-conversion / RMD / IRMAA / ACA / survivor / heir-tax optimizer — NOT a full household decumulation planner — and do NOT gate the Apple release on V2.1.**

**Rationale:** most of the "competitive completeness" wishlist is already built (engine outputs or shipped UI); the genuine gaps (brokerage cost-basis, withdrawal-order optimizer) were already promised to Tim as 2.1; gating the whole release on the largest/most-uncertain scope risks shipping nothing and concentrates QA/rework (2.1 engine changes would disturb already-tested 2.0 UI). Trust comes from not over-claiming, not from completeness.

**IN scope (V2.0 launch bar):**
1. Editable Year-1 levers + **full observation tracking** (expand `observeUpstreamChanges()` past the current 2 fields; surface the 6 DataManager levers + off-plan indicator + `resetYear1ToEngineOptimal`).
2. Charts (conversion ladder, account balances over time, heir-frontier curve, **growth** sensitivity bands — labeled growth-sensitivity, never "risk/odds").
3. Advanced assumptions sheet (growth, CPI, pvRealDiscountRate, **terminalLiquidationTaxRate** [flagged required], per-spouse horizon, withdrawal-ordering **preset** — surface the existing `WithdrawalOrderingRule`, not an optimizer).
4. CPA-briefing PDF with assumptions + **Limitations** section + year-by-year table.
5. Riders off existing engine outputs: survivor (`widowStressDelta`) + SS-nudge (`ssClaimNudge`) callout banners, richer year table, threshold/cliff surfacing (`ConstraintHit`).
6. Explicit **Assumptions & Limitations** surface (UI + PDF); narrow non-full-planner positioning.
7. **4a — ONE narrow engine change:** credit the terminal taxable balance to heirs at step-up (`HeirFrontierCoordinator.swift:53` + `PlanComparison.heirsKeep` both currently omit `endOfYearBalances.taxable`). `heirKeeps = terminalRoth + (terminalTrad - heirTax) + terminalTaxable`. No optimizer/loop touch (step-up = no gain to tax at death); fixes the heir-frontier's biggest trust risk.

**DEFERRED to V2.1:** 4b — capital-gains/NIIT tax on *lifetime* taxable withdrawals (NOT narrow: prerequisite is fixing the LTCG/QDI-taxed-as-ordinary Path A simplification, and it hits the optimizer's per-year loop and interacts with conversion decisions); full brokerage cost-basis; withdrawal-order **optimizer**. Label the lifetime taxable-drawdown treatment as simplified in UI + PDF.

**DEFERRED indefinitely:** Monte Carlo / multi-factor sensitivity (positioning mismatch — product is a tax optimizer, not a ruin-probability tool; `SensitivityBands` doc already forbids "risk/odds" labeling).

**Trust-story principle:** disclaimers mark the *edge of scope*, not the *reliability of what's inside* (which is CPA-reviewed). Positioning copy must avoid "complete/full retirement income optimization."

Work lands on `2.0/heir-objective` (worktree `.worktrees/2.0-reconcile-engine`). Spec: `docs/superpowers/specs/2026-06-27-v2.0-ui-launch-scope-design.md`.

---

## 2026-06-27 — §6.1 Year-1 editing: SHARED one-source-of-truth model + workflow + engine-lever reality

**Decision (workflow, user-stated):** The Multi-Year Plan tab's Year-1 IS the single-year scenario (SHARED `DataManager` fields — one source of truth, NOT independent overrides). Workflow: the multi-year plan proposes an optimal Year-1 → the user adjusts it (in Scenarios OR the Multi-Year tab; same fields) for real-life reasons → the engine **pins Year-1 and re-optimizes years 2+** around the user's choice → an off-plan indicator shows divergence from the unconstrained optimum → "Reset to optimal" snaps back. Rationale: matches the existing engine architecture (no new storage), lowest risk, coherent "plan proposes / scenario disposes / plan reflects" mental model. This does NOT violate the additive/never-modify-Scenarios constraint (we don't touch Scenarios code; the underlying scenario data was always shared/editable from multiple places).

**Engine-lever reality (durable, verified in `OptimizationEngine.swift` ~L335-360):** In v2.0 the multi-year optimizer **only honors the Year-1 ROTH CONVERSION** override (`locked[baseYear] = .rothConversion(year1Primary+year1Spouse)`). Year-1 **withdrawal and QCD overrides are NOT honored** by the multi-year projection (the greedy candidate sweep never emits them; there is no `.qcd` LeverAction). Therefore §6.1's live, plan-affecting Year-1 lever = **Roth conversion only**. Do NOT surface editable withdrawal/QCD in the Multi-Year tab (they would silently fail to change the projection — misleading). Withdrawal/funding control ("I don't want to use my cash/assets this way") is the **2.1 decumulation/withdrawal-order work**, not v2.0. Single-year Scenarios tab still models a year's withdrawals as before.

**Off-plan metric:** compare `currentResult.lifetimeTaxFromRecommendedPath` vs `engineOptimalResult.lifetimeTaxFromRecommendedPath` (the user-visible lifetime-tax figures). Do NOT expose the internal `OptimizationEngine.Result.totalObjectiveCost` on the manager (would be an engine surface change). 4-state bands (delta = current − optimal): On plan <$1K; Near optimal $1K-$10K; Off plan $10K-$25K; Significantly off plan >$25K.

**Deferred to v2.x backlog (NOT §6.1):** **Year-end finalization / rollover** — once a tax year is finalized, lock that year's actuals, advance the base year, and re-optimize the plan forward. A lifecycle feature; capture and revisit post-launch.

Plan: `docs/superpowers/plans/2026-06-27-v2.0-ui-plan-3-editable-year1.md`.

## 2026-06-28: "Consider Legacy Planning" toggle now gates the Multi-Year tab's heir analysis

**Decision (user-chosen):** When Profile's "Consider Legacy Planning" (`enableLegacyPlanning`) is OFF, the Multi-Year Plan tab shows an owner-lifetime-only view: hide the heir frontier (chart + table), drop the "What heirs keep" comparison row, follow the owner-optimal path, and omit both from the CPA briefing. **Rationale:** the Multi-Year path was consuming heir inputs unconditionally, so the toggle had no effect there (user-reported); flipping it off should remove heir-focused content app-wide for consistency. Shipped commit `22666e9` on `2.0/heir-objective` (1129 tests). Implementation: `PlanComparisonView.showHeirs`, `CPABriefingModel.includeHeirs`, frontier compute skipped while off and recomputed on re-enable, and `activePath` ignores the heir-weighted frontier path when off so a stale heir-optimized plan can't leak through.

## 2026-06-28: Per-chart plain-language "Explain this chart" popover slotted for 2.0.1 (fast-follow, NOT V2.0)

**Decision (user-chosen):** Add an on-demand popover that explains each Multi-Year chart in plain language when the user taps an info affordance. **Slotted for 2.0.1, shipped right after V2.0 is live in the App Store** — explicitly NOT a V2.0 launch blocker (scope stays locked; don't slip the release). **Rationale:** strong fit for the non-pro audience and the "make the tax math legible" positioning, but additive polish that wants its own review pass and shouldn't gate launch. **Design constraints agreed:** generate the commentary **deterministically from the chart model** (same pattern as `PlanComparison.headline()` / `PlanSummary.headline`), NOT via an LLM — keep it offline, free, instant, reviewable, and adaptive to the user's actual numbers. Shape: one reusable popover + a per-chart commentary function; start with the Balances chart to prove the pattern, then extend to tax-impact, ladder, and threshold-map charts. Needs a dedicated review (auto-generated financial commentary that is subtly wrong is worse than none).

## 2026-06-28: User-set per-spouse mortality + survivor-penalty modeling slotted for 2.1 (backlog)

**Decision (user-chosen):** Capture as a single 2.1 feature bundle (NOT V2.0): (a) let the user set a per-spouse death/mortality age, (b) model a mid-plan filing-status switch (MFJ up to the widow year, single thereafter) with the deceased spouse's SS/pension stopping and the survivor inheriting balances, and (c) a survivor-penalty optimization or sensitivity view (today the penalty is only *measured*, not optimized for). **Why surfaced:** user asked whether they could set one spouse to a shorter lifespan and minimize the widow tax. **Current state (verified):** the per-spouse "plan through age" steppers ([AdvancedAssumptionsSheet.swift:21-26]) only set horizon length and the engine runs to `max(primaryEndYear, spouseEndYear)` ([OptimizationEngine.swift:318]) — nothing models mid-plan death (filing status is a fixed input, [ProjectionEngine.swift:863]). The only early-death surface is the automatic `WidowStressTest` (higher SS earner dies day 1, single-filer throughout, not user-tunable; [WidowStressTest.swift:7]); the file already calls out the v2.1 two-segment projection ([WidowStressTest.swift:13]). Surfaced in the UI only via the dismissible "Survivor tax impact" banner (threshold >$1,000; [SurvivorStressBanner.swift]). **Sub-finding (smaller, fixable sooner):** dismissed insight banners have no in-app un-dismiss control — `restoreDismissedInsights()` exists but is unwired ([MultiYearStrategyManager.swift:251]); dismissals persist across launches, so a dismissed Survivor banner can't be brought back without clearing the (demo) UserDefaults suite.

## 2026-06-28: Tax-payment tracker + safe-harbor coverage view slotted post-launch (2.1-ish, backlog)

**Decision (user-chosen):** Add the ability to record **actual** tax paid (quarterly estimates sent, out-of-pocket tax on a Roth conversion, withholding on an inherited-IRA withdrawal) and a **coverage view** showing how close paid-to-date is to (a) full estimated liability, (b) the 90% current-year safe harbor, and (c) the 100/110% prior-year safe harbor. NOT a V2.0 item (it lives in the single-year/Dashboard area, out of scope for the `2.0/heir-objective` branch). **Scoping agreed:** build the **annual coverage + safe-harbor-percentage** version first (small/medium, high value, low risk) as an enhancement to the existing Quarterly screen, NOT a new tab; treat true per-quarter Form 2210 annualized-income-installment timing (deadline-by-deadline penalty) as a separate, harder, later step. **Current state (verified — most of the engine already exists):** safe-harbor amounts federal+state, both methods, including the 110%-if-prior-AGI>$150k switch ([DataManager.swift:1748, 1801, 1778]); prior-year federal tax / state tax / AGI inputs ([IncomeDeductionsManager.swift:22-27]); per-source withholding totals ([IncomeDeductionsManager.swift:35]); Roth-conversion withholding incl. the Q4-counts-evenly trick ([DataManager.swift:1410], [QuarterlyTaxView.swift:967]); and a 1,181-line `QuarterlyTaxView` with safe-harbor card + per-quarter *recommendations*. **The gap:** all of that is forward-looking recommendation; there is no ledger of *actual* payments made and no paid-vs-targets progress view. Keep it framed as an estimate / not a filing (data-entry burden + accuracy expectation; nudges the app toward record-keeping).
