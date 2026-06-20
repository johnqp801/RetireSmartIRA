# Email to Bob — conceding NJ Worksheet D (Other Retirement Income Exclusion)

**Date:** 2026-06-18
**Recipient:** Bob (NJ tester, via Brian)
**Context:** Bob, testing 1.8.7 (build 55, ages 69 & 68), flagged that the engine wasn't applying NJ-1040 Worksheet D — the Other Retirement Income Exclusion, which lets the unused portion of the pension/retirement exclusion apply to interest/dividends when total income ≤ $150k and earned income ≤ $3,000. Verified against code: Bob is right; the engine only excludes pension + IRA income. Tracked in decision-log 2026-06-18 (NJ tax-completeness audit). This email concedes the point.
**Status:** Final (approved by John 2026-06-18).

---

Thank you, Bob. You are absolutely correct.

My research did not surface Worksheet D, so the RetireSmartIRA engine wasn't applying the Other Retirement Income Exclusion. That is a real gap, and you identified it for me.

I'm adding it to the engine now, along with the two conditions that go with it (total income under $150,000 and earned income of $3,000 or less). This is exactly the kind of input that helps me close gaps I'd have missed on my own. Thank you again, and I would welcome any further input you may have in the future.

John
