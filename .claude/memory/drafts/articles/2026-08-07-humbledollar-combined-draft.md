# HumbleDollar submission: "Paying 17.4% in a 12% Bracket"

**Status:** drafted 2026-08-07, tightening pass applied same day. Working candidate, NOT approved,
NOT submitted.
**Supersedes** the two competing angles in `2026-08-07-humbledollar-conversion-funding-two-drafts.md`,
kept on file as evidence of what was tried.

**Shape:** Draft B's argument wrapped around Draft A's discovery, then compressed. Body is roughly
1,000 words, down from about 1,450, with the rhetorical scaffolding cut and the strongest numbers
given room.

**Every dollar figure is pinned** by `ConversionTaxFundingArticleScenarioTests` on `main` @ `54fce6d`.
Dianne is a composite. Florida and California are the same profile with only the state changed.

## Revision history

**Round 1 (combine):** B's thesis and close around A's $40,000 discovery; the categorical
*"a two point gap does not survive a seventeen percent incremental cost"* removed; 24 percent made
unmistakably the illustration's own election.

**Round 3 (final):** Dianne is "a composite rather than a **real person**", not "rather than a
client." John's call. He has no clients, and the old phrasing implied an advisory relationship he does
not have. The archived two-angle file still carries the original wording as the record of what was
drafted; **do not copy the persona sentence from there.** The published website article says "She is a
composite, not a client" and is a candidate for the same change.

**Round 2 (tighten):** opening cut from six paragraphs to five short ones and led with the
condition-not-advice distinction; *"What I found first was not what I expected"* and the other
template phrases removed; "The stranger part" folded into the first case at half the length;
California reconciliation replaced with a compact table; Medicare led with its dollar result; the
withholding note moved ahead of the conclusion so the article ends on its argument.

## A labeling defect John caught, and it is also live on the website

**`TaxBreakdown.total` is `federal + state + irmaa`** (`MultiYearValueTypes.swift:42`). So any row
labeled "total tax" at the $150,000 size is **income tax plus a Medicare premium surcharge**, which
are different things, and the article otherwise keeps them apart carefully.

Decomposed:

| $150,000, funded from the IRA | Florida | California |
|---|---:|---:|
| Income tax (federal + state) | $40,849.37 | $65,130.59 |
| IRMAA surcharge | $6,355.20 | $6,355.20 |
| Sum, published as "total tax" | $47,204.57 | $71,485.79 |
| Funding withdrawal | $45,469.37 | $69,750.59 |
| Unfunded remainder | $1,735.20 | $1,735.20 |

The withdrawal funds income tax plus the **baseline** $4,620 surcharge, the tier she occupies anyway.
The $1,735.20 left over in both columns is the surcharge increase she caused, which the gross-up
deliberately does not fund. That is what `irmaaIsNotFundedByTheGrossUp` pins, and it is why the figure
is identical in a no-tax state and a high-tax one.

**Fix applied here:** the row is gone with the rest of the table, since **HumbleDollar does not run
tables**. The comparison is now three sentences of prose carrying $195,469, $219,751, $1.30 and $1.47.
$45,469 was dropped entirely (nothing downstream needed it) and $69,751 survives in the next
paragraph, where the incremental-cost argument requires it. No figure labeled "total tax" appears
anywhere in the piece, so the surcharge keeps its own paragraph and its own name.

**Not fixed, and it should be:** the published website article carries the same label in at least four
places, all at the $150,000 size where IRMAA is non-zero. `CA_150K` rows "Total tax, funded from
outside cash" ($44,639) and "Total tax, funded from the IRA" ($71,486), the "+$26,846" additional-tax
row, and the withholding paragraph's "$51,980 of total tax." **The $40,000 Florida figures are clean**
(IRMAA is zero there, so $4,234 and $5,125 really are income tax). This is a wording correction on
retiresmartira.com, not a figure correction: every number stays, the labels need to say "tax and
Medicare surcharge" or split into two lines.

**If John wants the split shown in print,** $40,849 / $65,131 are derivable from the emit test but are
not themselves pinned. Publishing them means adding pins first, per the standing contract that no
published figure goes out undefended.

## Two claims corrected against the code rather than transcribed

**1. The $891 is not all Social Security.** The suggested wording was *"The extra $891 is not simply
the normal gross-up. It is the additional IRA withdrawal caused by Social Security becoming more
taxable."* The pinned test asserts the added tax equals 12 percent of (withdrawal + benefit dragged
in): `0.12 x (5,125 + 2,300) = 891`. So **$615 is the plain gross-up and $276 is the Social Security
effect.** What the Social Security effect owns is the **5.4 percentage points**, not the $891. The
draft now decomposes it explicitly.

**2. $4,620 and $6,355 are surcharge only.** `TaxCalculationEngine.calculateIRMAA`
(`TaxCalculationEngine.swift:898`) computes `surchargeB = partBMonthly - standardB` and adds the Part D
IRMAA amount. With 2026 config values tier 3 is `(527.50 - 202.90) + 60.40 = $385.00/mo = $4,620` and
tier 4 is `(649.20 - 202.90) + 83.30 = $529.60/mo = $6,355.20`. **Neither includes the standard Part B
premium of $202.90 a month**, so calling either figure her "annual Medicare cost" would be wrong. The
returned value is `annualSurchargePerPerson`, so it is per person; Dianne is single, so it is hers
alone. The draft says surcharge, says it sits on top of the standard premium, and says it is one
year's.

---

## THE ARTICLE

**Paying 17.4% in a 12% Bracket**

EVERY ROTH-CONVERSION article says the same thing: pay the tax from taxable money, not from the IRA.

That is good advice if you have taxable money.

Plenty of retirees do not. Their savings sit almost entirely in a traditional IRA, built from years of
401(k) contributions and a rollover at retirement, with little brokerage money and no cash reserve
worth naming. For them, "pay from outside money" is not advice. It is a condition they do not meet.
Their real choice is a self-funded conversion or no conversion at all.

The familiar warning is that self-funding requires a gross-up. You withdraw money to pay the
conversion tax, that withdrawal is itself taxable, so you have to withdraw a little more.

Less discussed is what else that withdrawal sets off. It makes more of your Social Security taxable,
it raises your Medicare premiums two years later, and in a high-tax state it enlarges the amount that
has to leave the IRA. Here is what those three cost, on one household.

**A cautious conversion**

Meet Dianne, a composite rather than a real person. She is 66, single, retired to Florida, with $1,000,000
in a traditional IRA and nothing outside it. Social Security pays her $28,000 a year. She is past 59
and a half and already on Medicare. Florida keeps state income tax out of the arithmetic for now.

She converts $40,000. Careful, modest, the size people choose when they are trying not to do anything
dramatic.

The tax on that conversion, paid from a checking account she does not have, would be $4,234. Funding
it from the IRA instead, the withdrawal that covers it is $5,125, and her tax rises to match.

That extra $891 is 17.4 percent of the $5,125 she withdrew. Her ordinary-income bracket is 12 percent.

Twelve of those points are the tax on the withdrawal itself, which is the gross-up everybody expects.
The other 5.4 come from $2,300 of her Social Security being pulled into taxable income by that same
withdrawal. Paying from cash, $21,500 of her benefit would be taxable. Self-funding, $23,800 is. The
difference is caused by how she paid, not by what she converted, and nothing on her return will label
it.

**Not a smaller version of a large one**

The effect is not linear. Run the same woman at $150,000 and 85 percent of her benefit, the statutory
maximum, is already taxable before she funds the tax. The funding withdrawal drags in nothing further,
and this particular cost is zero.

That is not an argument for converting more. It is an argument against assuming a small conversion is
simply a smaller version of a large one. The one that looks cautious can carry the higher marginal
rate.

**What self-funding actually costs**

Give Dianne the $150,000 conversion, still with no outside cash, and add the state question.

Still in Florida, $195,469 has to leave the traditional IRA to put $150,000 into the Roth. Move her to
California, changing nothing else, and it is $219,751. That is $1.30 of IRA spent for every dollar
reaching the Roth, against $1.47, and the gap is California income tax compounded through the
gross-up. If a move across state lines is anywhere in your plan, the order of operations may matter
more than the size of the conversion.

But $1.47 invites a conclusion it does not support, and I would rather correct that myself than let it
travel. A conversion is taxable whichever pocket pays. Of the $69,751 Dianne withdraws in California,
roughly $44,639 replaces cash she would have spent anyway. The incremental cost of self-funding, in
wealth given up, is $25,111. About 17 percent of the conversion, not 47.

**The bill that arrives in 2028**

Self-funding also costs Dianne $1,735 in higher Medicare premiums, a surcharge of $6,355 rather than
$4,620, charged on top of the standard premium, for one year, and hers alone as a single filer.

The bill arrives two years late. Medicare sets her 2028 premiums from her 2026 income, so the cost is
invisible at the moment she is deciding how to pay the 2026 tax.

**When it can still make sense**

Doing nothing is not free either. Money left in a traditional IRA comes out eventually, under required
distributions, at whatever rates apply then, possibly to a survivor filing single, possibly to heirs
facing a ten-year deadline.

Where self-funding still holds up, a few things tend to be true.

The rate gap is durable rather than a one-year accident. Whether it repays a cost this size depends on
time, future tax rates and investment returns. A temporary dip in income is a thin foundation. A
structural window, after retirement and before Social Security or required distributions begin, is
more compelling.

There is runway, because shrinking the portfolio to change its tax character needs years of tax-free
growth to earn back.

Age 59 and a half is cleanly behind you. The converted amount is not subject to the 10 percent
additional tax on early distributions. A separate distribution taken to pay the tax generally is,
unless an exception applies.

And enough is left afterward. Check the balance after the funding withdrawal, not after the
conversion. Dianne's California IRA drops to $780,249, and whether that funds the next thirty years
matters more than whether the conversion was tax-efficient.

**A practical warning about withholding**

Withholding from the conversion is not a cheaper way to pay the tax. It reduces what reaches the Roth.
Elect 24 percent on Dianne's $40,000 conversion, as this illustration does rather than as any
custodian requires, and $9,600 goes to the IRS while $30,400 lands in the Roth, against $4,234
actually owed. The cash comes back next spring as a refund. The Roth room does not come back at all.

**Restating the rule**

Pay the conversion tax from outside cash if you have it. That remains the best answer.

It is not an answer for the retiree whose savings are almost entirely in a traditional IRA. For that
person, "never pay from the IRA" skips the actual decision, which is whether a self-funded conversion,
with its full marginal cost, beats leaving the money where it is.

Before deciding, count the gross-up, the Social Security effect, state tax and the Medicare bill two
years later. Sometimes that arithmetic still says no. It beats applying a rule written for somebody
with a different balance sheet.

---

## FOR THE FACT-CHECK, NOT FOR THE BODY

Claims carrying no regression test. Sources to verify before submission:

| Claim | Source to check |
|---|---|
| Taxable portion of a benefit capped at 85 percent | IRC §86(a)(2); IRS Pub. 915 |
| 2026 income sets 2028 Medicare premiums | 42 U.S.C. §1395r(i); SSA uses the most recent return available, generally two years prior; CMS 2026 amounts |
| The surcharge lasts one year for a one-year income spike | IRMAA is redetermined annually from the most recent return, so premiums revert when income does. **Mechanical, not engine-verified. Confirm before publication.** |
| Converted amount not subject to the 10 percent additional tax | IRC §408A(d)(3)(A)(ii); IRC §72(t) |
| A separate distribution taken to pay the tax generally is | IRC §72(t) and its exceptions |

**One nuance to raise with a tax professional.** The age 59 and a half sentence is deliberately
narrow, and there is a wrinkle it does not address: under IRC §408A(d)(3)(F) a distribution of
*converted* amounts within five years can itself attract the 10 percent additional tax for someone
under 59 and a half. Dianne is 66, so no engine run here exercises any of it. If the piece keeps that
condition, the recapture rule is the likeliest source of a correction in the comments.

**Not claimable anywhere:** the gross-up solved here is a real fixed point over federal and state tax
with benefit taxation recomputed inside it, but it does **not** enlarge itself when the funding
withdrawal crosses a Medicare or ACA threshold. The article never says otherwise, and the 2028 section
says as much in plain words.

## Open questions for John

1. **"Tax torpedo" was cut.** The term is familiar to this readership and appeared in the widow-tax
   piece, but the draft now explains the mechanism in plain words instead. Adding it back costs three
   words if you want the shorthand.
2. **Tables are out**, per John: HumbleDollar does not run them. The Florida/California comparison is
   prose. Two alternatives were considered and not used: splitting it across two paragraphs (more air
   around the jump, about 20 words longer), and leading with the ratio rather than the dollars (reads
   well, but buries $219,751, which is the most quotable number in the piece).

## Byline

Body carries no product mention, matching the July 4 placement. John founded GT Nexus (supply-chain
SaaS, acquired by Infor in 2015) and now builds RetireSmartIRA.
