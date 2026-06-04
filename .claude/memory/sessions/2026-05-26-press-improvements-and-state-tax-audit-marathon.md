# Session: 2026-05-26 — Press improvements, Mac review inquiry, and 50-state TY 2026 tax audit marathon

**Date:** 2026-05-26 (Tuesday)
**Branch:** `feature/multi-year-planning` (main repo); `main` (website repo)
**Status:** Major productive session. 15 states corrected to TY 2026, 34 pinning tests added, press page improvements deployed, Mac App Review inquiry sent.

---

## TL;DR

Six interlocking threads completed:

1. **Press page improvements** deployed per PR feedback (LinkedIn link, story angles, by-the-numbers, version bump)
2. **Mac 1.8.4 App Review inquiry** sent via App Store Connect Contact Us form (day-6 in queue)
3. **CA bracket UI bug** caught by user (showed TY 2023 brackets) → fixed to TY 2025
4. **50-state bracket freshness audit** discovery — found 21 states with material drift
5. **Path 1 policy** adopted per user direction "100% correct for TY 2026"
6. **Phases A + B + C of state-tax fixes** shipped (15 states + 34 pinning tests across CA + 3 phases)

DMARC report confirming 2/3 press pitch deliveries also appended to 5/25 memo.

---

## Chapter 1 — Morning: Mac 1.8.4 review wait + DMARC delivery confirmation

Started by checking Mac 1.8.4 App Store review status. Day-6 in "Waiting for Review" — past upper-end of normal window. Drafted polite status-check inquiry to send via App Store Connect Contact Us form. Captured the polite-status-check template in memory for future use:

> "Submitted [date]. In Waiting for Review for [N] days. The matching [other platform] build from the same upload was approved on [date], so the binary is clean. Wanted to make sure nothing on my end is blocking review and check whether you need additional information."

Inquiry submitted via developer.apple.com → Support and Contact → "Send us a message" form. Apple's stated SLA: typically 2 business days or less.

Also walked through user's question about whether they were in the right App Store Connect place (initially landed on "Reply to App Review messages" — wrong, that's for when Apple messages you first; needed Contact Us for a fresh inquiry).

While answering questions about Support URL field on the version page, walked user through where it lives (Distribution → 1.8.4 version → scroll past Boilerplate to "General App Information"). Verified Support URL = `https://retiresmartira.com/support` (correctly pointing to the page that now shows the new `support@retiresmartira.com` email). Marketing URL = homepage. App Review Contact email updated from stale `plansmartira@gmail.com` to `johnqp@mac.com` (user's Apple ID).

DMARC report from 5/24 UTC analyzed — showed two records consistent with successful delivery to Karsten Jeske (Gmail SPF pass) and Chris Mamula (caniretireyet.com Cloudflare Email Routing DKIM pass). Appended delivery-confirmation note to 5/25 press outreach session memo.

**Commits:** `e2a68f1` (memory: Mac review inquiry), `12444ae` (memory: DMARC delivery confirmation appended)

---

## Chapter 2 — Afternoon: PR feedback drives press page improvements

User shared PR feedback on the press page. Triaged 7 items, deferred 4, applied 3 in one PR.

**Item 1 (footer email inconsistency)** — reviewer was on cached pre-deploy version; current /press footer correctly shows `support@retiresmartira.com`. Marked resolved.

**Item 2 (LinkedIn link)** — applied: added LinkedIn icon + link to `https://www.linkedin.com/in/john-urban-isp` under founder name. Unblocks future Christine Benz pitch.

**Item 3 (Story angles)** — applied: added new section with 5 pre-baked story angles (ACA cliff, widow's penalty, RSU/NQDC unwind, "Can I retire?" reframe, on-device privacy). Reviewer literally drafted these for us; took ~20 minutes to flesh out with supporting blurbs.

**Item 7 (By-the-numbers stats strip)** — applied: 4 stat cards (50 states · 2026 IRS limits · 7 tax mechanics · 950+ tests).

**Also bumped:** "Current version" in Quick Facts from 1.8.1 → 1.8.4.

Deferred items 4 (named testimonials — needs outreach), 5 (recent milestones callout — next pass), 6 (demo video — defer to podcast wave).

**Commit:** `d60cb39` (website repo) — pushed to GitHub, Vercel auto-deployed.

---

## Chapter 3 — Apple Mail + iCloud config follow-ups

User opened Apple Mail to compose a reply from `support@retiresmartira.com` and discovered the alias wasn't in the From dropdown. Walked through Mail → Settings → Accounts → Gmail account → Email Address → Edit Email Addresses to add `support@`. Plus the `johnqp@mac.com` Apple ID update.

Brief detour: also explained the difference between Apple's Support URL (a user-facing field) and the App Review Contact Information (a reviewer-only field).

No commits — this was pure config work.

---

## Chapter 4 — Late afternoon: CA bracket UI bug → CA TY 2025 fix

User shared a screenshot of the CA tax bracket UI showing $21K/$49K/$78K/$108K/$137K/$698K — recognized these as **TY 2023 brackets**, three inflation cycles stale. Verified against the actual code in `RetireSmartIRA/StateTaxData.swift` line 523 (same on `1.8.4/incremental` shipped branch — production also had the bug).

Dispatched research agent to verify TY 2025 California brackets from CA FTB primary source (2025 Form 540 Tax Rate Schedules PDF). Confidence HIGH on all values returned.

Applied fix — full bracket replacement for single (Schedule X) + MFJ (Schedule Y) + comment block with source URL. Standard deduction $5,706/$11,412 already happened to be correct for TY 2025 (someone had updated that but missed brackets). MHST $1M threshold confirmed statutory/unindexed.

Updated 3 existing test expectations + added 2 new pinning tests covering the MFJ case from user's screenshot.

**Commits:** `b9d6413` (code fix), `55c1710` (CA audit memo with HoH/MFS gaps and 50-state freshness flag).

**Side finding:** Three follow-up gaps surfaced during CA fix:
1. HoH brackets globally missing (engine API limitation)
2. MFS brackets incorrectly routed to married (engine bug)
3. 50-state freshness audit needed (which became the rest of the day)

---

## Chapter 5 — Evening: 50-state freshness discovery audit

Dispatched discovery agent to survey all 43 configured states (CA excluded — just fixed). Output: triage table sorted by severity, ranking by user impact.

**Findings:** 21 states with meaningful drift, including 4 **structural** issues (LA wrong tax system, KS wrong bracket count, MT/ND wrongly modeled as flat when actually progressive).

**Strategic decisions surfaced:**
- TY 2025 actuals vs. TY 2026 scheduled policy question (5 states ahead of schedule)
- MA 4% surtax on income >$1M missing
- HoH brackets missing globally
- Press claim "All 50 states · 2026 IRS limits" needed to align with reality

User direction: **"we need everything in the end to be 100% correct for tax year 2026."**

Discussed three paths:
- Path 1 (recommended): TY 2026 where published, latest TY 2025 elsewhere, refresh quarterly
- Path 2: Project TY 2026 estimates via state CPI indexing
- Path 3: Soften press claim, don't try

User chose **Path 1**.

**Commit:** `bb46f0a` (50-state discovery audit memo).

---

## Chapter 6 — Phases A + B + C: 15 states corrected to TY 2026

Big sequential push through three phases. For each phase: dispatch research agent → verify code structure → apply fixes → write pinning tests → run iOS Simulator tests → commit code → commit memory.

### Phase A — Structural corrections (commit `ac883ce`)

5 states with structural changes:

| State | Change |
|---|---|
| Louisiana | Progressive 3-bracket → flat 3% (HB 10) |
| Kansas | 3 brackets → 2 brackets (SB 1, 2024 Special) |
| Montana | "Flat 4.7%" → 2-bracket progressive (HB 337 reduced top 5.9%→5.65% for TY 2026) |
| North Dakota | "Flat 1.95%" → 3-bracket with $0 first bracket |
| Michigan | Flat 4.05% (TY 2023 trigger) → flat 4.25% (TY 2024+) |

10 pinning tests added. **All passed** on iOS Simulator.

### Phase B — High-severity bracket/rate/exemption corrections (commit `379aa99`)

| State | Change |
|---|---|
| Hawaii | All 12 bracket thresholds replaced with Act 46 TY 2026 widened values |
| Connecticut | Bottom 2 rates 3%→2%, 5%→4.5% (missed 2024 reform) |
| Arkansas | Top rate 4.4%→3.9%, new 0% first bracket, std ded $2,200/$4,400→$2,470/$4,940 |
| Maryland | Added new 6.25%/6.50% top brackets per 2025 Act Ch. 604; std ded flat $3,350/$6,700; pension $39,500→$41,200 |
| Rhode Island | Bracket thresholds refreshed; pension exclusion $0→$50K |

12 pinning tests added. **All passed.**

### Phase C — Medium-severity refreshes + one major restructure (commit `d5bcb42`)

| State | Change |
|---|---|
| Minnesota | Bracket refresh +2.37% (MN DoR press release) |
| Maine | Bracket threshold refresh (Maine Revenue Services PDF) |
| Delaware | Std deduction $3,250/$6,500 → $5,700/$11,400 per HB 89 statute |
| South Carolina | **MAJOR** restructure — 3-bracket → 2-tier 1.99%/5.21% per H.4216 (signed March 2026) |
| West Virginia | New 5-bracket schedule from 5% cut signed June 2026, retroactive Jan 1 |

7 pinning tests added. **All passed** (after isolating run — xcodebuild had caching quirk with multiple -only-testing flags + brand-new suite).

**Plus:** Missouri verified no-change (top 4.7% held into TY 2026). 5 states deferred to Phase C2 (NE, NM, WI, VT, OR — each with explicit reason for deferral and primary-source verification still needed).

**Memory commits:** `b6fb4ef` (Phase A), `c6df0f7` (Phase B), `30b35e6` (Phase C).

---

## Engineering rigor maintained

- **Per-state source URLs** in code comments for every fix
- **Pinning tests** designed to fail if state regresses to pre-fix values (each test computes expected tax to the cent based on TY 2026 schedule)
- **Engine limitations** documented in code comments per-state (CT/RI AGI phaseouts, MA $1M surtax, MD county tax, HoH brackets globally, AR two-schedule cliff)
- **Independent agent verification** — each phase dispatched a research agent to verify against primary sources before applying
- **Honest deferral** of MEDIUM-confidence data — preferred admitting "needs primary source verification" over shipping uncertain values

---

## Combined state of state-tax engine at end of day

| Status | Count | States |
|---|---|---|
| **TY 2026 actuals applied** | 15 | LA, KS, MT, ND, MI, HI, CT, AR, MD, RI, MN, ME, DE, SC, WV |
| **TY 2025 latest** (TY 2026 not yet published by state authority) | 1 | CA |
| **TY 2026 verified no-change** | 1 | MO |
| **Deferred to Phase C2** | 5 | NE, NM, WI, VT, OR |
| **Originally CURRENT** | ~14 | AL, AZ, CO, IA, IL, MA, NJ, NY, OK, PA, UT, MS, NH(no-tax), WA(no-tax) |
| **LOW-severity edge cases** | ~8 | DC, GA, ID, VA, IN, KY, NC, OH (Phase D scope) |

**Pinning tests:** 34 across CA + Phase A/B/C suites (5+10+12+7).

---

## Open follow-up scopes (carried forward)

1. **Phase C2** — Primary-source verification for 5 deferred states (NE, NM, WI, VT, OR). Per-state agent dispatches with PDF requirements.
2. **Phase D** — TY policy edge cases (IN, KY, NC, OH currently "ahead-of-schedule" using TY 2026 statutory rates; TY 2025 actuals differ). Product decision needed.
3. **Phase E** — Engine API changes for HoH brackets, MFS routing, MA $1M surtax, AGI-based exemption phaseouts.
4. **Quarterly refresh routine** — Set up `/schedule` agent for Jul 2026, Oct 2026, Jan 2027 audit cycles.
5. **Cherry-pick to `1.8.4/incremental`** — All today's work on `feature/multi-year-planning`. Shipped users still on pre-fix data until release branch picks it up. Recommended: 1.8.5 patch release.
6. **Press claim adjustment** — "All 50 states · 2026 IRS limits" still defensible at federal level; state engine is improved but not uniformly TY 2026. Decide whether to tighten engine first or soften claim.

## Carried over from prior sessions (unchanged)

- 🔐 Rotate ImprovMX API key `sk_REDACTED-rotated-2026-06-04` — exposed in transcripts (Day 4 outstanding)
- 📅 Mac 1.8.4 App Review status — inquiry sent today; expect Apple response in 1-3 business days
- 📨 Watch for Jonggie App Store review (sent thank-you + soft ask 5/23)
- 👀 Press outreach bumps Tue 6/2 / Wed 6/3 for Karsten/Fritz/Chris non-responders
- LinkedIn About rewrite (drafted, not applied per 5/25 memo)
- Next iOS submission: update App Review Contact to `johnqp@mac.com`

---

## Commits today

### Website repo (`main`)
- `d60cb39` press: add LinkedIn link, story angles, by-the-numbers, bump version

### Main repo (`feature/multi-year-planning`)

**Code:**
- `b9d6413` fix(state-tax/CA): TY 2025 brackets
- `ac883ce` fix(state-tax): Phase A — LA, KS, MT, ND, MI
- `379aa99` fix(state-tax): Phase B — HI, CT, AR, MD, RI
- `d5bcb42` fix(state-tax): Phase C — MN, ME, DE, SC, WV

**Memory:**
- `e2a68f1` Mac 1.8.4 review inquiry session note
- `12444ae` DMARC delivery confirmation appended to 5/25 memo
- `55c1710` CA bracket freshness audit + 3 follow-up gaps
- `bb46f0a` 50-state discovery audit
- `b6fb4ef` Phase A complete + Path 1 policy adopted
- `c6df0f7` Phase B complete + engine limitations documented
- `30b35e6` Phase C complete (5 applied + 1 verified + 5 deferred)

---

## Habits scorecard

- ✅ **Habit 1 start-bookend:** Memory read at session start; cross-references throughout
- ✅ **Habit 1 end-bookend:** This session note
- ✅ **Habit 2 log decisions:** Multiple substantive entries in `decisions/log.md` (Path 1 policy, Phase A, Phase B, Phase C). Multiple full-detail decision memos in `decisions/`.
- ⚠️ **Habit 3 save drafts:** N/A today (no marketing drafts produced; today was engineering)
- ✅ **Habit 4 commit memory:** 11+ commits between code and memory
- ✅ **Habit 5 tester feedback loop:** Jonggie waiting; DMARC confirmed 2/3 press pitches delivered; Mac review inquiry sent

## Closing thought

This was unusual in scope. Started Tuesday morning with a single press-page PR-feedback item and ended Tuesday night having fixed a deeply-buried tax-correctness bug across 15 states with full test coverage. The CA bracket UI screenshot was the entry point; everything else cascaded from "if CA is 3 years stale, what about the others?" The discovery agent + per-phase verification agents made it tractable. Path 1 policy + per-state code comments with sources should make this maintainable going forward.

Next session: probably want to either close out Phase C2 (5 deferred states) or take a break from state-tax and shift focus to one of the other open threads (Mac review status, press outreach bumps, LinkedIn About rewrite, etc.).
