# Gemini review payload — should the Tax Data Methodology Brief be published on the website, and where?

**Date:** 2026-05-30
**Purpose:** Get an independent strategy opinion (Gemini) on whether/where to
publish the Tax Data Methodology Brief on retiresmartira.com, and whether to
shorten or expand it.
**Brief under review:** `drafts/press/tax-data-methodology.md` (on 1.8.5 branch, committed `6a6e110`)
— the RESTRUCTURED version (durable methodology + separate versioned "Current
release" section). This SUPERSEDES the earlier `2026-05-27-tax-data-methodology-brief.md`
(which I originally quoted before John confirmed the newer restructure is authoritative).
The 20-year/decades-of-planning language was removed in the evolution from the
original `2026-05-27-tax-accuracy-technical-brief.md`.
**Site context provided to Gemini:** the post-1.8.5-refresh site map (see
`2026-05-30-website-content-snapshot.md`), supplied as authoritative because the
refresh wasn't deployed yet at prompt time.

## Questions posed to Gemini
1. Publish publicly at all? (trust/credibility upside vs. nitpicking / liability / competitor-roadmap downside)
2. Where? Press tab / dedicated "Methodology" page / footer "Trust & Accuracy" link / Support / on-request only — top pick + fallback with UX rationale.
3. **Length (key question):** shorter (what to cut) or more verbose (what to add)? Can one doc serve both buyers and press, or split?
4. Framing edits for public vs. on-request version.

## The prompt (verbatim, ready to paste into Gemini)

---

You are advising on website/content strategy for a consumer iOS/macOS app called
**RetireSmartIRA** (retiresmartira.com). It's a retirement-tax-planning tool
(Roth conversions, Social Security timing, withdrawals, RMDs, multi-year tax
projection). Solo founder, John Urban (ex-co-founder of GTNexus/InforNexus).
Native macOS + iOS, free, on-device, no account.

We have written an internal **Tax Data Methodology** document (full text below)
describing how the app sources and verifies its federal + 50-state tax data. I'm
deciding whether to publish it on the public website and, if so, where and in
what form.

**A browsing note:** if you visit retiresmartira.com directly, the live site may
lag what I describe below — treat the CURRENT SITE MAP I provide as authoritative.

Please answer these four questions:

1. **Publish publicly at all?** Weigh the trust/credibility upside against the
   downsides (inviting nitpicking on edge cases, liability exposure, handing
   competitors a roadmap). Net recommendation.
2. **Where?** Options: under the existing Press tab / a new dedicated
   "Methodology" or "Accuracy" page / a footer "Trust & Accuracy" link /
   inside Support / on-request only. Give a top pick + a fallback, with UX
   rationale grounded in the site map.
3. **Length (the key question):** Is this the right length? Should it be
   SHORTER (and if so, what specifically to cut) or MORE verbose (what to add)?
   Can one document serve both prospective buyers AND press/reviewers, or
   should it be split into two versions?
4. **Framing edits** for a public version vs. an on-request version — what
   would you change in tone or content for each.

---

### CURRENT SITE MAP (authoritative — retiresmartira.com, post-1.8.5 refresh)

**Global nav (header, every page):** RetireSmartIRA · Features · What's New ·
About · Press · Privacy · Support · Download
**Footer (every page):**
- Product: Features, Privacy Policy, Support, Help & FAQ, Contact Us
- Legal: Privacy Policy, About, Terms of Use
- Copyright + one-line planning-tool disclaimer

**Pages (8):**
1. **/ (Home)** — Hero ("Reduce lifetime retirement taxes by tens of
   thousands"; banner "New in 1.8.5 — refreshed 2026 state tax data across all
   50 states"), positioning banner ("Can I retire?" vs "What should I do this
   year?"), review quotes, screenshot showcase, 8-feature grid, 6-persona grid,
   founder card, privacy banner, CTA.
2. **/features** — 9 feature sections (Roth conversions, legacy/heir planning,
   RMDs, full tax bill incl. NIIT/IRMAA/SALT, state tax comparison, SS couples
   planner, quarterly estimates, CPA PDF export, privacy).
3. **/about** — Founder story, why built, technical highlights, disclaimer.
4. **/press** — Intro + press contact (john@retiresmartira.com); Quick Facts
   (version 1.8.5, released May 29 2026; platforms; free; company; contact);
   By-the-numbers (50 states · 2026 IRS limits · 7 tax mechanics · 1,100+
   tests); boilerplate (1-sentence + 1-paragraph); 5 story angles; founder bio
   + LinkedIn; downloadable assets (press kit zip, app icon, headshot); live
   showcase link; quotable reviews; press inquiries.
5. **/support** — Contact (support@retiresmartira.com) + 8-item FAQ (tax year,
   advice disclaimer, data storage, MFJ, RMD, platforms, PDF export, IRMAA) +
   3-step Getting Started.
6. **/whats-new** — Latest: Version 1.8.5 ("A state-tax accuracy release…")
   with 4 cards (50-state TY2026 refresh · verified against official sources ·
   Roth conversion withholding option · 1,100+ tests). Older: Version 1.8.1.
7. **/privacy** — On-device data, no collection, no third-party SDKs.
8. **/terms** — Educational tool / not advice; arbitration; limitation of
   liability; CCPA; already disclaims accuracy of tax tables.

**Notable for placement:**
- There is currently **NO** "Methodology / Accuracy / Trust / How we verify"
  page, and no footer link to one.
- Closest existing surfaces: /press "By the Numbers" strip; /support FAQ
  ("What tax year…"); accuracy disclaimer already lives in /terms.

---

### FULL TEXT OF THE DOCUMENT UNDER REVIEW

# RetireSmartIRA — Tax Data Methodology

How RetireSmartIRA sources and verifies the tax parameters it ships.

**Current release:** v1.8.5 (May 27, 2026)
**Last methodology review:** May 27, 2026
**Prepared by:** John Urban, Alamo Ventures Group LLC

---

## At a glance

RetireSmartIRA is a retirement-planning tool, not tax-preparation
software. Its job is to give households a directionally correct,
year-by-year picture of how withdrawals, Roth conversions, and Social
Security timing affect federal and state taxes through retirement —
not to file a return.

The app's tax engine is built on:

1. **Federal tax parameters** based on official IRS guidance for the
   current planning tax year (the annual Revenue Procedure containing
   inflation-adjusted parameters, plus signed legislation effective for
   the planning year).
2. **State tax data** verified against official primary sources (state
   departments of revenue, official forms, enacted legislation, state
   statute pages), with internal audit notes retained for each materially
   changed state.
3. **In-app disclosures** positioning output as estimates for planning
   purposes, explicitly excluding items outside scope (local taxes,
   MFS/HoH filing status, certain phaseouts), and directing users to a
   qualified professional before making financial decisions.

The framing the technical record supports is:

> Updated with current-year federal tax parameters and current state
> tax rules verified against official sources.

See the **Current release** section for the specific sources and state
inventory shipped in the latest release.

---

## 1. Federal tax engine

The federal tax engine is built from official IRS guidance for the
current planning tax year:

- The annual **IRS Revenue Procedure** containing inflation-adjusted
  parameters (standard deduction, brackets, AMT, IRA/401(k) limits,
  etc.)
- **Signed legislation** effective for the planning year, including
  retirement-relevant provisions (e.g., the One Big Beautiful Bill Act
  per-individual senior bonus deduction)
- **26 USC** statutes for items that are not inflation-indexed (NIIT
  threshold, certain statutory floors)

Combining these into a working engine still involves interpretive
modeling decisions wherever federal rules interact — for example, the
ordering of Social Security taxability, NIIT applicability, AMT
calculation, and Roth conversion impact on IRMAA tiers. Those modeling
choices are documented in code and covered by automated tests.

The federal engine is exercised by an automated test suite with more
than 1,100 tests, including end-to-end stress scenarios that combine
high income, multiple income sources, AMT triggers, and NIIT triggers,
with expected values checked against independently reviewed
calculations.

---

## 2. State tax engine

The state engine models 50 states + DC (51 jurisdictions). Each is
encoded as a per-state configuration: tax system (flat, progressive,
none, or special), bracket arrays per filing status, retirement-income
exemption rules, standard deduction, capital gains treatment, and
safe-harbor rules where applicable.

### 2.1 Sources of truth

Policy: every materially changed state bracket is sourced from the
highest-tier primary source available:

1. State department of revenue (e.g., CA FTB, NY DTF, MN DOR)
2. Enacted legislation (signed acts, codified statute)
3. Official forms (withholding formulas, rate schedules)
4. State statute pages

Secondary aggregators (Tax Foundation, RetirementLiving, Kiplinger,
Nolo) are used only as cross-checks, never as the basis for a change.

### 2.2 Verification process

Every state in which a release materially changes bracket data goes
through up to five verification layers, with the minimum bar being
three of five and primary-source verification always mandatory:

1. **Primary-source verification** *(mandatory)* — a state-government
   URL or enacted-statute citation captured in the audit notes.
2. **External calculator reasonableness check, where applicable** —
   bracket math compared against external reference calculators for
   sanity. Used as a cross-check, not as an authoritative source for
   the planning year's state law.
3. **Property-based regression tests** — automated tests asserting
   structural invariants the engine must satisfy (e.g., tax is
   non-decreasing in income, MFJ thresholds are at least equal to
   Single thresholds, an explicit zero-bracket produces zero tax at
   zero income).
4. **Independent review of the diff against the cited primary source** —
   a structured checklist applied independently to each change.
   Automated diff-checking tools may be used as an additional
   error-detection layer in this step. Any disagreement is resolved by
   direct verification against the primary source, never by reviewer
   majority.
5. **User-reported feedback** captured into the change log.

### 2.3 What we treat as material

For state tax purposes, the app applies current-year or best-available
official tax parameters to the active planning scenario. State tax-year
publication timing varies: some states publish final schedules later
than federal parameters, and some are derived from prior-year schedules
through statutory inflation adjustments.

Where a state has not yet published a final schedule for the planning
year, the app uses the most current official state guidance available;
where a state has not changed its rate structure since the prior
verified release, that schedule is retained after re-checking the
state's primary sources. Small inflation-indexing differences between
editions of a state's published schedule are treated as non-material
for planning purposes. **Structural changes, rate changes, new brackets,
missing surtaxes, and changes in retirement-income treatment are
treated as material and prioritized for correction.**

### 2.4 Audit trail

Each state change produces two artifacts retained as internal
verification records in the project repository:

- A **review payload** — the diff sent to the independent-review step,
  with the cited primary-source URL and the bracket-engine semantics
  needed to interpret the code.
- A **review result** — the verbatim reviewer responses and the
  disagreement-resolution notes when applicable.

---

## 3. In-app disclosures

The app explicitly tells users what it is and isn't:

### First-launch terms (clickwrap)
> *"RetireSmartIRA provides educational estimates only. Results are not
> tax, legal, or investment advice. Consult a qualified professional
> before making financial decisions."*

### Guide disclaimer (visible throughout the in-app Guide)
> *"This app provides estimates for planning purposes only. Local and
> city income taxes (e.g., NYC, Yonkers) are not included. Consult with
> a qualified tax professional or financial advisor for personalized
> advice. Tax laws and regulations may change."*

### Output framing
Every dollar value derived from the tax engine is presented with
language consistent with estimation, not filing: "Tax Projection,"
"Estimated quarterly payment," "Projected federal tax."

---

## 4. Known limitations (disclosed)

These items are explicitly out of scope and communicated to users
through the disclaimer text or the in-app Guide:

- **Local and city income taxes.** New York City, Yonkers, MD county
  taxes, OH/PA municipal, IN counties, and similar are not modeled.
- **Filing-status scope.** The current release models Single and
  Married Filing Jointly, the two statuses most relevant to
  RetireSmartIRA's target retirement-planning use cases. Married
  Filing Separately and Head of Household are not separately modeled
  and should not be used as the basis for decisions by users in those
  filing statuses.
- **State-specific surtaxes on capital gains** (e.g., MA 9% short-term,
  MD 2% high-AGI cap-gains surtax) are not separately modeled.
- **State retirement-income phaseouts.** Some states (NJ, RI, MN, etc.)
  have AGI-based phaseouts of pension or Social Security exemptions.
  Some of these exclusions are modeled at the primary exemption level
  rather than with every phaseout step. This may slightly over- or
  understate state tax near phaseout boundaries and is disclosed as a
  planning-tool limitation.
- **Estate, gift, and inheritance taxes** are not modeled. This is a
  retirement-planning tool, not an estate-planning tool.
- **General tax credits.** EITC, child tax credit, and similar credits
  not typically relevant at or near retirement are not modeled.

These limitations reflect a deliberate scope decision: build the best
tool for retirement-decision planning, not a general-purpose tax
calculator.

---

## 5. Update cadence and versioning

State and federal tax data is refreshed at least once per tax year.
Mid-year state rate changes are incorporated through maintenance
releases when material.

Each release ships with internal notes documenting which states were
materially changed and what primary source backs each change. The app
version is bumped on every release that touches tax data so users can
confirm they're on a current build.

---

## 6. Process in practice

Concrete examples of the verification process catching real errors
before release. These are kept as durable illustrations that the
methodology works in practice; not as breaking news from any one
release.

### Missouri TY 2026 threshold catch

During a recent release, the independent review caught a Missouri
threshold error before shipping. One official-looking DOR page
reflected a prior-year return schedule (the schedule used for returns
filed the following April), while the current-year withholding formula
PDF contained the actual current-year thresholds. The first source
*looked* current because it was on the DOR website with a recent
publication date, but it was structurally the prior tax year's data.

The independent-review layer flagged the discrepancy; direct
verification against the withholding formula PDF confirmed the catch;
the code was corrected before shipping.

**The lesson:** changed states are reviewed against specific
primary-source documents (forms, schedules, statutes), not general
tax-summary pages that may reflect a different tax year.

---

## 7. Bottom line

RetireSmartIRA is not tax-preparation software. It is a
retirement-planning tool with a documented tax-data methodology,
primary-source review, automated regression tests, and disclosed scope
limitations. Federal parameters are based on IRS-published guidance for
the current planning year; material state tax changes are reviewed
against official state sources. The app's goal is to help users
evaluate retirement decisions — Roth conversions, withdrawals, Social
Security timing, RMDs, and long-term tax exposure — with current,
source-backed assumptions, while making clear that users should consult
a qualified professional before acting.

---

## 8. Available for review

For press or professional review, state-specific verification notes are
available on request, including:

- The exact bracket data shipped in the latest release
- The primary-source URL(s) used to verify it
- The internal review responses for that state
- The before/after diff vs. the prior release

Contact: support@retiresmartira.com

---

# Current release

This section is updated each release that touches tax data. The
methodology above is durable; the inventory below is versioned.

**Release:** v1.8.5
**Release date:** May 27, 2026
**Planning tax year:** 2026

### Federal sources used in this release

- IRS Revenue Procedure 2025-32 (TY 2026 inflation-adjusted parameters)
- IRS guidance on One Big Beautiful Bill Act (OBBBA) provisions
  effective for 2026

### State inventory

| Category | Count | Meaning |
|---|---|---|
| Materially changed in v1.8.5 and verified against primary sources | 26 | Rate, threshold, structural, or retirement-treatment change applied this release |
| No broad wage / retirement-income tax | 9 | AK, FL, NV, SD, TN, TX, WY + NH (interest/div only, phased out) + WA (capital gains only). No bracket schedule to update. |
| Re-checked in v1.8.5 against current official sources; no code change required | 4 | Verified TY 2026-current; carried forward unchanged |
| Carried forward from prior verified release; no published TY 2026 change identified | 12 | Existing model remained directionally current; no rate-structure change observed in primary sources |
| **Total jurisdictions modeled** | **51** | |

After this verification pass, no known errors in supported state rate
structures exist within scope (Single, MFJ, retirement-planning use).

### In-app disclosure source references (as of v1.8.5)

- First-launch clickwrap: `ClickwrapView.swift:142`
- Guide disclaimer: `GuideView.swift:764`

---

*RetireSmartIRA is an Alamo Ventures Group LLC product.*
*App Store: https://apps.apple.com/app/retiresmartira/*
*Website: https://retiresmartira.com*

---

(End of document. Please answer the four questions above.)

## Multi-model review

The same prompt was sent to three models (Gemini, Perplexity, ChatGPT) for a
multi-LLM cross-check (TriSTAR-style: save the payload AND each result).
Synthesis is held until all three are in.

### Gemini response

_Captured 2026-05-30._

**1. Publish? — YES.** For a premium, privacy-first solo-founder app, trust is
the highest barrier to entry; high-net-worth retirees / self-directed investors
(Bogleheads) distrust black-box calculators. Publishing turns verification into
a competitive advantage.
- *Trust upside (massive):* proves the app isn't scraping Wikipedia / stale
  spreadsheets; John's enterprise background + 1,100+ tests + 5-layer process
  signals "institutional-grade engineering."
- *Competitor roadmap (minimal):* competitors (NewRetirement, Boldin,
  RightCapital) already know where IRS/State-DOR sources are; the moat is
  execution (native on-device, privacy, UX), not the raw data.
- *Nitpicking/liability (manageable):* §4 Known Limitations shields liability
  better than a buried ToS clause by setting explicit boundaries.

**2. Where? — TOP PICK: a dedicated `/accuracy` (or `/methodology`) page +
footer link** titled "Tax Accuracy & Methodology" under the **Product** column.
Don't clutter the 8-item header; footer is the industry-standard trust-doc home
(where users look for Security/Privacy/SOC2). Cross-link from /support FAQ
("How accurate is the state data?") and /press "By the Numbers."
**Fallback:** embed as an expandable accordion / featured article at the top of
/support (best moment to show methodology is when someone is questioning
validity).

**3. Length — split / progressive disclosure.** Doc serves two audiences
(casual buyer wanting peace of mind vs. skeptical journalist/CPA).
- *Cut for public:* the Swift code file refs (`ClickwrapView.swift:142`,
  `GuideView.swift:764`) "look unpolished on a marketing page"; streamline §2.4
  audit-trail jargon ("review payload — the diff sent to…") into a single punchy
  point about mandatory multi-person peer review.
- *Keep full version* (incl. technical grit) as a downloadable PDF
  (`RetireSmartIRA_Tax_Methodology_v1.8.5.pdf`) at the bottom of the public page
  and in the /press kit zip.

**4. Framing edits:**
- *Public:* rename §4 → **"Scope of Modeling: What's Included vs. Out of Scope"**
  (deliberate product scope, not flaws). **Elevate the Missouri catch** into a
  stylized callout/blockquote higher up, titled "Case Study: Why We Don't Rely
  on Secondary Summaries" — reads like a detective story, proves the 5-layer
  process catches what scripts miss.
- *On-request/press:* KEEP the `.swift` file refs here (for technical/Apple
  press, they prove transparency + native craftsmanship). Add an invitation to
  professionals in §8: "If you are a financial professional and find a statutory
  divergence in your state's macro-modeling, contact us at support@…" — turns
  critics into collaborative validators.

_Note: Gemini is the ONLY model that wants to KEEP the Swift file paths (in the
press version) and frames them as a craftsmanship signal; the other three say
cut them entirely. See synthesis._

### Perplexity response

_Captured 2026-05-30. Perplexity browsed the live site (saw 1.8.4 on /press,
1.8.1 on /whats-new — consistent with the not-yet-deployed 1.8.5 refresh) and
gave two passes: an initial review, then an updated review against the
restructured `tax-data-methodology.md`. Both preserved below._

**Live-site audit note:** Live /press shows v1.8.4; /whats-new shows 1.8.1 as
latest. Live footer appeared to omit "Features" (Product) and "Terms of Use"
(Support col) vs. the site map — possibly a browser-agent rendering artifact.
Treated the supplied site map as authoritative.

**1. Publish publicly? — YES, but not the full document as-is.** Upside is
real and asymmetric: target audience (DIY pre-retirees + financial press) is
vetting tools, and /press already makes claims ("1,100+ tests") with nothing to
click. Downsides mostly overblown for this category:
- *Nitpicking:* minimal — the doc is careful; the limitations section is a
  strength, signals discipline.
- *Liability:* already covered by /terms; publishing methodology explains the
  process behind what's already disclaimed. Bigger risk is making accuracy
  claims publicly WITHOUT backing docs.
- *Competitor roadmap:* the one legit concern, but narrow — the workflow isn't
  a moat (any serious player should run it); the real moat is the audit trail +
  test suite + accumulated state work, none transferable by reading a page.

**2. Where? — TOP PICK: a new `/accuracy` page, linked from the footer under
Legal.** Not /press (a press kit; journalists want angles/boilerplate, not a
methodology read; fragments the trust signal). Not /support (troubleshooting
context). Footer-under-Legal (not global nav — nav already 7 items + Download
CTA) matches how serious B2C software handles trust docs (TurboTax "About our
ads," Mint security page). Cross-links to add: /press intro sentence + link
"1,100+ tests" to the page; /support "What tax year…" FAQ → "See full
methodology"; /whats-new v1.8.5 "verified against official sources" card.
**Fallback:** a "Tax Data Accuracy" accordion on /support linked from /press
(less discoverable, no new page infra).

**3. Length — SPLIT INTO TWO TIERS. Do not publish the full doc as the public
page.** One doc cannot serve both audiences.
- *Tier 1 — public `/accuracy` page (~300–500 words):* keep "At a glance"
  (tightened), federal cite + test count, one-sentence state sourcing ("primary
  sources only, never secondary aggregators"), the full Known Limitations list
  (highest-trust section), update cadence, and the Missouri example (most
  compelling proof-of-process — move it UP).
- *Cut from public page → full brief:* §2.2 five-layer table, §2.4 audit-trail
  artifacts, the state-inventory category table, and the source-file citations
  (`ClickwrapView.swift:142` etc.).
- *Tier 2 — full brief (current doc, lightly edited):* on-request + downloadable
  PDF from /press, labeled "Full Methodology Brief (PDF) — for press and
  professional review."

**4. Framing edits:**
- *Public page headline:* "How We Source and Verify Our Tax Data" (matches
  search intent; not "Methodology Brief" [internal] / "Our Commitment to
  Accuracy" [fluff]).
- *Lead with user benefit, not process* — open with why accuracy matters to the
  user, then "Here's how we make sure."
- *Rename "Known Limitations (disclosed)" → "What this app doesn't cover"* —
  the "(disclosed)" reads legally defensive; reframe as user-helpfulness.
  (Perplexity's single biggest-edit pick.)
- *Move Missouri example up* in both versions.
- *Strengthen §5 update cadence* — tie the 26-state pass to the /whats-new
  "state accuracy release" story (deliberate decision, not routine maintenance).
- *Press brief:* retitle to "Tax Data Verification Record — v1.8.5"
  ("verification record" signals a factual paper trail); move §8 "available on
  request" to the TOP; add a one-line "what this document is NOT claiming"
  (e.g., not equivalent to professional tax software / not a substitute for a
  return) to preempt the obvious press gotcha.

**Updated pass against the restructured `tax-data-methodology.md`:** Perplexity
called the restructure "meaningfully better" — durable methodology (§1–8)
cleanly separated from the versioned "Current release" appendix is the right
architecture (methodology doesn't go stale on 1.8.6; only the appendix updates).
Recommendations unchanged in direction. Refinements:
- Footer-link model works *better* now: durable methodology = public page;
  "Current release" appendix = press-on-request tier / PDF.
- The clean 26/4/12/9 state-inventory breakdown could expand the /press "By the
  Numbers" strip (currently just "50 states" with no detail).
- Precise public-page cut list: keep "At a glance" verbatim; §1 minus the last
  two technical paragraphs; §2.1 sources hierarchy; §2.3 condensed to ~2
  sentences; §4 limitations (renamed); §5; §6 Missouri in full; §7; §8 as CTA
  ("Want the full detail?"). Cut §2.2, §2.4, and the entire "Current release"
  appendix (link to it instead). Result ≈ 450–500 words.
- On the public page, replace the inventory table with one sentence + link:
  "In v1.8.5, 26 states were materially updated, all verified against primary
  sources. [See the full v1.8.5 verification notes →]"
- *Press-version clarity fix for §2.2:* "minimum bar three of five" invites
  "which three?" — clarify that primary-source verification is ALWAYS mandatory
  and the other four are layered cross-checks, or reword to:
  "Primary-source verification is mandatory for every change. Additional
  cross-checks — external calculators, regression tests, independent diff
  review, user feedback — provide layered error detection on top of that."
- *Do-now regardless of publish decision:* update the /press "By the Numbers"
  strip to v1.8.5 (live still shows 950+ tests) and consider a "26 states
  re-verified this release" row — a zero-new-page win. (Note: our local website
  refresh already bumped this to 1,100+/1.8.5; not yet deployed.)

### ChatGPT response

_Captured 2026-05-30._

**1. Publish publicly? — YES, but not the full doc as the primary public page.**
Trust upside is real for the right audience (financial planners evaluating a
recommendation; retirement bloggers — Karsten/ERN, Mamula, Fritz; App Store
reviewers/journalists; users deciding whether "free" = "casual" or "serious").
Downsides: a long technical doc invites edge-case nitpicking (HoH, MD county,
MFS, NYC) and hands competitors a partial roadmap — though the methodology
isn't the core IP (execution + UX are). **Biggest risk is overclaiming**, not
competitors: the doc must read as disciplined planning methodology, not a
tax-prep warranty. So: publish a controlled public version; keep the full
audit-trail/state-source notes for press/professional review.

**2. Where? — TOP PICK: a new footer link "Trust & Methodology" → `/methodology`**
(page title "Tax Data Methodology"). Footer, NOT main header (header is already
selling; adding "Methodology" could overwhelm casual buyers). Footer is
discoverable to serious users without distracting consumers. Suggested footer
restructure adds a **Trust** column: `Product: Features, What's New, Support,
Download` · `Trust: Privacy, Tax Data Methodology, Help & FAQ` · `Legal: Terms,
Privacy Policy, About`. **Fallback:** a short "Tax Data Methodology" card on
/press linking to the full page (fits the existing "By the Numbers" strip).
**Also add a /support FAQ:** "How accurate are the tax calculations?" →
planning tool not tax-prep; federal from IRS guidance, material state changes
verified vs. official sources; local/MFS/HoH/phaseouts out of scope →
[Read Tax Data Methodology].

**3. Length — too long for buyers, about right for reviewers. Split into two
layers.** One doc cannot serve both.
- *Public website version: 700–1,000 words.* Answer: what sources, how verified,
  what "updated" means, what's NOT modeled, how often refreshed. No full
  mechanics / artifact descriptions / state inventory table (unless collapsed).
- *On-request technical brief: current full version* as downloadable PDF / send
  on request — keep state inventory, verification layers, Missouri example,
  release detail, test count, source hierarchy.
- *Cut from public page:* "up to five verification layers" detail; "review
  payload / review result" artifact language; full state inventory table; the
  Missouri story (or shrink to a sidebar); repeated source-category lists;
  "internal review responses."
- *ADD to public page a plain-English "What this means for you" section* —
  currently missing: compare retirement-tax decisions before acting; estimates
  federal+state from current official sources; useful for Roth sizing, RMD
  planning, SS timing, state-tax comparison; not a substitute for a CPA/advisor.

**4. Framing edits:**
- *Public tone:* calm, plain-English, confidence-building. Use "source-backed,
  official sources, planning estimates, current federal parameters, material
  state changes, known limitations." AVOID "minimum bar being three of five,"
  "review payload," "verbatim reviewer responses," "project repository,"
  "internal audit artifacts," **and "no known errors."**
- *"No known errors" is legally + rhetorically fragile.* Replace with:
  "After the v1.8.5 verification pass, we are not aware of any materially wrong
  state rate structure within the app's supported filing-status scope and
  retirement-planning use case."
- *Downplay LLM review prominence* — public/professional reviewers may not read
  "LLM-assisted review" as a quality mark. Phrase as "structured independent
  review and automated diff-checking tools"; explain LLMs as one error-detection
  tool, never the authority, only if asked.
- *On-request version* can be more technical (layers, Missouri, inventory) but
  must keep repeating the frame "retirement-planning projections, not
  filing-grade tax preparation" and avoid sounding like it certifies tax
  correctness.
- *Recommended public headline:* "Updated with current-year federal tax
  parameters and current state tax rules verified against official sources."
- *Provided a full ~8-section public-page skeleton:* intro ("planning tool, not
  tax-prep") → How tax data is sourced → How changes are verified → What
  "updated" means → What is not modeled → Why this matters → Current release
  (v1.8.5: 26 jurisdictions materially changed/verified) → Professional review
  (source notes on request).

**Do-now (matches Perplexity):** update /press "By the Numbers" to v1.8.5 /
1,100+ tests. (Already done locally in the website refresh; not yet deployed.)

### Claude Chat response

_Captured 2026-05-30._

**1. Publish? — YES, a trimmed version.** Retirement-tax tools live or die on
whether people believe the numbers; a documented primary-source methodology is
a credibility asset few solo-dev apps can show, and it de-risks a
Christine-Benz/Morningstar-type reviewer pitch. Downsides are mostly
self-inflicted if you publish the internal doc verbatim. The genuine cost is the
**competitive roadmap** (the five-layer process, the material/non-material
logic, the Missouri example are a copyable recipe) — which argues for *what to
cut*, not *whether to publish*.

**2. Where? — TOP PICK: a dedicated `/accuracy` page**, linked from the footer's
**Product** column, cross-linked from /press "By the Numbers" and the /support
FAQ advice-disclaimer item. The three places accuracy questions surface today
(home "verified against official sources" banner, /press By-the-Numbers,
/support FAQ) all currently **dead-end** — a standalone page gives each a
destination. **Name it "Accuracy," not "Methodology"** — buyers search "is it
accurate," not "what's your methodology." Footer, not global nav.
**Fallback:** fold into /press as a "How we verify our data" section (weaker —
buyers don't visit Press — but zero new infra).

**3. Length — too long for public; split into two.** Current doc is right-sized
as the internal/on-request artifact but ~2–3x too long for a public page and
pitched at the wrong reader (buyers want reassurance in 60 seconds; press want
the audit trail).
- *Cut for public:* the five-layer breakdown (collapse to one sentence —
  "primary-source verification plus automated regression testing and independent
  diff review"); §2.3 material/non-material logic; §2.4 audit-trail artifacts;
  the Missouri example (keep for press — best proof but also clearest competitor
  tell); the code file paths (`ClickwrapView.swift:142` "should never be
  public"); the state-inventory table (replace with headline numbers: 50 states,
  verified against official sources, 1,100+ tests).
- *Keep public:* "planning tool, not tax-prep" framing; federal-from-IRS /
  state-from-primary-sources in plain language; the disclosed limitations list
  (trust-builder + nitpick-preempter); update cadence; "consult a professional"
  close.
- *Add public:* almost nothing — maybe one line tying it to the home banner
  ("This is what 'verified against official sources' means").

**4. Framing edits:**
- *Public:* second person, reassurance register ("Here's how we make sure the
  numbers you see are current and source-backed"); lead with the conclusion,
  then briefly how; drop internal vocab ("review payload," "property-based
  regression tests," "audit notes," file paths); frame limitations as deliberate
  scope choices.
- *On-request/press:* keep as-is, but three fixes — (a) **remove or get
  permission before naming any user** in the change log; (b) **keep
  "Claude-wrote-everything"-type origin framing out**; (c) **confirm every
  operational claim is actually live** (TAXSIM-style oracle, multi-source
  review, primary-source citations) before handing to a reviewer who may verify.

**⚠️ Fact-check flag (unique to Claude Chat):** Double-check the federal source
citation **"IRS Revenue Procedure 2025-32"** for TY2026 against the actual IRS
release — "a wrong citation on an accuracy page is the one error a reviewer will
catch immediately." *(Action item — verify before publishing either version.)*

### Cross-model synthesis

_Written 2026-05-30 from all FOUR models: Gemini, Perplexity, ChatGPT, and
Claude Chat. (Gemini's substantive answer arrived later, after an initial
prompt-echo paste.) This is a full 4-of-4 synthesis._

**UNANIMOUS across all four models — treat as decided unless John overrides:**

1. **Publish — YES, a condensed/trimmed public version, not the full doc.**
   4/4. Trust is the decisive barrier for a privacy-first solo-founder
   retirement-tax app; the methodology is a credibility asset competitors can't
   easily fake. Every model says the competitive-roadmap risk argues for *what
   to cut*, not *whether to publish*.

2. **Placement — a NEW dedicated page, FOOTER-linked, NOT global nav.** 4/4.
   Three of four name **`/accuracy`** (Perplexity, Claude Chat, Gemini's primary;
   ChatGPT preferred `/methodology`). Footer column: Product (ChatGPT/Claude
   Chat/Gemini) vs. Legal/Trust (Perplexity) — minor. The 8-item header stays
   untouched.

3. **Cross-link from /press "By the Numbers" + a /support FAQ.** 4/4.
   (Perplexity/ChatGPT also add the /whats-new 1.8.5 "verified" card.) Claude
   Chat's sharpest point: the home "verified against official sources" banner,
   /press By-the-Numbers, and /support FAQ all currently **dead-end** — the new
   page gives each a destination.

4. **SPLIT INTO TWO TIERS. One doc cannot serve both audiences.** 4/4 and
   emphatic. Short public page + full brief on-request / as a downloadable PDF
   from /press (Gemini even named the file:
   `RetireSmartIRA_Tax_Methodology_v1.8.5.pdf`).

5. **Same public-page cut list.** 4/4 agree on: the §2.2 five-layer table
   (collapse to one sentence), the §2.4 audit-trail "review payload/result"
   jargon, and the state-inventory table (replace with headline numbers). 3/4
   (Perplexity, ChatGPT, Claude Chat) say **cut the Swift file paths entirely**;
   Gemini is the lone dissent (see divergence below).

6. **Lead with USER BENEFIT / reassurance, second person, plain English.** 4/4.
   Perplexity's opener ≈ ChatGPT's "What this means for you" ≈ Claude Chat's
   "Here's how we make sure the numbers you see are current" ≈ Gemini's
   buyer-framing. Drop internal vocab ("review payload," "property-based
   regression tests," "audit notes").

7. **Reframe §4 "Known Limitations (disclosed)."** 4/4 want it reframed as
   deliberate scope, not flaws/defensiveness. Names offered: "What this app
   doesn't cover" (Perplexity), "Scope of Modeling: What's Included vs. Out of
   Scope" (Gemini), "deliberate scope choices" (ChatGPT/Claude Chat).

8. **Do-now regardless:** bump /press "By the Numbers" to v1.8.5 / 1,100+ tests.
   Flagged by 3/4; **already done locally (commit `25be369`), pending a deploy
   John authorizes.**

**DIVERGENCES (judgment calls for John):**

- **Swift file paths (`ClickwrapView.swift:142`) — 3-vs-1.** Cut everywhere
  (Perplexity/ChatGPT/Claude Chat; Claude Chat: "should never be public"). Gemini
  alone says KEEP them in the *press/on-request* version as a craftsmanship /
  transparency signal for Apple-centric technical press. *Resolution:* cut from
  public page (unanimous); Gemini's keep-for-press is a defensible option but
  the majority view is they read as unpolished — lean toward cutting, or keep
  only if a specific technical reviewer asks.
- **The Missouri example placement — split.** Gemini: ELEVATE it into a
  stylized "Case Study" callout high on the public page (best proof). Perplexity:
  keep but move up. ChatGPT/Claude Chat: CUT from public (it's the clearest
  competitor tell), keep for press. *Resolution:* this is the real strategic
  fork — "best trust proof" vs. "clearest competitor recipe." My lean: keep a
  *short, de-tooled* version of the Missouri story public (the lesson, not the
  workflow), full version for press.
- **Public-page length:** ~300–500 (Perplexity) / 500–1,000 (ChatGPT) / "~⅓ of
  current, 60-second read" (Claude Chat) / scannable (Gemini). *Resolution:*
  ~500–700 words.
- **Slug + footer column:** `/accuracy` (3) vs `/methodology` (1); Product col
  (3) vs Legal/Trust (1). *Resolution:* `/accuracy`, Product column.

**HIGH-VALUE EDITS raised by one model, worth adopting:**

- **(ChatGPT) Kill "no known errors."** Legally/rhetorically fragile → hedge:
  "After the v1.8.5 verification pass, we are not aware of any materially wrong
  state rate structure within the app's supported filing-status scope and
  retirement-planning use case." **Single most important framing fix; aligns
  with CLAUDE.md "never overclaim."**
- **(ChatGPT) Downplay the LLM-review layer** publicly → "structured independent
  review and automated diff-checking tools"; LLM-as-one-tool only if asked.
- **(Claude Chat) ⚠️ FACT-CHECK "IRS Revenue Procedure 2025-32"** against the
  actual IRS release before publishing either version — a wrong citation on an
  accuracy page is the one error a reviewer catches instantly. **Action item.**
- **(Claude Chat) Pre-publish hygiene on the press version:** (a) get permission
  / anonymize before naming any user in the change log; (b) keep
  "Claude-wrote-everything" origin framing out; (c) confirm every operational
  claim (TAXSIM-style oracle, multi-source review, primary-source citations) is
  actually live before handing to a verifying reviewer.
- **(Perplexity) On-request brief:** retitle toward "Verification Record," move
  "available on request" to the top, add an explicit "what this document is NOT
  claiming" line (not equivalent to pro tax software / not a substitute for a
  return).
- **(Gemini) Press §8 invitation to professionals:** "If you are a financial
  professional and find a statutory divergence… contact support@…" — turns
  critics into collaborative validators.

**RECOMMENDED PATH (for John's sign-off):**
1. Keep `tax-data-methodology.md` as the **on-request / PDF press brief**
   (already well-structured: durable body + versioned appendix). Apply: the
   "no known errors" hedge, the "what this is NOT claiming" line, the
   professional-invitation, and Claude Chat's pre-publish hygiene checks.
2. Write a **new ~500–700-word public `/accuracy` page**, footer-linked
   (Product column), leading with user benefit, §4 reframed as scope, a short
   de-tooled Missouri callout, ending in a "full methodology on request / PDF"
   CTA. Cross-link from /press, /support FAQ, /whats-new.
3. **Verify the IRS Rev. Proc. 2025-32 citation** before publishing anything.
4. Deploy the already-staged 1.8.5 site refresh (separate authorization).

## Decision / outcome

**Decided 2026-05-30 by John, after the 4-model review (Gemini, Perplexity,
ChatGPT, Claude Chat):**

1. **Publish — YES.** A short public page + full on-request/PDF press brief
   (two-tier, per unanimous model consensus).
2. **Placement:** new **`/accuracy`** page, footer-linked under the **Product**
   column. Cross-link from /press "By the Numbers" + a new /support FAQ.
3. **Public-page length:** ~500–700 words (settled default, not a contested
   call).
4. **Missouri example → REVERSED 2026-05-30.** Initially decided to follow
   Gemini (elevate as a public "Case Study" callout), but John changed his mind
   and chose to **OMIT the Missouri example from the public page** (aligns with
   the ChatGPT/Claude-Chat "it's the clearest competitor tell" view). The
   underlying *principle* — "we verify against primary-source documents, not
   general summary pages that may reflect a different tax year" — is kept,
   folded into the verification paragraph without the named case study. Full
   Missouri example stays in the on-request press brief.
5. **Swift file paths → follow GEMINI:** CUT from the public `/accuracy` page;
   KEEP them in the on-request/press version as a craftsmanship / transparency
   signal for Apple-centric technical press.
6. **"No known errors" → follow CHATGPT:** replace with the hedge — "After the
   v1.8.5 verification pass, we are not aware of any materially wrong state rate
   structure within the app's supported filing-status scope and
   retirement-planning use case." (Aligns with CLAUDE.md "never overclaim.")
   Apply to BOTH versions.
7. **IRS citation fact-check → RESOLVED.** "IRS Revenue Procedure 2025-32" is
   CORRECT for TY2026 inflation adjustments (incl. OBBBA amendments), verified
   2026-05-30 against the IRS newsroom + primary PDF
   (irs.gov/pub/irs-drop/rp-25-32.pdf). No change needed.

**Still open / next steps:**
- Draft the ~500–700-word public `/accuracy` page (apply decisions 4–6).
- Apply the "no known errors" hedge to `tax-data-methodology.md` (press
  version).
- Build the page on the website (new route + footer link + cross-links).
- Deploy the already-staged 1.8.5 site refresh (commit `25be369`) — separate
  authorization.
- (Not yet decided) Perplexity's "Verification Record" retitle + "what this is
  NOT claiming" line; Gemini's §8 professional-invitation; Claude Chat's
  press-version hygiene (anonymize change-log users, keep origin framing out,
  confirm operational claims live).
