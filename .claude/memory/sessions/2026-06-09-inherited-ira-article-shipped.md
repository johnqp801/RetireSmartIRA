# Session: 2026-06-09 — Inherited IRA 10-Year Rule article fact-checked, built, shipped

**Repos:** retiresmartira-website (build + deploy); fact-check work is cross-project.
**Status:** Article LIVE on main. PR #1 + PR #2 both merged. GSC indexing submission pending (user doing manually).

---

## TL;DR

Took a user-supplied article draft (Inherited IRA 10-Year Rule), fact-checked the tax content across two rounds, then built it as the **second** article on retiresmartira.com (`/articles/inherited-ira-10-year-rule-2026`). Added PDF/print polish. Shipped via two PRs (both merged). Article is the IRMAA article's companion.

---

## 1. Tax fact-check (two rounds, deep web research)

Audited against IRS final regs (July 2024), Notice 2024-35, IRC §4974(e), §1411(c)(5), and 2026 inflation figures. Findings that shaped the final article:

- **First enforced year is 2025, NOT 2026.** Notice 2024-35 was the *final* penalty waiver (covered 2024 only). Final regs apply to calendar years beginning on/after Jan 1 2025. First hard annual-RMD deadline was Dec 31, 2025. The user's earlier HTML draft wrongly framed "2025 transitional / 2026 first enforced" — corrected in 5 locations before build. This was the most consequential error (a 2026 reader could think they had no 2025 obligation when they may have already missed one).
- **NIIT:** IRA distributions are excluded from net investment income (§1411(c)(5)). Distribution itself NOT subject to 3.8% NIIT, but raises MAGI which can pull *other* investment income over the threshold. Worked-example result cell fixed to "Top brackets + IRMAA spike" (NIIT removed).
- **2026 QCD limit = $111,000** per person (NOT $108,000 — that was the 2025 figure). Matches the IRMAA article. The draft had $108,000; corrected before build.
- **Minor-child nuance:** a formerly-minor child must take annual RMDs during the 21→31 window regardless of whether the parent died before/on/after RBD (ALAR rule — life-expectancy payments already began). Verified, included.
- **Ghost life expectancy rule** added for non-designated beneficiaries when owner died on/after RBD (5-year rule only applies if owner died before RBD).
- **25%/10% penalty**, correction window = end of 2nd taxable year after the missed year. Form 5329.
- **RBD:** April 1 after applicable RMD age — 73 for many, rising to 75 for those born 1960+. Correct.
- Worked example ($400K inherited, $150K other income) is deliberately directional ("~"/"+"), not precise. Consistent with author intent.

## 2. Build (website repo)

New TSX page using the existing article component system (same pattern as IRMAA). Files:
- **New:** `src/app/articles/inherited-ira-10-year-rule-2026/page.tsx` — Article + FAQPage JSON-LD, local `BeneficiaryTable`, two `WorkedExample` boxes (spike vs spread).
- **Modified (backward-compatible):**
  - `ArticleCTA.tsx` — optional `eyebrow`/`heading`/`body` props; defaults preserve IRMAA copy.
  - `Callout.tsx` — optional `variant` (default/warning/danger); default stays teal.
  - `ArticleLayout.tsx` — added **print-only branded header** (app icon + RetireSmartIRA wordmark + retiresmartira.com), `hidden print:block`, `next/image priority` so logo preloads. Applies to ALL articles.
  - `articles/page.tsx` — added to ARTICLES index (newest first).
  - `sitemap.ts` — added the URL.

## 3. PDF/print issue + fix

User reported Save-as-PDF "doesn't look like the online version, no logo, no download box." Root cause = print stylesheet working as designed:
- Site `<Header>`/`<Footer>` are `print:hidden` → no logo/nav in PDF.
- Hero gradient flattened to white, link colors removed (`globals.css @media print`).
- `ArticleCTA` is `print:hidden` → download CTA vanishes in PDF. IRMAA article has a *second* non-hidden gray box specifically so a download prompt survives; new article lacked it.

Fixes shipped:
- Added the gray (non-print:hidden) **download box** to the new article.
- Added the **print-only branded header** to shared ArticleLayout (benefits both articles).

## 4. Ship sequence (lesson learned)

- PR #1 (`article/inherited-ira-10-year-rule`) — article + memory. User merged via web UI.
- **Gotcha:** I pushed 2 more commits (print box + branded header) AFTER the user merged PR #1. A merged PR can't absorb later commits → those 2 were stranded on the branch and the branch "looked un-mergeable."
- Fix: opened **PR #2** from the same branch for the 2 stranded commits. Merged via `gh pr merge 2 --merge --delete-branch`.
- **Lesson:** Don't keep pushing follow-up commits to a branch whose PR the user is actively merging. Either batch all changes before they merge, or expect a second PR.
- Note: user settings **deny `git push origin main`** — website articles ship via feature branch + PR merge, not direct push. (Vercel auto-deploys on merge.)

## 5. Open / next

| Item | When | Notes |
|---|---|---|
| GSC: Request indexing for new URL | ✅ Done Jun 9 | Submitted via URL inspection: `/articles/inherited-ira-10-year-rule-2026` (+ `/articles` index). Now in Google's crawl queue. |
| Verify PDF on live page | After Vercel deploy | Confirm letterhead + download box render |
| GSC index coverage check | Wed/Thu Jun 10–11 | New article + IRMAA + original 7 pages |
| Article #3 / ConvertKit email capture | Future | ConvertKit slated for article 3 |
| Advisor market research (Bryan Jepson signal) | Future | From 2026-06-08 session |

## Reference
- Companion website-repo session note: `retiresmartira-website/.claude/memory/sessions/2026-06-09-inherited-ira-article-build.md`
- Prior session: `2026-06-08-articles-launch-bryan-jepson-advisor-market.md`
