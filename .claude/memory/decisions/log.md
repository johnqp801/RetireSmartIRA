# Decision Log

Append-only. Newest entries at top. Each entry: `## YYYY-MM-DD: <Title>` + decision + one-sentence rationale.

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
