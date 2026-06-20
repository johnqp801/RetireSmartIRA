# Email to Brian (relaying to Bob) — conceding NJ Worksheet D (Other Retirement Income Exclusion)

**Date:** 2026-06-18
**Recipient:** Brian (brother-in-law); relays to Bob (NJ tester). John communicates with Bob through Brian.
**Context:** Bob, testing 1.8.7 (build 55, ages 69 & 68), flagged that the engine wasn't applying NJ-1040 Worksheet D — the Other Retirement Income Exclusion, which lets the unused portion of the pension/retirement exclusion apply to interest/dividends when total income ≤ $150k and earned income ≤ $3,000. Verified against code: Bob is right; the engine only excludes pension + IRA income. Tracked in decision-log 2026-06-18 (NJ tax-completeness audit). This note concedes the point.
**Status:** Final (approved by John 2026-06-18).

---

Hi Brian,

Can you please thank Bob for me, he is absolutely correct.

My research did not surface Worksheet D, so the RetireSmartIRA engine wasn't applying the Other Retirement Income Exclusion. That is a real gap, and he identified it for me.

I'm adding it to the engine now, along with the two conditions that go with it (total income under $150,000 and earned income of $3,000 or less). This is exactly the kind of input that helps me close gaps I'd have missed on my own. When you send him a note, please also include that I would welcome any further input he may have in the future.

John
