# 2026-07-27 — RMD chart axis fix, spouse/joint ownership fixes, HumbleDollar "Widow Tax" comment thread

Two shipped bug fixes on `root-workspace` (verified compatible with `main`, not yet merged/rebased), plus a long HumbleDollar comment-reply session for John's published "Widow Tax" article. One engine-verification task was interrupted mid-investigation and is NOT done — see Open Items.

## Bug 1: RMD projection chart x-axis label overlap (iOS)

**Report:** on iPhone, the top RMD bar chart's year labels overlapped into an unreadable smear at longer horizons.

**Root cause:** `RMDCalculatorView`'s "Projected Annual RMDs" chart plots a String category on x (`point.yearLabel`, e.g. `'29`), and Swift Charts' `AxisMarks` labels *every* category unless given an explicit subset. At 20/30/40-year horizons that's 20-40 labels crushed into ~300pt.

**Fix** (`RMDCalculatorView.swift`): `Owner.projectionAxisYears(currentYear:projectionYears:)` thins to round calendar years — every year (≤6y), every other year (≤16y), half-decades (≤32y), decades (40y) — matching the drawdown charts below it. Also drops the label on the **final** bar when thinning: Swift Charts centers a category label under its bar, so a label on the last bar overhangs the plot's trailing edge and renders as `…` (this is what turned the 30-year axis into `'30 '35 '40 '45 '50 …`). Extracted `chartYearLabel(_:)` so axis labels and bar categories can't drift apart.

**Verified on iPhone 17 simulator at all six picker horizons** (5/10/15/20/30/40) — screenshots confirmed clean labels, no ellipsis, no overlap.

**Tests:** `RetireSmartIRATests/RMDProjectionAxisTests.swift` (11 tests) — label count ceiling, in-window/ascending/no-duplicates, exact stride per horizon, the "never label the final bar" invariant, robustness across starting years, degenerate horizons (0/negative/1 year).

**Commit:** `026de86` — `fix(rmd-chart): thin projection x-axis labels to round calendar years`

## Bug 2: Spouse/joint IRA ownership — reported as "I added a spouse with an IRA and don't see the RMDs"

Investigation initially misdiagnosed the projections table as excluding the spouse — it doesn't; the table is `ScrollView(.horizontal, showsIndicators: false)` and the spouse's columns + household total were simply scrolled off-screen with no visible affordance. Caught this before reporting wrong info to John, by physically swiping the table sideways in the simulator. **Lesson for future sessions: verify horizontal-scroll UI by actually scrolling before concluding data is missing.**

While verifying, found a real, more serious bug: **a spouse-owned account with Enable Spouse OFF displayed an RMD of half the balance** ($900,000 IRA → "$450,000 Required Withdrawal") while the household total above it showed $0. Reproduced live in the simulator, then reverted.

**Root cause:** `spouseCurrentAge` / `spouseRmdAge` both `return 0` when `enableSpouse` is false (`ProfileManager.swift`). In `RMDCalculatorView`'s account breakdown, `0 >= 0` read as "RMD required," and `RMDCalculationEngine.lifeExpectancyFactor`'s past-the-table `?? 2.0` fallback (correct for ages >120) divided the balance by 2 for age 0.

User made a product decision via `AskUserQuestion` before the fix: (1) disallow "Joint" as an IRA owner entirely (an IRA has exactly one owner under IRS rules), grandfather existing joint accounts as counting toward the primary; (2) do NOT block turning off Enable Spouse when spouse/joint accounts exist — instead confirm and **reassign to primary, never delete** (John's own refinement of a stricter "block until deleted" proposal; reassign was judged better since destroying data to change a settings toggle is wrong).

**Three fixes shipped, all in `RMDCalculatorView.swift` / `AccountsManager.swift` / `AccountModels.swift` / `AccountsView.swift` / `DataManager.swift` / `SettingsView.swift` / `RMDCalculationEngine.swift`:**
1. **Engine floor:** `RMDCalculationEngine.calculateRMD` now returns 0 below the Uniform Lifetime Table's start age (70) — no caller can reach the 2.0 fallback with an unconfigured age. Fallback past age 120 is unchanged and still pinned by existing tests.
2. **`ownerRMDContext` returns nil** when an account names an owner with no configured profile; the breakdown row shows the balance + an explanation ("Turn on Enable Spouse...") instead of a number.
3. **Joint accounts price off the primary** (`AccountsManager.primaryOwners = [.primary, .joint]`), so they're no longer silently dropped from `calculateCombinedRMD()` (a 25% excise-penalty-bearing understatement).
4. **Owner picker gated:** `Owner.retirementOwnerOptions(enableSpouse:including:)` never offers Joint for retirement accounts; offers Spouse only when configured; always grandfathers the account's current owner so editing legacy data never blanks or silently rewrites the picker.
5. **Enable-Spouse toggle confirmation:** `SettingsView.enableSpouseBinding` + `AccountsManager.spouseAndJointAccountSummary()` / `.reassignSpouseAndJointAccountsToPrimary()` — turning the toggle off with spouse/joint accounts present shows a confirmation dialog ("N accounts totaling $X... Nothing is deleted") and reassigns to primary rather than stranding them. Verified end-to-end in the simulator (before/after dollar figures correct), then the user's real data was restored exactly (Rollover IRA = You, Spouse IRA = Spouse, Enable Spouse on).
6. **Table affordance:** `showsIndicators: true` restored on the combined projections table, plus a compact-width hint line ("↔ Swipe the table sideways for [Spouse]'s columns and the household total") so the hidden-columns problem that started this investigation doesn't recur for other users.

**Tests:** `RetireSmartIRATests/SpouseJointOwnershipTests.swift` (22 tests) — engine floor (age 0, every age <70, table boundaries unchanged, negative age), joint-account bucketing invariants, owner-picker option sets (no duplicates, grandfathering, gating), reassignment behavior (IRA + taxable accounts, summary accuracy), and the `ownerRMDContext` nil/non-nil matrix including an explicit "the $450,000 phantom RMD cannot be produced" regression test.

**Commit:** `364f1f4` — `fix(rmd): correct spouse and joint account ownership in RMD math`

## Verification against `main` (branch topology)

`root-workspace` was 40 commits behind `main` going into this session (main carries per-year expense overrides, local/city tax, state withholding mode — ~1,980 lines, unrelated to this work). Initial full-suite claims ("1,380 + 503 green") were **only valid against the stale base** and were corrected mid-session once this was noticed.

Verified properly: created a disposable worktree (`verify/rmd-on-main`), merged `main` into it, ran the full suite. **Result: 1,439 Swift Testing tests / 243 suites + 503 XCTest, 0 failures on the combined state.** Of the 7 files touched, only `DataManager.swift` and `SettingsView.swift` also changed on `main`, in unrelated regions (local/city tax field) — `git merge-tree` reports no conflicts. Worktree and verification branch were removed after confirming.

**Left for John to decide, not decided this session:** whether to rebase `root-workspace` onto `main` (linear history) or merge `main` in and keep the branch. Both are reversible pre-push. Neither has been done — `root-workspace` still sits 40 commits behind `main`, unmerged, unrebased.

## HumbleDollar "Widow Tax" article — comment-reply session

John's article published 2026-07-25 on HumbleDollar (his second placement there, after the July 4 HumbleDollar piece already in memory — [[download-driver-attribution]]). Argues the "widow tax" is real but inversely sized to income: costs the affluent couple *less* (Medicare surcharge shrinks with one enrollee), costs the $180K middle couple the most (~$8,500, senior-deduction phase-out + new IRMAA tier), and roughly doubles the effective rate at $90K via the Social Security torpedo even though the dollar cost there is smaller.

Drafted replies to essentially every commenter, iterating on tone based on live feedback:

- **Howard Rohleder** — rewrote per John's explicit request to open with "I read your piece, recommend it" rather than trying to one-up his AARP Tax-Aide anecdotes. Credited HIM for the year-of-death joint-filing mechanic rather than claiming it (caught and corrected a draft that had this backwards — Howard described it in his own referenced piece, not John).
- **Ormode** (pushback: "middle" isn't the real median) — conceded the point plainly rather than defending the label.
- **snak123** (detailed SPIA/Secure-Act-2.0 survivor plan) — iterated three times per John's feedback: first draft corrected his math before praising him (wrong instinct), second added a substantive question about the $75K single-filer senior-deduction threshold, third and final version per John's explicit call: **pure praise + a Forum-post suggestion, no correction at all** — reasoning being he stated a couple-level income and gave no info about the survivor's actual MAGI, so raising a doubt about a stranger's real plan in public, on incomplete information, would be presumptuous and borderline-advice.
- **Dan Smith** — agreed with his Roth-401(k)-for-modest-earners point, added the mirror-image caution (paying 24% now to spare 12% later is the trap).
- **Mike inLA** ("discuss financial changes, not widow tax") — agreed fully; his framing is sharper than the article's, said so directly.
- **Jerry Pinkard** (a survivor himself, self-critical about not converting sooner) — reframed his 90%→12% conversion + QCD-covers-RMDs as evidence the plan worked, precisely because he did it inside the joint-bracket window; deliberately did NOT mention SSA-44 redetermination since his own comment states SS+pension (not a 2-year MAGI lookback lag) drive his IRMAA tier.
- **Sanjib Saha** (OBBBA senior-deduction sunset, questioned the $8,500 middle-couple figure) — **DONE, resolved in a follow-up continuation of this session.** Built a temporary XCTest (`DataManager(skipPersistence: true)`, real `IncomeSource` rows, `.florida` to zero out state tax) reproducing Household B from the published article: couple $60K SS + $120K pension (MFJ, both 66) and survivor $30K SS + $120K pension (single, 66, the smaller SS check stops, ordinary income unchanged). 2026 run calibrated almost to the dollar against the published table (couple fed tax $17,148 vs. published $17,148; survivor $22,737 vs. $22,737; survivor IRMAA $2,885 vs. $2,885). Re-ran at `currentYear = 2029` (senior bonus expired, everything else identical since no bundled JSON exists past `tax-2026.json` so `loadOrFallback` holds 2026 brackets/thresholds): couple fed tax rises to $19,234, survivor to $23,162, survivor IRMAA **unchanged** at $2,885 (IRMAA runs on MAGI, not the deduction). Widow-tax gap: **$8,474 today → $6,813 post-2028**, not Sanjib's guessed "under $6,000." Cross-checked by hand against the 2026 MFJ/single brackets (couple's lost $9,480 deduction sits entirely in the 22% MFJ bracket → $2,085.60 more tax; survivor's lost $1,770 sits in the 24% single bracket → $424.80 more tax; both match the engine output exactly). Scratch test file deleted after use, repo left clean. Final reply sent the real numbers, credited Sanjib's direction, corrected the magnitude, and explained WHY the gap doesn't close further (bracket-rate mismatch on the two lost deductions) — see final text below.
- **Rick Connor** (praised the piece, mentioned writing his own follow-up inspired by commenter achnk53, raised "continuing impacts over time, not just year one") — engaged substantively rather than just thanking him: RMD divisor shrinks every year so the tax bill can climb for a decade on a flat portfolio, and IRMAA's 2-year MAGI lookback means a new widow's premium in year 1-2 still rides the couple's old joint income before the single-filer numbers catch up — a real "year one looks nothing like year three" mechanic none of the published case studies had to handle. Initial longer draft also tied his TaxAide clients to the article's $90K household (SS torpedo, thin cushion) and flagged divorce as related-but-distinct (no step-up in basis, different SS rules) — John cut that paragraph for a shorter final version, keeping the RMD/IRMAA-lookback point as the core and closing with a plain "look forward to reading it when you're done." Deliberately did NOT mention the app's multi-year engine even though it's the closest fit to "how does this evolve," since modeling a **mid-plan** filing-status switch is still 2.1 backlog, not built ([[survivor-mortality-2-1]]) — gesturing at an unbuilt capability would repeat the Tim/optimizer-objective mistake.
- **bbbobbins** (reframe: isn't this just the reversal of a "married bonus" rather than a widow-specific tax? singles never had the perks, plus higher per-capita living costs) — verified before answering rather than asserting from memory: grepped `TaxYearConfig.swift` and confirmed Social Security's combined-income thresholds are **not** doubled for MFJ ($25,000/$34,000 single vs. $32,000/$44,000 joint, not $50,000/$68,000 — a 1984 figure never inflation-indexed). Used that to give a nuanced agree: federal brackets and the standard deduction genuinely do double at these income levels (so losing them at widowhood is losing an earned-in bonus, as he says), but Social Security taxability was never doubled to begin with, which is part of why the article's $90K household takes its hit there rather than from bracket compression. Tied his equivalence-scale point back to the article's own footnote 4 (two people live at ~1.4x the cost of one, not 2x). Closed on "the label matters less than whether income still covers expenses," echoing the piece's actual thesis.
- Dave Melick, Chris & Steve Hensley, Heidi — shorter warm-thanks replies, drafted, not verified as sent.

**Consistent editorial position taken across the thread (John's instinct, confirmed repeatedly through this session):** don't mention RetireSmartIRA in any reply — under his own byline it reads as a plug, and readers here are peers, not prospects. One exception noted but not acted on: snak123 has hand-built a spreadsheet that does roughly what the app does, flagged as the one place a mention would read as a service rather than a pitch — John's call, not taken.

**Emerging follow-up article, flagged 3x independently by different commenters:** the OBBBA senior deduction ($6,000/person, phases out at 6%/person above $75K single / $150K MFJ, sunsets 2028) is doing more analytical work in the comments than in the article itself. Sanjib on the sunset, the McQuarrie-citing commenter on LTC deductibility interacting with it, Ormode on the true median income band. All three point at the same underexplored territory.

## Customer email: Joan Menard — Roth conversion tax funded from IRA, no outside cash

Support email (found the app via the article) asked whether the multi-year engine correctly handles funding Roth conversion tax from IRA withdrawals when there's no taxable/cash account, given her Ed-Slott-informed worry that this is a "big no-no."

**Full code audit performed before replying** (agent dispatch, ~56K tokens, 19 tool uses) — see `.claude/memory/decisions/log.md` 2026-07-26 entry for complete file:line detail. Verified: multi-year **already handles this correctly by default** (`TaxPaymentSource.taxableThenGrossUp`, real fixed-point gross-up solve in `ProjectionEngine.swift:864-902`). Initial draft reply said the opposite ("multi-year does not handle this") — caught and corrected before sending, since it would have sent her to the wrong screen. Final sent reply (John's own wording, this session only suggested the closing-question fix) correctly described the gross-up, flagged that the single-year screen's default differs and needs a manual switch, and disclosed a known limitation (Social Security taxability not recomputed post-gross-up).

**Two commitments now made to a customer in writing, dated:**
1. Selectable tax payment source, **V2.3, early August 2026**.
2. Social Security-taxability-in-gross-up fix, described to her as "on my list" (no date given).

Both logged to `.claude/memory/decisions/log.md` and a new persistent memory file `v2-3-tax-payment-source-commitment.md`, explicitly cross-referenced to [[optimizer-objective-not-selectable]] (the prior instance of promising a capability — to Tim — before it existed) as the pattern to avoid repeating.

**Five V2.3-backlog findings from the same audit, severity order** (full detail in decisions log, not repeated here):
1. `underfunded` (traditional exhausted, tax still short) is computed at `ProjectionEngine.swift:939` and read/surfaced NOWHERE — an infeasible plan renders as valid. Highest severity, smallest fix (value already exists).
2. Single-year (`rothConversionWithholdingMode`, defaults `.paidFromOutside`) and multi-year (`taxPaymentSource`, defaults gross-up-from-IRA) disagree with no linkage and no explanation to the user.
3. Taxable Social Security frozen pre-gross-up (`:626`), so the fixed-point under-solves when the extra withdrawal pushes more SS into taxability.
4. ACA MAGI excludes the gross-up (`:681`), overstating subsidies for pre-65 conversion users (doesn't affect Joan at 66/67).
5. The Ed-Slott "don't fund conversion tax from the IRA" concern is nowhere disclosed in-app (`V2Disclosures.swift` is silent on it) — worth noting since Joan arrived already worried about exactly this from his book.

## Open items / next steps

- **RESOLVED:** Sanjib's post-2028 middle-couple figure is now engine-verified ($8,474 → $6,813; see the Sanjib bullet above for method and cross-check). Reply drafted with the real numbers; not yet confirmed as posted to HumbleDollar.
- Rick Connor and bbbobbins replies drafted this continuation (see bullets above); not yet confirmed as posted.
- Branch topology decision (rebase vs. merge `main`) — not decided, `root-workspace` still 40 commits behind `main`, both fixes verified compatible but unintegrated.
- V2.3 scope: `underfunded` surfacing was the agreed next task before the pivot to HumbleDollar replies; not started.
- Two RMD-view gaps flagged earlier in the session, also not started: spouse RMD row vanishes when spouse is RMD-age but holds $0 spouse-owned traditional balance; `DataManager.swift:3706` prices the *ungated household* total balance off the *primary's* age/RMD-age alone.
- Still open across the whole comment thread: confirm which drafted replies (Sanjib, Rick Connor, bbbobbins, Dave Melick, Chris & Steve Hensley, Heidi) have actually been posted to HumbleDollar vs. still sitting as drafts.
