# 2026-07-30 — orphaned-memory rescue, root-workspace sync, article figure tests

App-repo side of a session whose main body was the website SEO program. Full detail of that work lives in the website repo at `.claude/memory/sessions/2026-07-30-seo-program-days-1-to-5-shipped.md`.

---

## 1. Two memory records were orphaned and nearly destroyed

`root-workspace` was **94 commits behind `main`** and still checked out at the project root, which is where `CLAUDE.md` and `.claude/memory/` live. Reading memory from the repo root was therefore returning a pre-V2.3 picture.

Syncing it looked trivial. It was not: `git diff main root-workspace` showed 643 insertions, and two of them were real.

**Rescued to `main` @ `0698d53`, purely additive (23 lines, nothing touched):**
- `sessions/2026-07-27-rmd-chart-axis-spouse-ownership-and-humbledollar-thread.md`, absent from `main` entirely
- The **2026-07-26 decision entry** recording that selectable Roth tax-payment source was committed in writing to a customer, plus the five-finding code audit behind it. `main`'s decision log jumped 07-22 to 07-28.

**Why they were orphaned:** the V2.3 branch was cut from an earlier commit, so these docs-only commits on `root-workspace` never rode the merge.

Everything else on `root-workspace` was verified stale before the reset: press methodology wording, the 2.3 release-notes checklist, the B2 backlog entry, the plan doc, and a source tree still at 2.1.1/build 61. The two RMD fixes survived because they had been cherry-picked onto the 2.3 branch.

`root-workspace` then reset to `main`. Old tip `5bbc6d6` is in the reflog.

**Lesson worth keeping:** this is the second time these two records were nearly lost, and the first near-loss is itself recorded in `pending-fixes-next-release`. Docs-only commits on a long-lived side branch do not survive a merge cut from an earlier point. Check `git diff --diff-filter=A main <branch>` before resetting anything.

## 2. `ConversionTaxFundingArticleScenarioTests`

Branch `article/conversion-tax-funding-figures`, pushed, **not yet merged to `main`**. Test-only, no engine changes.

Pins every published figure in `/articles/paying-roth-conversion-tax-from-your-ira`, following the `WidowTaxArticleScenarioTests` contract: a failure means the published article is now wrong and needs correcting, never that the expected value should be updated.

Persona "Dianne" and her **full income composition** are written into the file, because the widow-tax article lost real time to a $2,876 false alarm when a draft omitted a household's Social Security.

10 tests. The two that matter most are not simple number pins:

- **`socialSecurityFeedbackFigures`** asserts the *derivation*, not just the result. The article claims a 12% statutory bracket pays an effective 17.4%, and that the gap is a feedback effect rather than a bracket. The test checks that the added tax is exactly 12% of (withdrawal + benefit dragged in), which is what makes the claim true.
- **`irmaaIsNotFundedByTheGrossUp`** pins a documented *limit*. The unfunded remainder is exactly the self-caused IRMAA increase and nothing else. If the sizing loop ever changes, this surfaces as a claim the article can no longer make.
- **`incrementalCostIsSmallerThanTheHeadlineRatio`** measures $25,111 as net wealth rather than tax (they differ by the $1,735 of IRMAA not billed until 2028) and asserts it is strictly smaller than the tax delta. An inversion would mean the article's framing is wrong, not just its arithmetic.

The file header also enumerates **what in the article is NOT engine-backed** and therefore has no test defending it: the 85% statutory ceiling, the whole under-59.5 penalty discussion (the persona is 66, so that path never executes), the IRMAA billing lag, withholding rates (24% is the model's default, not a custodian standard), and every comparison to the do-nothing alternative.

## Verification

Full macOS suite green after the work: **1,575 Swift Testing tests in 265 suites + 503 XCTest, 0 failures.** Up from 1,565; the 10 added are the article pins.

## Open

- **Merge `article/conversion-tax-funding-figures` into `main`.** Test-only, no urgency, but it should not linger the way the orphaned records did.
- `main` is pushed and current at `0698d53` plus that branch.
