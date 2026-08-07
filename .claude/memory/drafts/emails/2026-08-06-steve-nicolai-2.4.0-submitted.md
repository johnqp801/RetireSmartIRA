# Email to Steve Nicolai: 2.4.0 submitted to Apple

**SENT 2026-08-07, 4:57 PM**, from Support, subject "RetireSmartIRA 2.4.0 submitted to Apple".
John's edit of the controller draft, with three corrections applied. It went out BEFORE macOS was
approved, so it says both platforms are awaiting review. That was true when sent.
Subject: RetireSmartIRA 2.4.0 submitted to Apple

---

Steve,

As promised, I'm writing with the next release. Version 2.4.0 was submitted to Apple today for both
iPhone and Mac and is now waiting on review.

Your Kansas report is now fully addressed. The personal exemption went in earlier; this release adds
the rest. KPERS, federal, military, and Railroad Retirement pensions are excluded from Kansas income,
and a private pension is correctly not excluded.

There's one change you'll want to make once the update is live. In Income Sources the app now asks what
kind of pension you have, and the Kansas exclusion follows from that answer. There's a new option for a
pension from your own state or locality, which is where KPERS belongs. Until you classify a pension,
the app treats it as ordinary income.

Iowa is in as well, including its Roth conversion treatment.

Your suggestion about communicating state-model accuracy turned into the part of this release I'm
happiest with. Each state now has a page that shows exactly what the app applies for that state and tax
year, generated from the same data the engine uses, so it can't quietly drift. Below that it lists any
known limitations in plain language. Where a rule turns on something the app doesn't yet capture, for
example whether a pension was employer-funded or when you vested, the page says so instead of
presenting a number without that context. You can reach it from your results and from State Comparison.

The RMD display is cleaned up too. The summary now leads with whichever of you reaches RMD age first,
the chart shows you separately, and the CPA briefing no longer mixes one person's age with a household
figure. The tax math was always using both accounts correctly; the problem was the labeling, which
matters when that's what you read first.

Thank you for both reports and for the suggestion. The accuracy page was a terrific idea. Let me know
if you like the way the feature came out.

John

P.S. If you ever get the chance to mention RetireSmartIRA to friends or leave an App Store review, I'd
appreciate it.

---

## Choices worth preserving

- **SCOPED TO STEVE'S OWN ITEMS.** Nothing about how widespread any defect was, nothing about the other
  states in the same work. That rule exists because a previous draft was rejected over exactly this,
  and these testers post on Bogleheads.
- **NO APOLOGY FOR THE RMD NUMBERS, deliberately.** The tax math always used both accounts correctly;
  only the labelling was wrong. Apologising for wrong figures would have been apologising for something
  that did not happen.
- **"Your Kansas report is now fully addressed" rather than "Kansas is complete."** More accurate:
  scoped to what he reported. Two known caveats remain (Thrift Savings Plans are defined-contribution
  and still taxed; `ownStateOrLocal` goes stale on a residence change) and NEITHER touches a KPERS
  holder who classifies their pension, which is his case.
- **The classification step gets its own paragraph.** Without it he updates, sees no change, and
  concludes the fix did not work.
- **The promotion ask moved to a P.S.** so it does not sit inside the thank-you for unpaid work.
- Three corrections applied to John's draft: two em dashes removed, one comma splice fixed, and
  "state and year" corrected to "state and tax year" to match the page header.
