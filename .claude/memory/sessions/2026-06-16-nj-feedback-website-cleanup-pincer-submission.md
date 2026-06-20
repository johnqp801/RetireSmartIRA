# Session: 2026-06-16 — NJ tax feedback + 1.8.8 decision, website style cleanup, GA opt-out, pincer submission doc

**Repos touched:** RetireSmartIRA (memory/roadmap/decision-log), retiresmartira-website (committed to main, push left to user). Plus user-level auto-memory and a Desktop .docx.
**Status:** All website changes committed to main (3 commits), not yet pushed by user. Decision-log + roadmap updated for 1.8.8. Two new writing-style preferences saved to auto-memory. Pincer submission doc iterated to V8 on the Desktop.

---

## TL;DR

Started from a Brian/Bob NJ-tax bug report, diagnosed it against the engine (app is correct; likely setup or old version), and committed the NJ pension-exclusion AGI phaseout as scope for a new **1.8.8** release. Cleaned the website articles of em dashes and AI-tell patterns after the user set two standing writing-style preferences. Added a self-traffic Google Analytics opt-out. Iterated the ACA/IRMAA pincer editorial-submission Word doc through several rounds of grammar fixes, AI-tell reduction, caveats, and an editorial-byline restructure (V2 to V8).

---

## 1. NJ tax feedback (Brian relaying his friend Bob)

Bob reported NJ tax showing when income was under $100K, and that the federal standard deduction looked like it was carrying to the state.

**Diagnosis (verified against code, double-checked on request):**
- NJ pension/RMD exclusion is built in and works (passing test: 62-year-old single, $80K pension + $30K RMD => $0 NJ tax). [StateTaxData.swift:1538], [TaxCalculationEngine.swift:514-528].
- It only applies to income typed **Pension** or **RMD** (exact app labels, [IncomeModels.swift:99,122]); wages/interest/dividends/Other are not exempt. This is correct per NJSA 54A:6-15.
- Requires age 62+ (`regularExemptionMinAge: 62`).
- Federal-deduction carryover to `.none` states was a real bug fixed in **v1.8.3** ([DataManager.swift:545-553]); only affects users on older builds.
- The "Taxable Income" figure on the State Comparison screen is FEDERAL taxable (post federal deduction); NJ taxes the higher gross. Likely source of Bob's "carrying federal deduction" impression. ([StateComparisonView.swift:135] vs [DataManager.swift:1795]).

**Most likely causes, in order:** (a) income not typed Pension/RMD, (b) age under 62, (c) older app version. Need three data points from Bob: app version, income category used, birth year/age.

**Reply to Brian:** drafted, refined for length, saved as final (the version giving Bob credit for spotting the AGI-phaseout gap). The $50K dividends + $100K pension question: app would tax only the dividends (full pension exclusion), but real NJ law at $150K total income gives only 25% exclusion (MFJ tier) => taxes ~$125K. App under-taxes in the $100K-$150K window. This is the documented gap.

## 2. Release decision: next release is 1.8.8 (not 1.9)

- **NJ pension-exclusion AGI phaseout** committed as scope for **1.8.8** (an .8.x accuracy patch). Engine already has `.partialWithAGIPhaseout` from Phase E (CT/RI), but NJ does not fit cleanly: stepped phaseout (50%/25% MFJ, 37.5%/18.75% single), per-filing-status caps ($75K single / $100K MFJ), and a $150K cliff. Needs an engine-case extension + boundary tests at $100K/$125K/$150K. Touches `ExemptionLevel` enum => update StateComparisonView switch statements for exhaustiveness (same gotcha Phase E hit).
- Recorded in [decisions/log.md] (2026-06-14 entry) and [roadmap/current.md] (new "PLANNED (NEXT): V1.8.8" section). Build 55 already staged in pbxproj; MARKETING_VERSION still 1.8.7 (needs bump to 1.8.8 at release).
- **1.9** remains the features bundle (ACA subsidy modeling, Medicare plan-type awareness, pre-tax contribution levers, Reduce-AGI dashboard) per [docs/1.9-roadmap.md] (that doc is stale-dated 2026-04-29; scope still "TBD-confirm" in roadmap). Note: the 1.9 bundle's HSA work explicitly calls out NJ, so the 1.8.8 NJ engine change will land underneath it.

## 3. Writing-style preferences (saved to user auto-memory)

Two standing rules now in `~/.claude/projects/.../memory/`:
- **no-em-dash.md** — never use the em dash character in anything produced for the user.
- **writing-style-avoid-ai-tells.md** — vary sentence rhythm, drop reflexive rule-of-three, cut mechanical transitions and hedging, no empty summary sentences, avoid overused vocab (delve, leverage, robust, navigate, underscore, testament, tapestry, realm, landscape, pivotal, crucial, seamless, boasts).

## 4. Website work (retiresmartira-website, committed to main, NOT pushed)

Three commits on main:
- `bb26c03` — **GA self-traffic opt-out.** beforeInteractive script in [src/app/layout.tsx] sets GA4's native `window['ga-disable-G-K62WBF51P9']` from a localStorage flag. Visit `?ga_optout=1` once per device/browser to opt out, `?ga_optout=0` to re-enable. Verified in preview (set / persists on clean URL / re-enable / no console errors). Per-browser; only effective after deploy.
- `107a85f` — **Em-dash removal** across all three articles, the articles index, OG image alt/body, and shared article components (ArticleCTA, NewsletterSignup, PincerChart, ArticleLayout, ShareButton). Context-appropriate punctuation, not blind swaps. En-dash numeric ranges (e.g. "years 1-9") intentionally left. Required clearing `.next` cache + dev-server restart because Turbopack's watcher missed tool-based edits (first verification showed false stale hits). Verified all four pages render 200, zero em dashes, no console errors.
- `ed93cb2` — **AI-tell reduction.** Removed a duplicated tricolon and a "To be precise:" throat-clear in the pincer article; broke a rigid three-parallel-sentence run in the IRMAA article. Lexical scan found zero overused-vocab/mechanical-transition hits, so the articles were already clean on that front.

**Push instruction given:** `cd /Users/johnurban/Projects/retiresmartira-website && git push origin main` (user has a deny rule on push; they push manually). Pushing triggers Vercel auto-deploy.

## 5. ACA/IRMAA pincer editorial submission doc (Desktop .docx, V2 to V8)

Iterated the editorial-submission Word version of the pincer article. Source content lives at `src/app/articles/aca-irmaa-pincer-2026/page.tsx`; the .docx is a standalone submission artifact built earlier with docx-js and now hand-edited by the user across versions.

- **Static chart** regenerated from `/tmp/generate_pincer_chart.py` (matplotlib). Early fix: subsidized bars were showing full premium; corrected so $60K/$80K show short indigo bars (~$4,914 / $7,968) vs tall red over-cliff bars (~$29,856). Later fix: removed em dashes baked into the chart title/legend ("vs. Both Cliffs: Married / Joint Filer", "ACA premium (subsidized)", "ACA premium, over cliff (no subsidy)").
- **V3:** fixed ~20 grammar/clarity errors the user introduced while hand-editing V2 (e.g. "I can present" -> "it can present", doubled "by", broken parallelism, comma splices, colon+verb list items, nested parens).
- **V5:** bucket-1 self-edits — varied punchy parallel cadence, added plain caveats on 2028 IRMAA (illustrative proxy) and the shifting 2026 subsidy law, softened over-certain claims ("reliable"->"reasonable" proxy, "you'll be paying"->"you would be looking at roughly").
- **V8 (Gemini review revisions):** byline cut from "By John Urban, Founder, RetireSmartIRA" to "By John Urban"; commercial credential moved to an "About the author" bio at the end; chart re-rendered em-dash-free; "proactive case" paragraph reframed as an explicit longer-horizon aside so it stops muddying the two-year timeline.
- Editing method: unpack with the docx skill, targeted XML edits, repack with `--original`, validate, verify (em dashes, chart image preserved). Each version saved to `~/Desktop/aca-irmaa-pincer-submission V*.docx`.

**Important fact defended twice:** the 2026 IRA 50+ contribution limit is **$8,600** ($7,500 base + $1,100 catch-up per Notice 2025-67), NOT $8,500. ChatGPT/Claude-chat both suggested $8,500 (using the old $1,000 catch-up); that is wrong for 2026. Do not change it.

---

## Open questions / next steps

- **NJ 1.8.8:** implement the AGI-phaseout engine change + boundary tests. Confirm whether to batch other small state-tax fixes into 1.8.8. Bump MARKETING_VERSION to 1.8.8.
- **Bob:** waiting on app version, income category, birth year to confirm root cause of his NJ report.
- **Website:** user to push main (3 commits) to deploy.
- **Pincer doc:** user may want the "proactive case" paragraph fully cut rather than signposted; offered. No PDF requested yet. Authentic founder anecdote still not added (I will not fabricate it; needs the user's own input).
- **Cross-ref:** when 1.9 HSA/contribution work starts, note the NJ engine changed under it.
