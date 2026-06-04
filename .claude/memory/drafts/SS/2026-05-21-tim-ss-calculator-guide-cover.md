# Cover message to Tim — sent with SS Calculator Guide PDF

**Date:** 2026-05-21
**Recipient:** Tim (retired military, tester)
**Attachment:** `2026-05-21-tim-ss-calculator-guide.pdf` (5 pages)
**Context:** Tim asked via text whether the app can compute spousal benefit off the higher
earner's earnings like ssa.gov does. He also reported a discrepancy: Jen's estimate at age
65 is "a couple hundred dollars more" in the app than on ssa.gov. The PDF answers his
original question; this cover message asks him to follow the PDF steps and report back
specifics on the Jen discrepancy.

---

## Final message text

> Tim — thanks for trying it. I put together a short walkthrough (attached) covering exactly
> what the calculator does and step-by-step instructions, including the spousal-benefit math
> for the higher-earning-spouse case you asked about. It also has an honest list of what the
> app *doesn't* model — short version: the WEP/GPO concerns don't apply to you since
> military service is SS-covered, so the standard calculation should be correct.
>
> **On the Jen discrepancy** — a couple hundred dollars is too big to be rounding, so
> something specific is off. Could you do me a favor and re-run her numbers using the steps
> in the PDF, then send me a screenshot or four so I can pin it down?
>
> Specifically, what would help:
>
> 1. **Her date of birth** as you entered it in the app (My Profile → Spouse). A wrong year
>    by one changes both her Full Retirement Age and the bend points used in the formula,
>    which can shift the result by exactly the kind of amount you're seeing.
> 2. **A screenshot of ssa.gov's estimate at age 65 for Jen** — the exact number SSA is
>    showing.
> 3. **A screenshot of the app's Social Security inputs page for Jen** — showing the three
>    SSA numbers (at 62, FRA, 70) you entered, or, if you used Earnings History, the
>    calculated PIA result.
> 4. **A screenshot of the app's Claiming Analysis view for Jen** — that's the per-spouse
>    view that lists all nine claim ages 62–70 in a table. Page 5 of the PDF describes how
>    to get there.
>
> One quick diagnostic you can try yourself: if you used Quick Entry, try Path A (Earnings
> History) too — import her XML or paste her earnings table. If the calculated PIA differs
> from the SSA-statement FRA number you entered, that tells us SSA is assuming different
> future earnings for her than you (or she) entered. If they match but the age-65 number
> still differs from SSA's site, that points to a different cause.
>
> No rush. This is exactly the kind of tester report that drives the next release —
> appreciate you taking the time.
>
> — John

---

## Internal notes — what each requested screenshot tells us

- **DOB:** wrong birth year → wrong FRA (months-early calc) + wrong bend points (different
  PIA from same AIME). Highest-likelihood root cause for a "couple hundred dollars"
  discrepancy.
- **SSA's age-65 number:** exact reconciliation target.
- **App inputs page:** confirms which path he used (Quick Entry vs Earnings History) and
  what numbers were entered.
- **Claiming Analysis view:** if age 65 is off but 62/FRA/70 match SSA, points to the
  early-claim reduction formula. If all four differ proportionally, points to either DOB
  or the entered FRA value.

## If the discrepancy is real (not data entry)

This goes into the TriSTAR tester-feedback loop. Possible v1.8.5 patch candidate. Until
Tim reports back with specifics, we can't classify whether it's:
- User-input mismatch (most likely)
- A UI gap (e.g., DOB and entered benefits don't reconcile — could warrant a warning)
- A real calculation bug

## Cross-references

- PDF guide: `.claude/memory/drafts/SS/2026-05-21-tim-ss-calculator-guide.pdf`
- Earlier Tim outreach drafts: search `.claude/memory/drafts/` for "tim"
- TriSTAR Protocol: `.claude/memory/policy/state-tax-accuracy-tristar-protocol.md`
  (tester-feedback loop is the 5th verification source)
