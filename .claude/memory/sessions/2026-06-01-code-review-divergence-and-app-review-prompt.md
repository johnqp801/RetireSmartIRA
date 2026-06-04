# 2026-06-01 — 1.8.5 deep code review, multi-model review divergence, and in-app review-prompt strategy

## ⭐ HEADLINE OPEN THREAD (return to this)

**Decide and build the best way to request App Store reviews in-app.** Strategy is
mostly settled (see below); what remains is finalizing the trigger design and the exact
code hooks, then deciding the release vehicle (1.8.6 vs 1.9). User explicitly wants to
come back to this. No code written yet — user has more questions first.

---

## What happened this session

### 1. Pushed 1.8.5 branch to GitHub
- Confirmed tag `v1.8.5-build50` (commit `6a6e110`) was already on origin.
- Branch `1.8.5/state-tax-refresh` was NOT a remote head — **pushed it** so the shipped
  code shows up as a branch, not just a tag. Now on origin.

### 2. Deep code review of the SHIPPED 1.8.5 codebase
Reviewed `.worktrees/1.8.5-state-tax-refresh/` (= the `v1.8.5-build50` tag).
- **76 app files / ~39.2k LOC; 58 test files / ~16.2k LOC; ~1,200 test functions**
  (843 Swift Testing `@Test` + ~360 XCTest), 1,328 `#expect` + ~426 `XCTAssert`.
  "1,100+ tests" is **accurate** on the shipped tree.
- **Verdict: B+/A-** — well above median for an indie iOS app, well above median for a
  tax app. Moat = statutory-cited, TAXSIM-validated, executable spec of US retirement
  tax law (SS AIME/PIA engine, SECURE-Act inherited-IRA EDB logic, 50-state retirement
  exemptions, interacting cliffs IRMAA/NIIT/ACA/SS-torpedo/AMT with typed MAGI wrappers).
- **Real (shipped-tree) critiques:** no CI; `DataManager` (3,439 lines) is a
  partially-decomposed god object; ~30 states encoded-but-not-independently-bracket-
  tested; TAXSIM oracle pinned to TY2023 (no external check on OBBBA/2026 logic);
  silent California fallback in `StateTaxData.config(for:)`; stale state exemption values
  flagged in a code TODO (CO/AL/MD/MI — MI `.full` overstates).
- Engineering rigor signals: **zero `try!` / `fatalError` / `as!`** in 39k LOC; 184
  statutory citations in comments; versioned persistence migrations; real design-system
  token layer.

### 3. ⚠️ Multi-model review divergence — ROOT CAUSE FOUND
Perplexity + ChatGPT (their two reviews were **word-for-word identical** — treat as ONE
source, not two) claimed **"ACA cliff is not built — only a `#Preview` in
MetricCard.swift:103."** My review found ACA built + 5 test files. Resolution:

- **They reviewed `main`.** Fingerprint: their "DataManager 2,636 lines" == `main` HEAD
  exactly. `main` genuinely has NO `ACASubsidyEngine` — so they were *correct about the
  tree they saw* (and even hedged "maybe it's on a branch not on main").
- **`main` is badly stale:** HEAD dated 2026-05-04, **204 commits behind** the shipped
  1.8.5 tag, and **missing every release 1.8.1 → 1.8.5** (incl. ACA). Releases shipped
  from worktree branches/tags and were never merged back to `main`; on 2026-05-04 `main`
  diverged toward the 2.0/multi-year line.
- **The shipped `v1.8.5-build50` tag DOES contain the real 129-line `ACASubsidyEngine`
  + `ACASubsidyBar` + 5 test files.** ACA is built, tested, and live in the App Store.
  The advertised feature is real for users.
- **Correction owed to Perplexity:** my first-pass claim that "they grep'd and stopped at
  a #Preview" was WRONG. They were thorough; their branch just lacked ACA.

**Artifact created:** `RetireSmartIRA-1.8.5-shipped-6a6e110.zip` (2.7 MB, project root)
— clean `git archive` of the shipped tag, for feeding to other AI tools so they review
the right code. (Untracked; not committed.)

### 4. In-app review-prompt strategy (verified + designed, NOT built)
- **Verified across ALL branches (shipped 1.8.5, main, current HEAD): NO review prompt
  exists.** No `requestReview`, no `SKStoreReviewRequest`, no `import StoreKit` anywhere.
  All 5 existing ratings are organic. → biggest, cheapest review-volume win available.
- **Design decisions reached (directional, not finalized):**
  - **Value-event trigger > raw session counting.** Debated Perplexity's
    "ReviewPromptManager with session counting." Conclusion: sessions are a weaker
    satisfaction proxy, "session" is fuzzy/bug-prone to define, and heavy custom
    rate-limiting duplicates iOS's built-in throttle (~3×/365, ~once per version,
    OS decides display). Keep only a **thin session/maturity floor** as a guard.
  - **PDF export is the WRONG anchor.** User feedback: their own value comes from the
    **what-if exploration loop** — adjusting scenarios and bouncing between **Scenario
    and Tax Planning** — and they "hardly ever hit the PDF." So the value-event should
    track exploration depth: # scenario recalcs, **Scenario↔TaxPlanning round-trips**,
    multi-scenario compares.
  - **Never fire mid-loop** (it would shatter the flow state we're rewarding). Detect a
    high-value session, set a flag, and fire at a calm moment: settling back to
    Dashboard, OR **deferred to next launch** ("rich session + returned" = strongest
    signal; neatly fuses the good half of value-event + session signal).
  - **Add a manual "Rate RetireSmartIRA" button in Settings** deep-linking to
    `...?action=write-review` — escape hatch + drives *written* reviews (native dialog
    mostly yields silent stars).
  - **Minimal persisted state:** ~3 UserDefaults keys — event/launch count,
    `lastPromptedVersion` (version-gate), `firstLaunchDate`.
  - Code hooks (identified, not wired): Scenario↔TaxPlanning tab switches live in
    `ContentView`; recalcs flow through `DataManager`; scenario state via
    `ScenarioStateManager`.
- **OPEN QUESTION for user:** what's the single "payoff micro-moment" in their own
  usage? (bracket-headroom number updating? IRMAA distance-to-cliff shifting? lifetime-SS
  comparison resolving?) — that's the highest-precision event to count.

### 5. Release-vehicle question (NOT decided)
- Leaning **1.8.6 (branched off `v1.8.5-build50`)** over folding into 1.9, because: speed
  (reviews compound; 1.9 scope is TBD), risk isolation (tiny StoreKit-only diff),
  precedent (1.8.2 narrow patch), clean base (release tag, not stale main / unfinished
  1.9). Only counter-argument (avoid an extra submission cycle) doesn't hold unless 1.9
  is imminent, which it isn't.
- Scope options floated for a 1.8.6: (a) review prompt only; (b) + cheap CA-fallback
  assertion; (c) + stale-state exemption fixes (CO/AL/MD/MI — touches engine, more risk).
- **User said "more questions first" — NOT finalized.** Do not build yet.

---

## Open / next steps
1. **★ Finalize in-app review-prompt design + build it** (the headline thread). Needs:
   user's "payoff micro-moment", final trigger thresholds, then wire hooks + Settings
   button + version gate + run tests.
2. **Decide release vehicle** (1.8.6 vs 1.9) and scope. Adding a review prompt = binary
   change = **new build required** for the App Store.
3. **Reconcile `main`** (204 commits / ~3 weeks stale, missing 1.8.1–1.8.5). Offered a
   plan (inspect the 10 main-only commits → merge/fast-forward to shipped line); user
   has not approved. Until fixed, `main` misleads anyone who clones it.
4. **Process fix:** feed every review model the SAME current tree — the shipped tag /
   active worktree (or the 2.7 MB archive), NEVER `main`. This round's entire divergence
   was stale-branch, not analysis quality.
5. Carryover correctness items (shipped tree, independent of reviews): re-pin TAXSIM
   oracle to TY2026; fix stale state exemptions; add CA-fallback assertion; add CI.
6. **🔐 Carryover security TODO (still outstanding):** rotate exposed ImprovMX API key.

## Other shipped-status context (unchanged)
- iOS 1.8.5 build 50 LIVE since 2026-05-29. macOS build 48 was waiting for review as of
  2026-05-30 — check status.
