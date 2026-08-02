# 2026-07-31 — Alan round 3, a confirmed NY calculation bug, and a promise that got missed

Continues the 2026-07-30 session (see `2026-07-30-memory-rescue-and-article-figure-tests.md` here, and the website repo's `2026-07-30-seo-program-days-1-to-5-shipped.md`).

---

## 1. Alan's four questions, audited against code

He sent four at 6:30 AM. Three had clean answers, one was a real bug.

**Q1, Social Security withholding.** Non-issue. `federalWithholding` appears nowhere in `TaxCalculationEngine`; withholding never enters the liability calculation, only the owe-versus-refund picture. The SS field is a W-4V rate picker (`IncomeSourcesView.swift:800`) because those are the only rates SSA accepts.

**Q2, New York.** See section 2. Real bug.

**Q3, "two withholding lines look the same."** Not duplicates. For an SS source the editor shows a `Federal Withholding` W-4V picker, then a `State Withholding Entry` $/% toggle. The state label truncates on iPhone badly enough to read as a second federal control. Labeling defect.

**Q4, "two unlabeled boxes on income rows."** His assumption was right, federal then state (`IncomeModels.swift:57-58`). They need labels.

Reply sent 8:21 AM.

## 2. The NY government-pension gap — CONFIRMED

Full research and fix shape: `roadmap/2026-07-30-ny-government-pension-exclusion-gap.md`. Summary:

**Alan confirmed: "I'm getting a NYC employee's pension - only Federal taxable."** A New York City employee pension is local-government pension income, so it is IT-201 **line 26**: fully excluded from NY State, no cap, and exempt from NYC tax too because the city rate runs on the state-taxable base. He is a live affected user.

**The law, verified against primary source (tax.ny.gov IT-201 instructions):** line 26 and line 29 are SEPARATE subtraction tracks. Line 29's $20,000 applies only to income NOT from a government plan, so a government pension does not consume any of the $20,000.

**Scope, narrower than first assumed.** Already correct: non-government pensions (including the shared pension+IRA cap), Social Security, and military retirement (`MilitaryRetirementExemption.swift:129`, NY fully exempt). The gap is **non-military government pensions only** — NYS, NY local, federal civilian. No `IncomeType` can represent one, and `RetirementIncomeExemptions` is per-state rather than per-source.

**Two-part harm:** income above $20,000 taxed by state and city when NY taxes none of it, AND `pensionAndIRAShareSingleCap` makes the pension eat the $20,000 that should have covered an IRA withdrawal.

**Carve-out that shapes the fix:** salary-reduction supplemental plans (403(b) TDA, 457 deferred comp) are NOT line 26 income even for a government employer. So "is it a government pension?" is insufficient; plan type matters. Does not affect Alan, whose is the pension itself.

**Not yet built.** Needs a per-source flag, not a state-level setting.

## 3. A promise to Alan that missed its release

Reading the full email thread (Jul 12 through Jul 31) surfaced this:

**2026-07-19, John to Alan:** *"I'm going to put a fix in the next release so the cursor starts at the right side of the field."*

The next release was **2.3.0 / build 63, submitted 07-28, approved 07-29. It shipped without the fix.** Verified: `fix/numeric-caret-at-end` was in no tag and not on `main`.

This is the [[optimizer-objective-not-selectable]] pattern and worse — with Tim a capability was merely claimed; here the fix **existed on origin and was simply not picked up**. Root cause: the promise lived in the decision log but was never attached to the fix, so nothing connected them at release time. Now recorded in `pending-fixes-next-release`.

A second, softer promise from 07-18 is also outstanding: *"Entering your own future income the same way is next on my list."* Per-year income entry, still unbuilt.

**Also worth knowing:** Alan told colleagues about the app (07-16, *"a lot of them are retirement age and above"*). Three rounds, three real finds, and his round-2 items shipped in 2.1.2 credited in `TaxCalculationEngine.swift:394`.

## 4. Both queued fixes cherry-picked onto `main`

| On main | Commit | Was |
|---|---|---|
| caret-at-end | `af45404` | `fix/numeric-caret-at-end` |
| Year-1 override wipe | `25d7edd` | `fix/year1-override-wipe` |

No conflicts. **Full macOS suite green: 1,570 Swift Testing in 265 suites + 503 XCTest, 0 failures.**

**The caret fix is PARTIAL and this is an open decision.** `.caretAtEndOnFocus()` is a per-screen modifier applied to `SettingsView` only. That closes Alan's exact case (the local tax field lives there). Eight other views use `.decimalPad`/`.numberPad` and are still exposed: `IncomeSourcesView`, `AccountsView`, `RothConversionView`, `QuarterlyTaxView`, `SSDataEntryView`, `TaxPlanningView`, `Year1EditorView`, `YearDetailEditor`. One line each. `IncomeSourcesView` is the sharpest risk: full of pre-filled trailing-aligned numerics, and the screen Alan lives in.

## 5. App Store Connect analytics, interpreted

John asked how retention is measured. Verified against Apple's docs:

- **Retention is a specific-day measure**, not cumulative. Apple's example: 100 devices install May 1, 20 have a session **on May 8**, so day-7 retention is 20%. A user who returns on day 3 and day 11 appears in no bucket.
- **All usage metrics are opt-in only.** Retention, Sessions, Active Devices, Deletions. Updates and downloads are App Store metrics, full population.

**Conclusion reached: stop working the retention metric.** Daily Retention returns "Not Enough Data" at this scale, the opt-in pool is roughly 19 monthly actives, and cohort retention assumes a daily-use hypothesis this product does not have.

**What the data actually showed:**
- **Active Last 30 Days flat at ~20 from May through mid-July, then doubling to ~40 in the final week.** The climb starts around 07-22 to 07-25, matching the HumbleDollar piece (07-25) and the Bogleheads thread (07-26). Three opt-in metrics turned up in the same week as the editorial wave.
- **835 sessions across roughly 19 to 40 distinct opted-in devices** is ~25 to 45 sessions per device per quarter. Engaged, not drive-by.
- **Updates is the best installed-base proxy**: full population, no opt-in gate, no requirement that the user open an episodic app. ~186 on 2.3.0 release day, and 1,587 over ~9-12 releases implies **130 to 175 devices per release**. The release-day spike is a floor, not the total, because iOS auto-update rolls out over days.

**Open question to revisit in August:** does the Active-Last-30-Days doubling hold, or decay back to 20? If it holds, earned editorial produced durable users, which is the strongest argument for the Day 7 HumbleDollar pitch.

## 6. SEO Day 6 — Search Console

Website-side, recorded here because it closed in this session. Detail in the website repo.

- **Sitemap resubmitted. Discovered pages 11 → 16.** Previous read was **Jun 9**, seven weeks stale, so three of five articles had never appeared in a sitemap Google actually read.
- **ACA article:** indexed, last crawl 07-30 6:04 PM, which is post-deploy — provable because the site emitted no canonical tag at all before that deploy.
- **New flagship article: indexed within a day of publication.** Last crawl 07-31 11:09 AM.
- **`Google-selected canonical: Inspected URL`** on the new article. Google chose the same URL John declared, which is the independent confirmation that the www fix landed correctly.
- "Referring page: None detected" on both. Expected lag; Google has not re-crawled the pages that link to them. Worth re-checking in a week, since Day 2 was internal linking.

---

## Open items

- **NY government-pension fix, not built.** Per-source flag. TDD, state-tax suite as the gate.
- **Decide the caret fix scope** before cutting a build: eight more screens, or ship narrow.
- **`main` has 2 unpushed commits** (the cherry-picks).
- **Reply to Alan** confirming the NY bug is real, and telling him the caret fix slipped 2.3.0 rather than letting him find out.
- Search Console: widow-tax URL inspection, and identify the one "Crawled - currently not indexed" page.
- Vercel: apex redirect 307 → 308.
- `article/conversion-tax-funding-figures` still unmerged to `main`.
