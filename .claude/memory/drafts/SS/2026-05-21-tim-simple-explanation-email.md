# Simple email to Tim — why SSA and RetireSmartIRA differ for Jen

**Date:** 2026-05-21
**Recipient:** Tim
**Context:** Plain-language follow-up explaining the Jen age-65 discrepancy
(app $1,466 vs SSA $1,381) and the fix.

---

## Final email text (corrected)

Subject: Quick answer on the Jen Social Security difference

Tim —

Here's the difference between the two:

In SSA, the calculator has full access to Jen's complete work history. In
RetireSmartIRA's Quick Entry, you enter just three numbers, and the app uses
those to calculate everything else.

That shortcut works well for people who don't have a large number of blank
(zero) earning years — but that's not Jen's case. Her 20 years of
capital-gains-only income count as zeros in the Social Security math, so her
benefit at earlier claim ages is genuinely lower than the three-number
shortcut assumes.

That's the reason we built the ability to import her XML file from ssa.gov,
or paste her earnings history into the app. Once RetireSmartIRA has the same
full work history SSA has, it runs the same formula on the same data — so it
should land very close to SSA's number. One thing to match up: the app will
ask how many more years Jen plans to work and at what income — set that the
same way SSA assumes, and the results should line up.

Your experience highlighted the need to add a flag into RetireSmartIRA for
cases like Jen's, so the app points users with gappy earnings histories
straight to the earnings import.

Thanks again for catching this — really helpful.

— John

---

## Cross-references

- PDF guide: `.claude/memory/drafts/SS/2026-05-21-tim-ss-calculator-guide.pdf`
- Full technical diagnosis: `.claude/memory/drafts/SS/2026-05-21-tim-jen-discrepancy-diagnosis.md`
- v1.8.5 candidate: Quick Entry flag for irregular earnings histories
