# 2026-05-30 — Accuracy & Tax Data page publish + GA4 tracking

## Summary

Published a public **Accuracy & Tax Data** page (`/accuracy`) on
retiresmartira.com that explains how the app sources and verifies its
federal and 50-state tax data, links the full Tax Data Methodology PDF,
and added GA4 tracking for the page and the PDF download. Committed and
deployed live.

## Decisions made (this session + carried from prior)

- **Publish strategy** (4-model synthesis — Gemini, Perplexity, ChatGPT,
  Claude Chat, all unanimous): condensed public page + full methodology
  available as a PDF; dedicated footer-linked page (not global nav);
  cross-link from /press + /support FAQ; lead with user benefit; reframe
  "limitations" as deliberate **scope** choices.
- **Slug:** `/accuracy`. **Footer:** Product column.
- **Length:** ~520 words (target was 500–700).
- **Missouri example:** REVERSED. Initially decided to elevate it as a
  case-study callout (per Gemini); John then said "leave out the Missouri
  example." Kept only the underlying principle folded into "How changes
  are verified" (verify against specific primary-source documents — forms,
  schedules, statutes — not general tax-summary pages).
- **"No known errors" framing:** followed ChatGPT — softened to a hedge:
  "After our latest verification pass (v1.8.5), we are not aware of any
  materially wrong state rate structure within the app's supported filing
  statuses and retirement-planning use."
- **IRS Rev. Proc. 2025-32** citation web-verified CORRECT for TY2026
  (incl. OBBBA amendments) via IRS newsroom + rp-25-32.pdf. No change.
- **CTA:** links the methodology PDF directly (was a mailto).

## What shipped (website repo: ~/Projects/retiresmartira-website)

Commit `55a2968` "site: add Accuracy & Tax Data page with methodology PDF
+ GA4 tracking" — pushed to origin/main (`d60cb39..55a2968`), auto-deploys
via Vercel. NOTE: this push also carried the prior staged commit
`25be369` (1.8.5 site refresh) live.

New files:
- `src/app/accuracy/page.tsx` — the public page (Server Component).
- `src/components/accuracy/MethodologyDownloadLink.tsx` — client comp,
  fires `methodology_pdf_download {source:"accuracy_page"}` on CTA click.
- `src/components/analytics/PageViewTracker.tsx` — client comp, fires GA4
  `page_view` on SPA navigations (skips first render to avoid
  double-counting the initial gtag config page_view); mounted in
  layout.tsx inside `<Suspense>`.
- `public/press/RetireSmartIRA_Tax_Methodology_v1.8.5.pdf` (16,179 bytes).

Modified:
- `src/lib/analytics.ts` — added `trackPageView(path)` and
  `trackMethodologyDownload(source: "accuracy_page" | "press")`.
- `src/app/layout.tsx` — Suspense-wrapped `<PageViewTracker />`.
- `src/app/press/page.tsx` — cross-link to /accuracy under "By the numbers".
- `src/app/support/page.tsx` — added "How accurate are the tax
  calculations?" FAQ (plain-text reference to the Accuracy page).
- `src/app/sitemap.ts` — `/accuracy` entry (priority 0.6, monthly).
- `src/components/layout/Footer.tsx` — Product → Accuracy & Tax Data link.

## GA4 details

- Property `G-K62WBF51P9` (owned by john.urban@me.com).
- New events: `page_view` (path `/accuracy` on nav) and
  `methodology_pdf_download` ({source}). Appear in Realtime ~30s.
- TODO (optional): mark `methodology_pdf_download` as a Key Event in
  GA4 Admin → Events to surface it in reports/ads attribution.

## Methodology doc source of truth

- `tax-data-methodology.md` (committed `6a6e110` in worktree
  `.worktrees/1.8.5-state-tax-refresh/`) — restructured into durable body
  §1-8 + versioned "Current release" appendix. 20-year refs removed.
- Applied hedge edit to the doc's "no known errors" line to match the
  public-page framing. Regenerated PDF via `_render_methodology_pdf.py`.

## Open / not yet done

- (Offered, not confirmed) Surface methodology PDF in /press
  downloadable-assets block via PressDownloadButton (the
  `trackMethodologyDownload("press")` source already exists for this).
- (From synthesis, not decided) Perplexity's "Verification Record" retitle
  + "what this is NOT claiming" line; Gemini's §8 professional-invitation;
  Claude Chat press-version hygiene (anonymize change-log users).
- **Carryover security TODO:** rotate ImprovMX API key
  `sk_2edc...b1067` — exposed in earlier transcripts.

## Post-deploy verify checklist

- https://retiresmartira.com/accuracy loads
- CTA "Read the full methodology (PDF)" opens the PDF
- Footer Product → Accuracy & Tax Data works
- GA4 Realtime shows page_view /accuracy + methodology_pdf_download
