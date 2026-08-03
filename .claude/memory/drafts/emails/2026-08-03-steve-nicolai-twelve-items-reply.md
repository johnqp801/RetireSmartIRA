# Steve Nicolai reply: his twelve items (thirteen with Iowa)

**Status:** drafted 2026-08-03, approved by John. Send from john@retiresmartira.com.
**Context:** he emailed support@ 2026-08-01 with 4 issues + 8 suggestions, then Iowa on 08-02.
John acknowledged the same evening and confirmed the Kansas bug in writing, promising
"answers and a plan over the next couple of days." This reply is two days late.

---

## What was deliberately CUT, and why it matters

An earlier draft told Steve that a 51-jurisdiction audit found roughly 29 defective states,
that no personal-exemption concept existed in the engine at all, and that Kansas was therefore
unlikely to be the only wrong state.

**John rejected that, correctly.** Steve is a user, not a shareholder, and he participates on
Bogleheads, which [[download-driver-attribution]] records as the app's number-one referral
source after the July 26 thread. Handing him "29 of 51 jurisdictions are defective" gives him a
quotable line that damages the app far more than his two reports ever did, and invites a forum
post about how bad the app was and who straightened it out.

**Rule going forward: scope user-facing replies to the user's own items.** Internal audit
findings are internal. Confirm what they found, fix it, tell them it is fixed. Do not volunteer
the blast radius.

## The commitment this email creates

It promises FOUR things in the next release:
1. Kansas personal exemption corrected
2. Iowa retirement exclusion corrected, including Roth conversion income
3. Per-state detail view (his suggestion F)
4. RMD calculator: spouse-aware summary and a chart that separates the two people

Items 1 and 2 are State Tax Phase 5 work; item 3 is Phase 6. This pulls them ahead of the rest
of the program. Item 4 is separate from the state tax program entirely and touches only
`RMDCalculatorView.swift`.

**Do not let this slip.** The caret fix already missed 2.3.0 after a written promise to Alan
Levy ([[pending-fixes-next-release]]), and that is exactly the pattern this email would repeat.

---

## FINAL TEXT (John's revision, approved 2026-08-03)

**Subject: Your Kansas and Iowa reports, and answers on the rest**

Steve,

Thank you for putting such thoughtful and detailed input into your emails. The product will be
better for it.

Kansas: you were right to the cent. The app was not applying the $18,320 joint personal
exemption, which is why you saw $2,171.52 where your $1,218.88 is correct. Fixed, and it will be
in the next release.

Iowa: also right, and it matters more than it first looks. Iowa excludes retirement income from
age 55 and names Roth conversion income specifically, so the app was showing tax on conversions
Iowa does not charge. It's now fixed as well and will be in the next release.

Your suggestion F is the one I most want to thank you for. Asking how accurate the state modeling
is, on the same day you found a state error, is a fair question, and the answer should not be
"trust us." The next release adds a per-state view showing how each type of income is treated
where you live, generated from the same data the calculations use so the two cannot drift apart.

On the RMD calculator: currently the summary at the top uses your age alone, so for a household
where a spouse reaches RMD age first it can say RMDs have not started when your wife's already
have. Also, the projected RMD chart does include both of you in the totals, but it draws them as
a single bar, so there is no way to see whose is whose or who begins when. Both are being
addressed in the next release. I am checking your Tax Summary point separately, since that may be
a third thing rather than the same one.

Your 403(b) point is being built now. You were right that it has to be a per-account property,
since some of your wife's accounts qualify and others do not.

Living off taxable withdrawals is a known gap and on my roadmap. I can't give you a firm date but
it's a priority.

On the taxable account yields, whether those percentages should also flow into single-year income
is a design question. I'm collecting input from other users as well.

Your A through D suggestions read to me as one argument rather than four, and I think you are
right that accounts should come first and that expenses deserve their own page with funding
rules. That is a larger restructure that I am putting on the prioritized roadmap along with your
donor advised fund idea and the federal bonds income type.

I'll email you when I submit the next release to Apple. Thank you again for the great input!

John

## What changed from Claude's draft, and why John's is better

John rewrote it and the result is stronger. Worth keeping the reasoning:
- **The close.** "I'll email you when I submit the next release to Apple" replaced a vague promise
  to write later. It gives Steve a concrete event rather than an open-ended wait.
- **Cut self-flagellation.** "For a conversion planning tool that is the one number you most need
  right" was removed. True, but it volunteers how bad the miss was.
- **"I'm collecting input from other users as well"** on the taxable-yield question is a better
  answer than describing it as unresolved: it is honest and commits to nothing.
- **Consolidated A-D, the DAF idea and federal bonds** into one prioritized-roadmap sentence
  rather than three separate deferrals.

Claude's edits on top: "succinct" to "detailed" (he sent twelve items, so succinct read as faint
praise); a comma splice split; the Tax Summary sentence restored, because Steve raised it
explicitly and dropping it answered two of his three RMD sub-points while silently skipping the
third; "road map" to "roadmap"; one double space.

## THE COMMITMENT LEDGER: five things, in the next release

1. Kansas personal exemption corrected        (State Tax Phase 5)
2. Iowa exclusion corrected, conversions too  (State Tax Phase 5)
3. Per-state detail view, suggestion F        (State Tax Phase 6)
4. RMD summary leads with whoever starts first (NOT in any plan yet)
5. RMD chart separates the two people          (NOT in any plan yet)

Plus the 403(b) work described as underway, which is Phase 3b.

Items 1 to 3 pull three phases of the state tax program forward. Items 4 and 5 are the least
specified and the most likely to slip, because they exist in no plan at all. That is precisely
how the caret fix missed 2.3.0 after a written promise to Alan Levy
([[pending-fixes-next-release]]). Plan the RMD work before the release is cut.

## The RMD diagnosis, corrected

My first diagnosis was WRONG and John caught it with two screenshots. I had guessed that Steve's
wife's accounts were not owner-tagged, so `spouseTraditionalIRABalance` read zero and the spouse
section was hidden. His screenshots show accounts correctly tagged Spouse, and the spouse block
rendering fine.

**The actual defects, verified in code:**

1. `RMDCalculatorView.swift:184` renders `"RMDs start in \(dataManager.yearsUntilRMD) years"`,
   the PRIMARY's number only. `spouseYearsUntilRMD` already exists at `ProfileManager.swift:160`
   and nothing on this screen reads it. For a household whose spouse is older and already
   required, that headline is wrong rather than merely incomplete.
2. `RMDCalculatorView.swift:777` declares one `var regularRMD: Double = 0`, adds the primary's
   RMD, then adds the spouse's into the SAME accumulator. One series, labelled "IRA / 401(k)".
   The math includes both; the attribution is invisible.
3. Tax Summary spouse RMDs: NOT YET VERIFIED. Steve says they are absent. Check before claiming.

**Precedent worth reusing:** the Retirement Drawdown chart on the same screen already plots
"RMDs begin" and "Spouse RMDs" as separate markers, so the app already computes both dates.

**Fix shape:** status card leads with whoever starts sooner and shows both when the spouse holds
traditional balances; chart emits two series instead of summing, since the per-person math
already runs inside that loop. Self-contained to `RMDCalculatorView.swift` plus whatever the Tax
Summary check turns up.
