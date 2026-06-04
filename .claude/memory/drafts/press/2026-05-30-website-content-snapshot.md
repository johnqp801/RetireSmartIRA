# Website content snapshot — retiresmartira.com (2026-05-30, post-1.8.5-refresh)

**Captured:** 2026-05-30
**Repo:** `/Users/johnurban/Projects/retiresmartira-website` (Next.js 16, App Router)
**State captured:** AFTER the 1.8.5 refresh edits (commit `25be369`, local, **not yet
pushed/deployed** as of this snapshot — live site still showed 1.8.4 until deploy).

This snapshot exists to (a) preserve the site's information architecture and (b) serve
as authoritative context for the Gemini methodology-brief placement review (see
`2026-05-30-gemini-methodology-placement-prompt.md`).

## Global navigation
**Header (every page):** RetireSmartIRA · Features · What's New · About · Press · Privacy · Support · Download
**Footer (every page):**
- Product: Features, Privacy Policy, Support, Help & FAQ, Contact Us
- Legal: Privacy Policy, About, Terms of Use
- Copyright + one-line planning-tool disclaimer

## Pages (8)
1. **/ (Home)** — Hero ("Reduce lifetime retirement taxes by tens of thousands"; banner now "New in 1.8.5 — refreshed 2026 state tax data across all 50 states"), positioning banner ("Can I retire?" vs "What should I do this year?"), review quotes, screenshot showcase, 8-feature grid, 6-persona grid, founder card, privacy banner, CTA.
2. **/features** — 9 feature sections (Roth conversions, legacy/heir planning, RMDs, full tax bill incl. NIIT/IRMAA/SALT, state tax comparison, SS couples planner, quarterly estimates, CPA PDF export, privacy).
3. **/about** — Founder story (John Urban, ex-co-founder GTNexus/InforNexus), why built, technical highlights, disclaimer.
4. **/press** — Intro + press contact (`john@retiresmartira.com`); Quick Facts (version **1.8.5, released May 29 2026**; platforms; free; company; contact); By-the-numbers (50 states · 2026 IRS limits · 7 tax mechanics · **1,100+ tests**); boilerplate (1-sentence + 1-paragraph); 5 story angles; founder bio + LinkedIn; downloadable assets (press kit zip, app icon, headshot); live showcase link; quotable reviews; press inquiries.
5. **/support** — Contact (`support@retiresmartira.com`) + 8-item FAQ (tax year, advice disclaimer, data storage, MFJ, RMD, platforms, PDF export, IRMAA) + 3-step Getting Started.
6. **/whats-new** — Latest: **Version 1.8.5** ("A state-tax accuracy release…") with 4 cards (50-state TY2026 refresh · verified against official sources · Roth conversion withholding option · 1,100+ tests). Older: Version 1.8.1.
7. **/privacy** — On-device data, no collection, no third-party SDKs (last updated Mar 5 2026).
8. **/terms** — Educational tool / not advice; arbitration (JAMS, Contra Costa CA); limitation of liability; CCPA; already disclaims accuracy of tax tables (v1.0, eff. Mar 24 2026).

## Notable for methodology-brief placement
- **No** "Methodology / Accuracy / Trust / How we verify" page exists, and no footer link to one.
- Closest existing surfaces: /press "By the Numbers" strip; /support FAQ ("What tax year…"); accuracy disclaimer already in /terms.

## Known remaining staleness (NOT fixed in 1.8.5 refresh pass)
- /press contact uses `john@` while /support + footer use `support@` (CLAUDE.md-flagged inconsistency; left as-is per user scope).
- /whats-new jumps 1.8.1 → 1.8.5 (no 1.8.2/1.8.3/1.8.4 entries ever added).
- /privacy "Last updated" Mar 5 2026; still asserts "Never synced to iCloud" — revisit if/when iCloud sync ships (see `roadmap/icloud-sync.md`).

Full raw page-text extraction was generated during the session via a build +
HTML-to-text pass over `.next/server/app/*.html`.
