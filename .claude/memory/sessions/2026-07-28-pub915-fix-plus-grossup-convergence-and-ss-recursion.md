# 2026-07-28 (session 2) — Pub 915, gross-up convergence, SS recursion, cash-flow funding, IRMAA MAGI, TAXSIM band

**All six fixes are DONE and MERGED TO `main`.** V2.3 was merged first, then the three ordered engine fixes, then the cash-flow/copy fix, then the IRMAA-vs-ACA MAGI split and the TAXSIM 50%-band oracle coverage.

---

## State at end of session

**All SIX fixes are MERGED TO `main` @ `2d89141`.** Branch and worktree deleted (fast-forward merge, nothing lost).

- **`main` @ `2d89141`**, now **39 commits ahead of `origin/main`, unpushed.**
- Merge order: V2.3 merged first (`7fedf7f`), then the six engine/UX fixes on top:
  - `1f006a0` Pub 915 50% tier
  - `6247f01` gross-up fixed-point convergence (Aitken)
  - `59f8f04` Social Security recursion through the gross-up
  - `c5d3fcc` cash-flow tax funding + funding-feasibility copy
  - `8a8f481` IRMAA MAGI vs ACA MAGI split + cliff-buffer overshoot repair
  - `2d89141` TAXSIM 50%-band oracle coverage
- **Verification on merged `main`:** 1,545 Swift Testing tests in 259 suites + 503 XCTest, 0 failures. iOS `BUILD SUCCEEDED`. TAXSIM oracle 26/26.

**Not yet done:** push `main`, version bump, release notes, submission.

## 1. Pub 915 50%-tier (`1f006a0`)

One line at `TaxCalculationEngine.swift:834`: `min(excessOverFirst, ssIncome * 0.5)` → `min(excessOverFirst * 0.5, ssIncome * 0.5)`.

IRC §86(a)(1) taxes the lesser of one-half of benefits or **one-half of the excess** of provisional income over the base amount. Limb (B) was missing its halving.

**Three independent confirmations, not one reading:**
1. The adjacent 85%-tier branch already halves its band.
2. The existing 85%-tier tests spell out Pub 915 line 14 as `min(0.5*benefits, 0.5*(34,000-25,000))` — the same halving.
3. An un-halved excess taxes benefits at a **full dollar per dollar**, a rate no tier of §86 provides. A property test caught exactly this (`delta 250.0 <= 212.51` failed).

**Two tests pinned the wrong value and were corrected** with worksheet arithmetic in the comments:
- `RetireSmartIRATests.swift:206` ($2,000 → $1,000)
- `VADisabilityTests.swift:88` ($5,000 → $2,500) — its own subject (VA out of provisional income) is unaffected; the contrast if VA leaked in is ~$17,000 vs $2,500.

**New `SocialSecurityPub915Tests`** (7 tests): statutory worked examples both filing statuses, a case where limb (A) binds so the benefits cap can't be dropped later, continuity at threshold2, and domain-wide properties — benefits taxation is non-decreasing in other income, rises at most 85 cents per dollar, never exceeds 85% of benefits.

### NEW FINDING worth acting on

**The TAXSIM-35 differential oracle has ZERO fixtures in the 50% band.** All 10 of its SS-bearing scenarios land in the 85% tier (provisional $50,000–$150,000). The oracle structurally could not have caught this. Closing that gap needs a POST to the NBER TAXSIM server via `tools/taxsim-refresh` — an external call, so it was NOT done unilaterally. **Recommend adding 50%-band fixtures (single $25k–$34k, MFJ $32k–$44k) next cycle.**

---

## 2. Gross-up convergence (`6247f01`)

The 3-pass budget was not merely "insufficient" — measured residuals were **larger than previously recorded**:

| state | conversion | unfunded tax |
|---|---|---|
| FL | $600K | $7 |
| CA | $300K | $4,131 |
| MN | $600K | $11,092 |
| CA | $600K | **$13,894** |

(prior note said worst was $8,344). These households are solvent with ample assets left; the shortfall is tax reported but never removed from any account, so ending balances were overstated by the full amount.

**Perf mattered and was measured, not assumed.** Naively raising the budget to 40 cost **37%** on the hot path (MFJ 35-year persona 11.44s → 15.67s against a 15s budget) because the loop runs per year per optimizer candidate.

**Solution: Aitken delta-squared extrapolation after two Picard steps.** The tax map is piecewise LINEAR in `dW`, so between bracket boundaries the extrapolation is *exact*, not approximate. Converges in one round (two evaluations, fewer than the old three). Same persona now **11.53s**, indistinguishable from baseline, while converging to under a penny. Clamped into `[0, availableTrad]`; a bad landing is absorbed by the next round's plain Picard steps.

**One test legitimately rebaselined:** `InfeasibleYearEngineTests` previously asserted this exact scenario carried **more** than $1 of residue so the gate had to look past it. That scenario was leaving $4,131 unfunded. It now asserts funded-to-the-dollar. The `assetsExhausted` half of the gate is still load-bearing and still covered by the starved / whole-IRA-conversion / unsellable-dollars cases in that same suite.

---

## 3. Social Security recursion (`59f8f04`)

`taxableSS` was computed once before Step 7 and never revisited, so the gross-up withdrawal's own effect on benefit taxation was dropped. Now a closure over `otherIncomeForSSTax + dW + saleGain`, evaluated **inside** the fixed point.

Understatement measured (single, age 70, whole tax funded from traditional):

| state | benefit/mo | conversion | taxable SS | total tax |
|---|---|---|---|---|
| FL | $4,000 | $40,000 | $7,222 | $2,037 |
| CA | $4,000 | $40,000 | $9,038 | $2,762 |
| VT | $4,000 | $40,000 | $11,888 | $4,762 |
| MN | $4,000 | $40,000 | **$11,888** | **$4,809** |

Larger than the previously recorded worst ($6,367 / $1,741). **Zero on large conversions** (benefits already at the 85% ceiling, delta identically zero) — which is exactly why no reference scenario moved.

### The MAGI trap, resolved and verified

MAGI = AGI + non-taxable SS + tax-exempt = (non-SS income) + gross benefits + tax-exempt. It is **algebraically invariant to the taxable/non-taxable split**. So `reportedMagiAddback` falls by exactly what `reportedAGI` rises by.

**Verified empirically across a 36-profile grid: reported MAGI moves by exactly the change in the gross-up withdrawal and by nothing else.** That is correct — MAGI has been post-gross-up since the A3 fix and the household really did withdraw more. The benefit-split component contributes zero. Pinned by a test that recovers gross benefits from each run's own reported figures and requires the funded and outside-money runs to agree.

---

## 4. Cash-flow tax funding + feasibility copy (`c5d3fcc`)

Resolves the **Roth/HSA-only false-infeasibility** carried over from the prior session. Reproduced first, and it is worse than that note recorded.

**The indefensible case:** $30,000 pension, **ZERO expenses**, $2M Roth, $585 tax. Every year flagged "cannot pay its modeled tax" while $30,000 of unspent income evaporated annually. The prior note's sharpest case had $60k expenses; removing expenses makes it worse.

**Confirmed: expenses have zero effect on the gate.** Probes at $60k / $0 / $40k give byte-identical shortfalls of $585 and $1,185.

**Sharpest statement of the bug:** Roth was already an acceptable source for GROCERIES but not for TAX. At $60k expenses the engine drains Roth by exactly $30,000 for living costs in the same year it declares $585 of tax unfundable.

### The fix (engine)

Unspent income (income less expenses, less anything reinvested into a bucket) now counts toward funding the year's tax. **Measurement only, never a source that moves a balance** — that surplus was already being discarded by the projection, so there is no balance to debit. Two consequences, both deliberate:
- Ending positions untouched (pinned by a test asserting traditional falls by exactly conversion + gross-up).
- Because the gate also requires `assetsExhausted`, this can only change years that were **already** flagged. Every other year is byte-identical.

**This is NOT the Roth cascade the prior session warned against.** A household whose income falls short of expenses has no surplus and is still flagged; that case is handled by copy, not by raiding the balance the product exists to build.

Note the prior session's blanket "do NOT extend the cascade to Roth" was reasoned from "the household would pay from pension income," which holds when surplus exists but not in the $60k-expense case where the engine is already spending Roth. The distinction now lives in the code.

### The fix (copy) — chosen by John from 3 options, "model-limit, neutral"

Banner was: "N years cannot pay their modeled tax" / "they do not describe an outcome this household can reach" / "balances the household could never have held". All false for a solvent household. Now:

> **Tax funding not modeled in N years**
> In these years the modeled tax is more than the taxable and traditional balances can cover. This plan funds tax only from those accounts, so paying from Roth savings or from cash on hand is not modeled. The totals above leave that tax unfunded. [N later year(s) build on those balances, so their figures carry the same gap.]

Per-row explanation and the downstream-year note got the same treatment (`V2Disclosures`). **Two tests pin the ABSENCE of the accusation by phrase** ("cannot pay", "could never have held", "household can reach", "could not actually have reached", "not fully funded"), so it cannot return through an innocent rewording.

### Rebaselines

Three copy tests. Plus one engine test restructured, worth knowing: `noTraditionalWithAmpleTaxableIsNotInfeasible` had its $150,000 pension cancelled against $150,000 of expenses. Its whole purpose is to exercise the `sellableForTaxes` half of the gate, and with a surplus it would no longer reach the gate at all — it would have silently stopped testing anything. `makeInputs`/`makeAssumptions` in that file gained an `expenses:` parameter.

Verified end to end: surplus case now 0/3 years flagged and `isFullyFunded == true`; no-surplus case still 3/3 flagged, with the new model-limit copy.

---

## 5. IRMAA MAGI vs ACA MAGI (`8a8f481`)

**They are different statutory quantities and the difference is exactly the non-taxable half of Social Security.** The multi-year engine used ONE add-back for both.

- **IRMAA, 42 U.S.C. §1395r(i)(4):** AGI + tax-exempt interest (+ §135/911/931/933 exclusions). **NO benefit add-back.**
- **ACA PTC, IRC §36B(d)(2)(B):** AGI + excluded foreign earned income + tax-exempt interest + **the portion of benefits not included under §86**.

IRMAA MAGI was therefore overstated by the non-taxable benefit portion for every household collecting SS: **$20,704 too high** at a $3,000/mo benefit with a $30,000 conversion; $19,472 at $4,000/mo. Not display-only — the optimizer reads it via `.limitToIRMAA`.

**Corroboration:** the single-year engine already had it right (`DataManager.irmaaMagi` = `estimatedAGI + taxExemptInterestTotal`; its ACA MAGI adds `nonTaxableSS`). The two engines disagreed about what IRMAA MAGI *is*.

`magiAddback` split into `irmaaMagiAddback` (tax-exempt only) and `acaMagiAddback` (+ nonTaxableSS). Only the ACA one tracks benefit taxation, so ACA MAGI stays invariant to the split while IRMAA MAGI correctly moves with it. `YearRecommendation.magi` is now the IRMAA basis.

### The latent bug it exposed

The optimizer's cliff candidates assume converting $X raises IRMAA MAGI by $X. **That held only because the wrong add-back cancelled the benefit-taxation feedback exactly.** Corrected, a conversion also drags benefits into taxation, so the candidate overshoots into the `cliffBuffer` dead zone it was aiming at. MFJ reference profile, year 2031: landed $213,471 against a $213,001 target, inside (213,001, 218,001). The objective cannot see this — the zone is below the threshold, so no surcharge is owed and the margin scores as free.

**Fixed by post-selection repair**, not a per-candidate preference. The preference approach was tried and **rejected on evidence**: it changes which amount wins → changes the next iteration's baseline → the greedy stops converging → a full extra fixed-point pass → MultiYearStrategyManager blew its 5s compute deadline (baseline 4.111s). The repair pulls the winner back by the measured overshoot, max 3 passes, only on affected years: **4.136s vs 4.111s baseline**. Keeps the original amount if it cannot clear, so it can never make a year worse.

---

## 6. TAXSIM 50%-band coverage (`2d89141`)

Six scenarios added (FL/CA/CO/NY/PA/NC, single + MFJ). `tools/taxsim-refresh` re-run against taxsim.nber.org with John's authorization; synthetic scenarios only.

**Being in the band is not sufficient, and the first draft got this wrong.** Low provisional income usually means the standard deduction zeroes the tax, so a scenario can sit squarely in the band and return $0 either way. Of six as first written, only ONE moved federal tax past the $200 tolerance; two returned $0 tax with and without the bug. Resized so the excess is ~half of gross benefits (where the error peaks), two using filers under 65.

**Verified by reintroducing the bug:** oracle drops to 21/26 with the five band scenarios failing at Δ +436/+360/+528/+530/+580. With the fix, 26/26.

Three independent sources agree: hand-computed Pub 915 Worksheet 1 predicted 930/1118/1316/580/730 for scenarios 21/22/24/25/26; TAXSIM returned 940/1118/1328/600/750; the engine matches TAXSIM on all 26.

Scenario 23 deliberately does NOT discriminate — it pins the benefits-cap limb (A). Scenarios 24 and 26 sit exactly ON the second threshold.

---

## Why almost nothing rebaselined

The earlier handoff predicted heavy rebaselining across ~13 suites. **Only one test moved.** Reason: the reference scenarios are built around large conversions and high balances, which either put benefits at the 85% ceiling (recursion delta = 0) or have ample taxable buckets so no gross-up fires. That is consistent with the narrow blast radius, not evidence the fixes are inert — the new tests prove the numbers move where they should.

---

## Open items

- **Push `main`** — now **39 commits ahead of origin**, unpushed.
- **Release notes** must cover V2.3 *and* all six fixes. Per CLAUDE.md: no "honesty"/"misleading" framing; "Accuracy Improvements"/"Refinements"; offer 2-3 wordings. The V2.3 MUST/MUST NOT list in the prior session note still applies, EXCEPT the Roth/HSA-only banner item, which is now fixed.
- **Version bump + submission** (both platforms). Next build = max across platforms + 1; 2.1.2 shipped as build 62.
- **Audit harness** (`2.2/display-audit-harness`) baselines will move; rebase onto the new `main`.
- **Annotate-then-rank** for infeasible strategies (from the V2.3 session): comparison columns are inflated by phantom funding with no feasibility marker, and `keepBestOfCandidates` ranks purely on objective cost.
- The 2.3 worktree `.worktrees/2.3-tax-funding-mode` still exists with its gitignored SDD ledger and review diffs; branch `2.3/tax-funding-mode` is merged and could be cleaned up if the ledger is not wanted.
