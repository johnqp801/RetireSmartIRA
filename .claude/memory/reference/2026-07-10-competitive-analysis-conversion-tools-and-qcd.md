# Competitive analysis — Roth-conversion tools + QCD modeling (2026-07-09/10)

Research for the V2.1 selectable-conversion-approaches feature. Sources are product help centers, docs, Bogleheads, and Kotlikoff/Kitces primary writing (2024–2026). Confidence flagged; verify before customer-facing copy.

## Selectable objectives / bracket-fill / IRMAA / itemized-in-multi-year

| Tool | Selectable objective? | Bracket-fill w/ picker | IRMAA-tier aware | Side-by-side compare | Itemized in multi-year |
|---|---|---|---|---|---|
| **Boldin** (ex-NewRetirement) | Yes — 4 goals incl. Tax-Bracket Limit + IRMAA-Bracket Limit | Yes (pick the ceiling) | Yes (pick tier) | Yes | Yes, but only in Detailed Budgeter tier |
| **Pralana** (Gold/Online) | Optimizer + user IRMAA/ACA/bracket constraints | Yes | Yes | Yes (A/B/C) | Yes — strongest (time-bounded expense streams) |
| **RightCapital** | Conversion target (bracket/IRMAA) | Yes | Yes | Yes | Yes (advisor-grade; med confidence) |
| **ProjectionLab** | Yes — pick what you optimize for | Yes | Yes | Yes | Yes |
| **MaxiFi** (Kotlikoff) | No — one fixed lifetime objective; refuses bracket-fill | No | Yes (inside global opt) | Baseline vs optimized | Yes (less publicly documented) |
| **Holistiplan** | No optimizer (scenario tool) | Manual, not auto-fill | Yes | Yes | Yes (reads real Schedule A) |
| **Fidelity/Schwab public** | No | No | No | No | No |

**Key sources:** [Boldin Tax-Bracket Limit](https://help.boldin.com/en/articles/12067253), [IRMAA-Bracket Limit](https://help.boldin.com/en/articles/12067360); [RightCapital tax strategies](https://help.rightcapital.com/module-overview/client-portal/tax/tax-strategies); [ProjectionLab Roth](https://projectionlab.com/help/roth-conversion). High confidence: Boldin/Pralana/Holistiplan/ProjectionLab (primary docs). Medium: RightCapital/MaxiFi itemized.

## QCD modeling

| Tool | Models QCD in multi-year | Correct AGI/MAGI reducer (not itemized) | Charitable-as-%-of-RMD input | QCD+conversion strategy surfaced |
|---|---|---|---|---|
| **Boldin** | Yes ([help](https://help.boldin.com/en/articles/8530088)) | Yes ("does not count to AGI… reduces IRMAA, SS taxation") | No | Partly (user combines) |
| **Pralana** | Yes (charitable stream flips to QCD at 70½) | Yes | No | User-driven |
| **RightCapital** | Yes (Gift Goals) | Yes | No | Partly |
| **Holistiplan** | Yes (QCD Explainer, Premium) | Yes ("excluded from taxable income") | No | Partly (separate explainers) |
| **MaxiFi** | Likely/limited | Unverified | No | Implicit |
| **Fidelity/Schwab** | No (education, not calculator) | N/A | No | No |

## Bottom line
- **Selectable bracket/IRMAA goals = table stakes.** Shipping them reaches parity; a single fixed objective sits below every serious competitor.
- **Correct-AGI QCD modeling = table stakes**; omitting it is a gap for the 70½+ charitable segment.
- **"Charitable as % of RMD" = unmet across the surveyed set** (small genuine differentiator).
- **Explicitly surfacing "QCDs open conversion room" = a PRESENTATION differentiator** — NOT a claim that competitors' engines ignore the interaction (unverified; must not appear in copy).
- **Dollar consequence decomposition (vs warning icons) = the main differentiator** (2.1.1).

## Kotlikoff vs Kitces/Bogleheads (framing)
- **Kotlikoff** ([substack, May 2026](https://larrykotlikoff.substack.com/p/federal-bracket-filling-to-roth-convert)): bracket-filling is a "rule of dumb" — ignores SS taxation, IRMAA, state tax; the right approach is global lifetime optimization (which MaxiFi, his product, does). Opinion/marketing from the vendor.
- **Kitces**: endorses systematic partial conversions to fill lower brackets as a practical strategy, *adjusted* for IRMAA cliffs and SS-taxation humps — a reasonable heuristic, not inherently wrong.
- **Bogleheads consensus**: "fill to top of 12/22/24%" is the standard rule of thumb, used as a starting frame then corrected for SS/IRMAA/ACA/LTCG effects.
- **Implication (drove the 2026-07-10 decision):** bracket-fill is defensible as a co-equal selectable approach IF the tool shows its true effective-rate consequences (which our engine can). See decisions/log.md 2026-07-10.
