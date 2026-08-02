# 2026-08-01 — Steve Nicolai's feedback, the LinkedIn post, and a full backlog reconciliation

**Next session: start at `roadmap/2026-08-01-consolidated-backlog.md`.** John's instruction was "address 100% of all this tomorrow." That file is the entry point; this one is the context.

Third day of a long session. Earlier parts: `2026-07-30-memory-rescue-and-article-figure-tests.md`, `2026-07-31-alan-round-3-ny-pension-bug-and-broken-promise.md`, and in the website repo `2026-07-30-seo-program-days-1-to-5-shipped.md` and `2026-07-31-seo-day-6-search-console.md`.

---

## 1. Steve Nicolai, a new tester, filed 12 items and found a shipped bug

Emailed support@ at 3:48 PM. Four issues, eight suggestions. Full detail: `roadmap/2026-08-01-steve-nicolai-feedback.md`.

**Kansas is missing its personal exemption**, confirmed to the cent. Both numbers reproduce from the config:

| | Calculation | Result |
|---|---|---|
| App | (50,000 − 8,240 std ded) × 5.2% | **$2,171.52** ← what he saw |
| Correct | (50,000 − 8,240 − **18,320**) × 5.2% | **$1,218.88** ← his math |

Verified against Kansas DOR (SB 1, 2024 special session): $18,320 MFJ, $9,160 single, $2,320 per dependent. Brackets and standard deduction were already right. **Overstates every married Kansas filer by $952.64 a year.**

**Acknowledged the same evening and confirmed the bug in writing.** That makes it a commitment, like Alan's caret fix. John also promised "answers and a plan" on all twelve items within a couple of days, so **due around 08-03.**

## 2. Backlog reconciliation, and three structural findings

Consolidated everything into `roadmap/2026-08-01-consolidated-backlog.md`, then **verified the July 13 multi-year backlog against `main` rather than trusting it.** It had gone stale: ten items were already fixed.

Three things were invisible in any single source:

**Kansas and backlog item I2 are the same defect in two code paths.** `StateTaxConfig` has no personal-exemption field at all, AND `postExemptionDeduction` appears *nowhere* in `ProjectionEngine.swift` (verified by absence). So multi-year drops the exemption even for New Jersey, where it does exist. Fix the config alone and Kansas comes out right in Scenarios and still wrong in Multi-Year, and the next user reports it from the other screen.

**Alan's NY government-pension gap and Steve's suggestion G are one problem.** A NYC pension is fully excluded while a private pension is capped; some of Steve's wife's 403(b) accounts are state-exempt and others are not. Neither is expressible because `RetirementIncomeExemptions` is per-state, not per-source. One design covers both. Separate patches would add two more hardcoded special cases beside NJ's.

**The decumulation gap now has three independent reporters:** Fred (07-14, grep-confirmed), Steve (#3, 08-01), and the in-code comment at `OptimizationEngine.swift:388-395`. And **Steve's suggestion C is the same gap expressed as a UI request** — an expenses page with funding rules. Fred's approved vision email is the design brief.

**Also verified as genuinely open, with evidence:** E8 is a real SALT-cap basis mismatch, not a suspicion (single-year `DataManager.saltCap:1747` uses `scenarioGrossIncome`; multi-year `MultiYearItemizedDeduction.swift:95` passes `agi` net of above-the-line, so two screens disagree for anyone with an HSA or deductible IRA contribution). F-SS and C5 have no implementation anywhere. I3 could not be confirmed either way and was left open rather than guessed.

## 3. LinkedIn post: ready, not posted

`drafts/linkedin/2026-07-31-widow-tax-arch-post.md`. Text final, graphic built, **posting deliberately deferred to Tuesday morning** because it was finished Saturday at 5 PM, close to the worst slot in the week for professional content. John's own note already said Tue-Thu morning.

**The hook took four iterations** and the adopted one is John's: *"You've heard the widow tax gets worse the more you have. I ran the numbers on three incomes through RetireSmartIRA. At the highest one, it isn't a tax at all. It's a discount."* All four candidates and why each was rejected are in the draft file.

**John caught the real flaw himself**: the first draft explained all three households, and the chart already prints all three numbers, so a reader finished having learned everything with no reason to click. Shortened so the giveaway is one insight (the rate rises in all three, only the dollars arch) and the withheld part is which band is worth planning around.

**A second, more designed infographic was rejected.** Reasons are recorded in the draft file because the same generator will reproduce them: a bold "(50% Increase)" that is actually 60%, a "volunteer-validated data projections" line describing something that never happened, decorative bar charts corresponding to no data, children in a retired-couple icon, hype contradicting the article's own thesis, and the loss of the arch itself. Built a vertical 1080x1350 branded replacement from the correct chart instead; HTML source is committed beside the PNG.

## 4. Other things that happened

**Commented on Bogdan Sheremeta's HumbleDollar piece** "$400,000 Mistake" (Aug 1), which covers step-up and joint tenancy versus community property. **That takes the topic off the table for the Day 7 pitch**, but its omission is the opening: it never mentions the §121 two-year window for a surviving spouse, and neither does John's own widow-tax article. The comment plants that topic publicly. Worth waiting a few days to see whether it draws replies before pitching, because "this came up in the comments" beats a cold proposal.

**Apex redirect fixed 307 → 308** via the Vercel API, since `vercel domains` does not expose redirect status codes. Root cause was an absent setting rather than a wrong one: `redirectStatusCode` was `null` and Vercel defaults to 307. Every www signal now agrees, including Google's own selected canonical.

**Personal research, no action needed:** John's own trust. The Urban Family Trust preserves community property character in three separate clauses, including one that explicitly converts prior joint tenancy to community property, and it has NO mandatory A-B split at first death. So the house and the Apple position both get the full double step-up. The only real exposure is the §121 two-year window for whoever survives. Also flagged that quasi-community property (they married in NJ in 1980) may behave asymmetrically depending on which spouse dies first, which is a question for the drafting attorney.

---

## Unpushed at session end

| Repo / branch | Commits |
|---|---|
| App `main` | 2: `af45404` caret, `25d7edd` Year-1 wipe |
| App `article/conversion-tax-funding-figures` | 10, unmerged |
| Website `main` | 4 doc commits |

## Owed in writing

- **Alan:** NY bug confirmed; caret fix slipped 2.3.0. Better from John than discovered.
- **Steve:** answers and a plan on 12 items, ~08-03.

## Suggested order for tomorrow

1. **`personalExemption` on `StateTaxConfig` + multi-state audit + I2**, as one change. Shipped error, written commitment, structural, fixes both code paths. Consider folding in E8 since it is the same single-year-versus-multi-year divergence in adjacent code.
2. **Per-source state exemption design** covering Alan's NY pension and Steve's 403(b) together.
3. **Decide the caret scope** (SettingsView only, or the other eight numeric screens), then cut build 64.
4. **Audit Steve #1 and #2.** Cheap; may not be bugs.
5. **Decumulation.** The big one.

TDD throughout; the state-tax suite is the gate. Full macOS suite was green at session end: 1,570 Swift Testing in 265 suites + 503 XCTest.
