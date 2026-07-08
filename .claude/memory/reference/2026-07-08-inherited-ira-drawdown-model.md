# Inherited-IRA drawdown model — verified numbers (Bogleheads "Jill/John" case)

Built + verified 2026-07-08 to answer a Bogleheads reply (arcticpineapplecorp) on the inherited-IRA 10-year-rule case study. All anchors cross-checked to the dollar against the app's own engine constants and IRS/CMS sources. Use this as the reference if the thread reopens or the article's worked example is revisited.

## Scenario
MFJ, both 68 in 2026. SS $60k, pension $50k. Inherited traditional IRA $400k (owner died 2025 after RBD → beneficiary RMDs years 1-9, full drain year 10). Own IRA $800k, RMDs at 73. 6% growth both. 2026 law held flat (dollar amounts unindexed) but scheduled changes applied (OBBBA senior deduction sunsets after 2028). No state tax. Single Life factor age 68 = **20.4** (verified against `RMDCalculationEngine.swift:55` and IRS Pub 590-B; NOT 17.7).

## Verified base-year numbers (2026, before inherited withdrawals)
- Provisional income = $50,000 + ½·$60,000 = **$80,000** (> $44k MFJ 2nd threshold)
- Taxable SS = **$36,600** (NOT $0 — arcticpineapplecorp's narration was wrong; his bottom line right)
- AGI = $86,600; standard deduction = **$47,500** ($32,200 base + $3,300 both-65+ + $12,000 OBBBA senior bonus, MAGI < $150k)
- Taxable income = **$39,100** (12% bracket); tax ≈ **$4,196** (matches his ~$4,199)
- +$40k inherited draw → taxable SS jumps to the 85% cap ($51,000, +$14,400), tax +$6,528 = **16.3% blended** (matches his figure exactly)

## SS phase-in decomposition (the marginal-vs-blended point)
Marginal rate IN the phase-in zone = 12% × 1.85 = **22.2%** (each $1 drags $0.85 of SS taxable). Zone exhausts after ~**$17k** of withdrawal (taxable SS hits 85% cap), then clean 12% to ~$47k of withdrawal, then 22%. Blended over the full $40k = 16.3%. (My first draft wrongly said "12% × 1.36 = 16.3% marginal" and "zone exhausts after $40k" — both fixed.)

## 10-year A-vs-B (verified)
| | A: defer, drain yr 10 | B10: level ~$51k × 10 |
|---|---|---|
| Fed tax | $235,870 | $193,179 |
| IRMAA | $12,710 (one tier-4 yr) | $0 |
| Gross inherited $ | $602,968 | $512,709 |
| Effective rate on inherited $ | 25.8% | 19.6% |

Year 10 under A: ~$378k cleanout + $50k own RMD → AGI ~$529k, TI ~$493k (fills 22/24/32%, misses 35%), tier-4 IRMAA ≈ $12,700/couple. Raw tax+IRMAA gap A−B10 ≈ $55k, but A withdraws ~$90k MORE gross (deferral growth). **Fair after-tax-wealth terminal difference (B10 − A), sensitivity to reinvestment drag:** 22% drag → +$23,131; 15% → +$29,404; 0% → +$43,513. **Direction never flips; only size moves.** The aggressive 5-year drain (my original post's advocacy) ranges break-even to +$38k and loses to level-over-10 under every drag → conceded to arcticpineapplecorp's point #4.

## Perplexity review scorecard (given as "consider carefully")
- ✅ RIGHT & important: "marginal 16.3%" was imprecise → it's blended; true marginal in the zone is 22.2%. Adopted.
- ❌ WRONG: claimed Single Life factor 17.7 at 68 (→ $22-24k RMDs, ~$225k total). Actual is 20.4 (verified). Kept my numbers.
- ⚠️ HALF-RIGHT: claimed lower reinvestment drag "would flip" the wealth comparison. Ran it — it does NOT flip; spreading wins by MORE as drag falls. But their instinct to not quote a single fragile figure was sound → disclosed the range instead.
- ❌ REJECTED: their "the model overstates late deductions because senior deduction sunsets" — the model already applies the sunset. Clarified "held flat = dollars unindexed, scheduled law changes applied."

## Model script
Saved at repo scratch during the session; reproduce from this file if needed. Key mechanics: SS worksheet (MFJ $32k/$44k), 2026 MFJ brackets from `tax-2026.json`, OBBBA senior bonus 2025-2028 with $150k phaseout, IRMAA MFJ tiers (tier-4 add = ($649.20−$202.90 partB + $83.30 partD)×12×2 = $12,710), Single Life 20.4−1/yr for beneficiary RMDs, Uniform Table for own RMDs from 73, side-account reinvestment at 6%×(1−drag).

See [[optimizer-objective-not-selectable]] and the 2026-07-08 session note.
