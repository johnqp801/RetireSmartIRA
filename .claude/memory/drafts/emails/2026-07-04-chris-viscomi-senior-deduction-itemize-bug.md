# Email to Chris Viscomi — senior deduction question surfaces itemize bug

**Sent:** 2026-07-04
**To:** Christopher Viscomi (Humble Dollar reader)
**Subject:** Re: Software question
**From:** support@retiresmartira.com

## Context

Chris read the Humble Dollar article and emailed asking whether the $6,000 OBBBA
senior deduction income phaseout was modeled in the app. Investigating the
question surfaced a real bug: the deduction (and its MAGI phaseout) was correctly
applied when a user took the standard deduction, but was silently dropped when
`scenarioEffectiveItemize` was true — itemizing 65+ filers under the phaseout
threshold were understating their real deduction and overstating tax owed.

Root cause + fix: `DataManager.totalItemizedDeductions` didn't include
`seniorBonusDeductionAmount`. Fixed same day by adding the bonus to that
property, which also made the standard-vs-itemized auto-recommendation
comparison bonus-neutral. New regression test
`SeniorBonusDeductionTests.seniorBonusAppliesWhenItemizing`. Full suite green
(1,164/1,164). Merged to `main` (commit `f88966b`, merge `32db2de`), pushed to
origin same day. Not yet in an uploaded/approved App Store build as of this
writing.

## Sent email (final)

```
Hi Chris,

Thanks so much for reading the Humble Dollar piece, and for the great question.

Yes: the $6,000 senior deduction (per person 65+, up to $12,000 for a married couple) is modeled, including the MAGI-based phaseout (starts above $75K single / $150K MFJ, phases out at 6%, effective 2025–2028) for users taking the standard deduction. Your question helped me uncover that it was not being correctly applied for users who itemize deductions. I've just written and fully tested a bug fix, which I'm submitting to Apple now for the next version release, pending their review.

Thanks again for the kind words on the article, and for putting the app through its paces. Your question resulted in a real positive outcome. Please don't hesitate to ask further questions, or let me know what you'd like to see in RetireSmartIRA in the future.

Best regards,
John
```

## Notes

- Deliberately transparent/specific about the bug in this personal reply — different
  call than the "never frame release notes as bug fixes" rule in CLAUDE.md, which
  is about public App Store copy. Crediting an engaged technical reader by name for
  finding a real issue builds trust here rather than undermining it.
- Follow-up owed: once the fix ships in an approved build, worth a short "it's live"
  note back to Chris if he doesn't notice on his own.
