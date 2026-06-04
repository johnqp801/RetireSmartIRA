# Reply to Tim — Jen age-65 SS discrepancy diagnosis

**Date:** 2026-05-21
**Recipient:** Tim
**Context:** After receiving the SS Calculator Guide PDF, Tim sent three screenshots
showing the discrepancy between the app and ssa.gov for Jen at age 65:

- **App:** $1,466/mo (own benefit at 65)
- **SSA:** $1,381/mo at age 65
- **Both agree:** Age 62 ($1,017), FRA/67 ($1,692), Age 70 ($2,283)
- **Jen's DOB:** Sep 4, 1968 → FRA = 67. Age 65 = 24 months early.
- **Jen's earnings pattern:** 20 years of capital-gains-only (no SS-covered earnings,
  count as zeros in top-35), recently W-2 via S-corp conversion. Earnings will continue
  through FRA.

## The diagnosis (math)

App's $1,466 = $1,692 × (1 − 24 × 5/9 × 1%) = $1,692 × 0.8667. Internally consistent.

SSA's $1,381 implies PIA at 65 of $1,593 (= $1,381 / 0.8667), versus PIA at FRA of $1,692.
The $99 PIA gap reflects ~2 additional W-2 years (between 65 and 67) replacing zero years
in Jen's top-35 calculation. SSA assumes she stops at 65 for the age-65 projection; the
app's Quick Entry path doesn't, because it treats the entered FRA estimate as a single
fixed PIA.

**This is not a calculation bug. It's a Quick Entry limitation that becomes material for
users with irregular earnings histories** (gaps, late starts, S-corp conversions, etc.).

## TriSTAR finding — v1.8.5 candidate

Add a hint or warning in Quick Entry when:
- Planned claim age ≠ FRA, AND
- Earnings history is empty (user hasn't done Path A)

Suggested copy:
> "For more accurate results when your planned claim age differs from FRA, use the
> Earnings History import — especially if your earnings record has gaps or recent changes."

Alternatively (more aggressive): show the inconsistency itself when Tim could detect it —
i.e., warn that "claim at 65" implicitly assumes stopping earnings at 65, but Quick Entry
doesn't model that.

## Final message text

> I worked through the math against the screenshots, and **the app isn't wrong — but it's
> using a simplifying assumption that breaks down in Jen's case specifically**. Tim's
> report has actually surfaced a real modeling nuance worth fixing in the next release.
> Here's what's happening:
>
> **What the math says**
>
> Jen's DOB: Sep 4, 1968 → FRA = 67. Age 65 = 24 months early.
>
> The app's formula: takes the FRA value you entered ($1,692) as her PIA, then applies
> the standard early-claim reduction: 24 months × 5/9 of 1% = 13.33% reduction → $1,692 ×
> 0.8667 = **$1,466.40**. That matches what the app shows.
>
> SSA's $1,381 at age 65: reverse-engineering — $1,381 / 0.8667 = **$1,593** implied PIA
> at age 65, vs. $1,692 PIA at FRA. So SSA is using a different (lower) PIA for the
> age-65 projection than for the FRA projection.
>
> **Why SSA's PIA differs by claim age (and why this matters for Jen specifically)**
>
> PIA is computed from your top 35 *indexed* earning years. Jen has 20 years of
> cap-gains-only (no SS-covered earnings → those years count as **zeros** in the top-35
> calculation) followed by recent W-2 income through the S-corp.
>
> When SSA projects:
> - **At FRA (67):** assumes she keeps W-2 earnings to 67 → ~9 more positive years
>   replace 9 zeros → higher PIA → **$1,692**
> - **At 65:** assumes she stops at 65 → only ~2 more positive years replace 2 zeros →
>   lower PIA → ~$1,593, then 13.33% reduction = **$1,381**
>
> So SSA's $1,381 isn't *just* applying an early-claim reduction — it's also recomputing
> her PIA under the assumption she stops earning at 65.
>
> The app, when you use Quick Entry, only knows one PIA number ($1,692, which you entered
> as the FRA value). It applies the early-claim reduction to that single PIA regardless
> of claim age — which is fine for someone with a long full-earnings history but
> **overstates the age-65 figure for someone like Jen with a lot of zero years still
> being replaced**.
>
> **The fix: do the Earnings History import (Path A in the PDF)**
>
> This is exactly the case the Earnings History path was built for. When you import her
> actual earnings record:
>
> 1. Tap **Import Earnings** on Jen's page
> 2. Log into ssa.gov/myaccount → download her XML
> 3. **Future-earnings projection:** enter her current annual W-2 amount and **set
>    "years remaining" to 2** (meaning she works through 65, then stops)
> 4. Save
>
> That should produce an age-65 figure close to SSA's $1,381.
>
> Then, as a second test, do it again with **years remaining = 9** (works to FRA at 67).
> That second run should match SSA's FRA $1,692 number — and the age-65 figure from
> *that* run will be higher (around $1,466), matching what Quick Entry currently shows.
> That's the "if she keeps working to FRA but claims at 65" scenario, which is a coherent
> but uncommon planning choice.
>
> **Why this is useful feedback**
>
> You've found a real limitation in Quick Entry for non-standard earnings histories. The
> app should probably warn users in Jen's situation — "You have a planned claim age
> different from FRA. If your earnings history has gaps, Earnings History import will
> give a more accurate result." That's going on the v1.8.5 list as a UI improvement.
>
> Try the Path A test and let me know what number it produces. If it lands near $1,381 —
> confirmed: app behaves as expected, the "bug" is really just a Quick Entry limitation
> we should disclose more clearly. If it comes back different, then there's something
> else going on and we keep digging.
>
> Thanks for the detailed screenshots — this is exactly the kind of report that actually
> makes the next release better.
>
> — John

## Cross-references

- PDF guide: `.claude/memory/drafts/SS/2026-05-21-tim-ss-calculator-guide.pdf`
- Cover message: `.claude/memory/drafts/SS/2026-05-21-tim-ss-calculator-guide-cover.md`
- TriSTAR Protocol (tester feedback loop): `.claude/memory/policy/state-tax-accuracy-tristar-protocol.md`

## Open follow-ups

1. **Await Tim's Path A test result.** If it lands near $1,381, confirms the diagnosis.
   If not, deeper investigation needed (possible birth-year issue, possible engine bug).
2. **v1.8.5 candidate:** Quick Entry UI hint when planned claim age ≠ FRA, steering
   users with irregular histories toward Earnings History.
3. **Documentation update:** the PDF guide should probably get a note in Path B (Quick
   Entry) saying it works best for users with a continuous full-time earnings history;
   for gaps or recent earnings changes, use Path A.
