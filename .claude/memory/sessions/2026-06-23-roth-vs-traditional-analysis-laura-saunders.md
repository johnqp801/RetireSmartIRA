# Session Summary — Roth vs. Traditional 401(k) Analysis + Laura Saunders Outreach

**Date:** 2026-06-23
**Source:** Claude Chat session (not Claude Code). Imported into project memory 2026-06-23.
**Focus:** Built and refined a rigorous Roth-vs-Traditional 401(k) analysis through 5 versions plus a one-page summary; replied to WSJ tax reporter Laura Saunders.

> NOTE: the deliverable `.docx` files and build scripts below live in the Claude Chat session container, NOT on this machine. Re-download from that chat if needed. This file is the durable record of the decisions and numbers.

---

## Outcomes

### Laura Saunders (WSJ) — touch 2 of 3 sent
- Replied to her substantive email under the **original subject** ("Re: A related angle on inherited IRAs"), sent from **john@retiresmartira.com**.
- Strategy: conceded her "conventional wisdom" pushback gracefully, sharpened what is genuinely new (the four hidden traps), answered her Roth 401(k) question directly including the "more dollars in" point, and **offered the one-pager without attaching it** (let her pull).
- One touch remaining under the three-touch rule if she goes quiet.
- Did NOT attach the document; full v5 doc is backup if she asks to verify.

### Deliverables (both final, zero em-dashes, validated)
- **roth-vs-traditional-v5.docx** — full ~12-page analysis, source of truth.
- **roth-vs-traditional-onepager.docx** — single-page summary, the attachment for Laura when she asks.

---

## The analysis — key modeling decisions (all verified vs 2026 IRS/CMS figures)

- **Fair comparison:** identical contribution dollars both strategies. Case 1 = max Roth 401(k). Case 2 = traditional 401(k) + invest the tax savings in a brokerage (7.5% net = 8% minus 0.5% drag, 15% LTCG).
- **2026 limits:** base $24,500; catch-up $8,000 (50-59); super catch-up $11,250 (60-63). Totals $32,500/yr (55-59), $35,750/yr (60-61). 7-yr total $233,000.
- **High earners** (prior-year FICA wages from sponsoring employer >$150k): catch-up MUST be Roth per SECURE 2.0. Only $24,500 base is traditional.
- **2026 MFJ 32% bracket:** $403,550–$512,450. Standard deduction $32,200.
- **Two profiles:** High $468,420 gross / $436,220 taxable (30% into 32%); Moderate $225,000 gross / $192,800 taxable (22%).
- **RMD divisor at 75 = 24.6** (IRS Uniform Lifetime Table).
- Contributions assumed beginning-of-year (stated explicitly).

## Three-scenario structure (driven by existing balance at 55)
- **Scenario A** ($500k start → 22% at 75): traditional wins on bracket math throughout.
- **Scenario B** ($1M start → 24% at 75) **PRIMARY/common case**: traditional leads by only $4,084 at 75, Roth overtakes by 80 (+$2,694), +$35,911 by 90. The hidden traps erase/reverse the thin traditional edge.
- **Scenario C** ($2M start → 32% at 75): Roth wins outright from 75 (+$36k-47k at 75, +$167k-199k by 90).
- Honesty point: needs ~$2M existing balance to actually reach 32% — the RMD bridge proves the 32% assumption isn't automatic.

## The four hidden traps (analytical core, all favor Roth)
1. **IRMAA** (Medicare surcharges). 2026 MFJ couple costs (Part B+D, both spouses): Tier 1 $2,297, Tier 2 $5,770, Tier 3 $9,240, Tier 4 $12,710, Tier 5 $13,872.
2. **Widow tax.** Survivor files single on same income. Scenario B: couple MAGI $265,701 = Tier 1; widow MAGI $245,301 = **Tier 4** (single), costing $6,355/yr vs couple's $2,297 = extra **$4,058/yr** from filing-status change alone.
3. **State tax trap.** California taxes traditional withdrawals up to 13.3%, no break for retirement income, no preferential LTCG. Roth exempt. CA adds ~$71k to Roth advantage at 75 ($118,673 vs $47,284 federal-only). NY/NJ/OR/MN similar.
4. **SECURE Act 10-year rule.** Heirs pay ordinary income on inherited traditional within 10 years, no step-up. Roth tax-free. $2M balance = $480k haircut at 24% heir rate.

## NIIT note (now traceable in v5)
At 23.8% LTCG (20% + 3.8% NIIT) instead of 15%, even federal bracket math flips: Roth leads by ~$6,963 at 75 in Scenario B (moderate) rather than trailing. NIIT shifts every sensitivity cell ~$11,000 toward Roth. Added as a dedicated row in the v5 brokerage sensitivity table so the one-pager figure traces.

---

## CRITICAL CORRECTION made this session
- **Widow IRMAA tier was WRONG in earlier drafts.** Originally stated $245,301 MAGI = Tier 3. Verified against CMS 2026: $245,301 exceeds $205,000, so it is **Tier 4** (single). Corrected surcharge to **$6,355/yr** (was $7,800), additional widowhood cost to **$4,058/yr** (was $5,856). Couple Tier 1 corrected to **$2,297** full B+D (was $1,944 Part B only). Full IRMAA schedule table updated to B+D couple costs. Propagated through entire v5 doc and into one-pager.

---

## Document evolution (each version driven by external AI critique)
- **v1→v2:** fixed contribution-mismatch flaw (was $8k Roth vs $31k 401k), added equal-dollar comparison.
- **v2→v3:** corrected bracket numbers, labeled beginning-of-year contributions, extended tables to 90, added RMD bridge + "no withdrawals 62-75" caveat, IRMAA/widow/inheritance sections, whole-household inheritance table, CA mini-section, fixed catch-up FICA wording, "SECURE Act 10-year rule" not "SECURE 2.0".
- **v3→v4:** added executive summary BLUF (four-traps hook), three-scenario structure, hidden-trap tally, renamed CA → "state tax trap" (national), added 24% primary scenario. Then fixed table layout: 10-col tables didn't fit portrait → reduced to compact delta-only tables; removed redundant Direction column; removed unhelpful gross-value reference tables.
- **v4→v5:** tightened prose (4000→3643 words), removed ALL em-dashes (verified 0), fixed garbled "today's tax deduction is worth giving up" sentence, applied all IRMAA corrections, added NIIT sensitivity row.
- **One-pager:** built per Perplexity's strongest structural suggestion. Core finding box, four traps with one-line quantifications, "contributions are not equal" box (answers Laura's Q, now quantified $32,500/$22,100/$10,400), year-by-year mini-table (added Age 62), NIIT flip note, "who this matters for" 5-item checklist, CA figure anchored with math, softened disclaimer. Fits exactly one page (verified via PDF).

---

## Standing rules reinforced (see also user auto-memory)
- All RetireSmartIRA outreach sends from **john@retiresmartira.com** (the Andy Panko pitch accidentally went from gmail on 2026-06-12 — flag before every send).
- Three-touch maximum on all outreach.
- Writing rules: no em-dashes, no blocklisted vocab (delve, leverage, robust, navigate, underscore, etc.), varied sentence rhythm, no rule-of-three bundling.

## Open / next steps
1. Await Laura's reply. If interested → send one-pager; full v5 doc as backup. One touch left if quiet.
2. **Inherited IRA article — RESOLVED (no action).** The Claude Chat summary listed it as "still ready to publish (Jake Schmitt cleared)," but that was a stale belief: John confirmed 2026-06-23 that **Claude Chat simply did not know the article was already live.** The Inherited IRA 10-Year Rule article shipped LIVE to retiresmartira.com on 2026-06-09 (`/articles/inherited-ira-10-year-rule-2026`, PRs #1+#2 merged, GSC-indexed). There is NO new/second inherited-IRA article to build. (Separately still open from the 06-20 session: a small worked-example redline on that live article — gross-vs-taxable relabel + senior-deduction nuance — offered but not yet applied.)
3. Possible future: Roth conversion angle (62-74 window) — deliberately omitted from one-pager to avoid an unmodeled second analysis; raise in conversation with Laura if she engages.

## File locations (Claude Chat session container — re-download if needed)
- roth-vs-traditional-v5.docx, roth-vs-traditional-onepager.docx
- Build scripts: build-roth-v5.js, build-onepager.js
