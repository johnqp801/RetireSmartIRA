# 2026-08-07 — Roth-conversion-funding article figures verified, test branch merged

**`main` @ `54fce6d`, pushed to origin, working tree clean.** Short session, one job: confirm the
published figures in "Paying Roth Conversion Tax From Your IRA" still hold after V2.4.0 moved a large
amount of state-tax and engine code, then land the tests that defend them.

## 1. The published figures are still correct

`ConversionTaxFundingArticleScenarioTests` lived only on `article/conversion-tax-funding-figures`, so
the file was copied onto `main`'s working tree to run it there. Both byline suites green against
`main` @ `44e260c`:

```
Swift Testing:  Test run with 21 tests in 2 suites passed
XCTest:         Executed 0 tests, with 0 failures
```

10 conversion-funding tests plus 11 in `WidowTaxArticleScenarioTests`.

The EMIT test's figure table was regenerated and checked line by line against what is live on
retiresmartira.com. **Every published number reproduces to the dollar:**

| Published | Engine on `main` |
|---|---|
| CA $150k funded from accounts, gross-up **$69,751** | 69,750.59 |
| …total tax **$71,486** | 71,485.79 |
| …**$1.47 per dollar converted** ($219,751 leaving the IRA) | 219,750.59 / 150,000 = 1.465 |
| CA $150k paid from outside, **$44,639** | 44,639.36 |
| CA $150k withheld, **$51,980** | 51,979.66 |
| FL $150k funded: **$45,469** gross-up, **$47,205** total, IRMAA **$6,355** | 45,469.37 / 47,204.57 / 6,355.20 |
| Ending traditional balance **$780,249** | 780,249.41 |
| FL $40k: **$4,234** vs **$5,125**; taxable SS $21,500 → $23,800 | exact |
| CA $40k withheld, gross-up **$891** | 891.44 |
| Roth ending **$30,400** / **$114,000** under withholding | exact |

The two tests that check *reasoning* rather than arithmetic also still hold. The 12% statutory bracket
reaching an effective **17.4%** is still exactly 12% of (withdrawal + benefit dragged into
taxability), which is what makes the article's "this is a feedback effect, not a bracket" claim true.
And the unfunded remainder at $150k is still exactly the self-caused IRMAA increase and nothing else,
so the article may still say the gross-up does not fund the tier it crosses.

**Nothing in V2.4.0 disturbed this piece. No correction is owed.**

## 2. What in the article still has NO test behind it

Unchanged from the file header, and this is the list a HumbleDollar adaptation has to re-check by
hand, because the suite will not catch an error in any of it:

- "At most 85 percent of a benefit is ever taxable" — IRC 86, statutory.
- The entire under-59½ discussion (10% additional tax, IRC 72(t)). **Dianne is 66, so the engine never
  executes that path.**
- "IRMAA on 2026 income is billed through 2028 premiums" — program rule.
- Withholding rates. 24% is what the model elects, not a custodian standard.
- The four "what has to be true for self-funding to make sense" conditions, and every comparison to
  the do-nothing alternative (future RMDs, survivor filing single, the heirs' 10-year deadline). No
  projection was run for any of them.

Also still true and worth not overstating: the gross-up is a real fixed point over federal AND state
tax with benefit taxation recomputed inside it, but it does **not** enlarge itself when the funding
withdrawal crosses an IRMAA or ACA cliff. Those are frozen in the sizing loop by design.

## 3. The merge

`article/conversion-tax-funding-figures` merged with `--no-ff`. **Net effect on `main`: one file, 370
lines.** No engine or app code.

Five docs on the branch also existed on `main` in newer form and conflicted add/add. **`main`'s copy
was kept in every case, after checking rather than assuming.** Three differed by insertions only. The
two where `main` had deletions dropped exactly two things, both correctly superseded:

- a stale `**Status:** … Not yet posted.` header on the widow-tax LinkedIn draft, which has since been
  posted;
- Phase 1 plan steps that were revised as Phase 1 was actually built (a deferred round-trip test, the
  Xcode-target drag instructions, an early bundle-loading sketch).

Nothing on the branch was lost. This was checked deliberately: the July near-loss of two orphaned
memory records came from exactly this shape, docs-only commits on a long-lived side branch.

**Full suite green before the merge commit: 2,094 Swift Testing in 308 suites + 509 XCTest, 0
failures.** That is precisely +10 tests and +1 suite over the V2.4.0 ship point, which is the article
file and nothing else.

Branch then deleted locally and on origin.

## 4. One snag worth remembering

The first `git push` and the branch delete both ran from `~` rather than the repo. The push reported
success (`c631e0f..44e260c main -> main`) because it came from a different checkout sitting at the
pre-merge commit; the delete failed outright with `fatal: not a git repository`. **A push that prints
a successful-looking range is not evidence your merge went up.** Verified afterwards by fetching and
comparing `origin/main` to the expected SHA, which is the only check that actually settles it.

Order matters here too: deleting the remote branch before `origin/main` carried the merge commit would
have dropped origin's only copy of those 16 commits.

## Open

Unchanged from 2026-08-06:

- **Alan Levy's note**, still owed, still waiting on iOS approval of V2.4.0 (macOS is live). Say
  plainly that the 2.3.0 partial caret fix was session-order dependent, not merely incomplete.
- **The HumbleDollar adaptation itself has not been started.** No draft exists. The website article is
  the source; the untested-claims list above is what to verify by hand before submitting.
- V2.4.1 items in `roadmap/2026-08-06-v2.4.1-accuracy-page-followups.md`; Phase 6 charter in the Phase
  5b ledger; Vermont still the largest unclaimed win at $5,211.50/yr, VT-7 specified.

**HumbleDollar etiquette, unchanged:** never mention RetireSmartIRA when replying to comments on
John's own byline articles. Peers, not prospects.
