# Session: Articles Launch, Bryan Jepson Outreach, Advisor Market Signal
**Date:** 2026-06-08
**Status:** Complete

---

## 1. What We Did This Session

### 1.8.6 App Store Approval
- Both iOS and macOS versions of 1.8.6 (build 51) approved and live as of 2026-06-07
- Tag v1.8.6-build51 pushed to origin
- Memory and roadmap updated

### Google Search Console Setup (2026-06-07)
- GSC verified for https://www.retiresmartira.com via HTML file method (google88c45cac05ff1a4a.html in /public/)
- Sitemap submitted (Next.js auto-generates /sitemap.xml)
- 7 existing pages submitted for manual indexing (/, /features, /press, /about, /accuracy, /support, /whats-new)
- /press was already indexed; /whats-new required indexing request

### Articles Section — Full Implementation
Built and deployed a complete /articles section on retiresmartira.com.

**Components created** (src/components/articles/):
- ArticleLayout.tsx — hero header, prose container, action buttons row; `updatedLabel` prop optional
- ArticleCard.tsx — exports ArticleMeta interface; linked card for index listing
- KeyTakeaways.tsx — brand-tinted bullet list box
- StatCallout.tsx — named export StatCalloutRow; responsive stat grid
- Callout.tsx — left-border accent aside
- WorkedExample.tsx — dark-header table with alternating rows; accessible caption
- ArticleCTA.tsx — "use client"; App Store CTA with article_cta analytics tracking; print:hidden
- FAQ.tsx — "use client"; accordion with aria-controls/aria-expanded; FAQItem exported; answer: ReactNode; always-rendered panels (hidden class) for print

**Pages created:**
- src/app/articles/page.tsx — index listing with ARTICLES array
- src/app/articles/irmaa-brackets-2026/page.tsx — full IRMAA article (526 lines)

**Modified files:**
- src/components/layout/Header.tsx — added Articles nav link (after What's New, before About); print:hidden on header
- src/components/layout/Footer.tsx — print:hidden on footer
- src/app/sitemap.ts — added /articles (weekly, 0.8) and /articles/irmaa-brackets-2026 (monthly, 0.8)
- src/lib/analytics.ts — added "article_cta" to trackAppStoreClick source union
- src/app/globals.css — @media print block (FAQ panels, table overflow, gradient bg, link styling)

**Share + PDF functionality:**
- ShareButton.tsx — Web Share API with clipboard fallback, "Copied!" confirmation
- PrintButton.tsx — window.print()
- Both buttons appear in ArticleLayout hero, print:hidden themselves

**IRMAA article accuracy corrections applied:**
- QCD limit: corrected to $111,000 in 2026 (source had $105,000)
- Part D Tier 2: corrected to $37.50 (source had $37.60)
- Part D Tier 4: $83.50 — flagged with code comment to verify against SSA POMS HI 01101.020

**Polish iterations based on user feedback:**
- Disclaimer text darkened (text-gray-400 → text-gray-600) for PDF readability
- BracketTable min-w-[560px] added for mobile horizontal scroll
- Tier column visibility improved (text-gray-400 → text-gray-500 font-medium)
- Print table overflow fixed (@media print overflow-x-auto → overflow: visible)
- Added restrained product callout (gray-50 box, not print:hidden) after Strategies section, before closing paragraph, with copy: "Before you convert, check the Medicare cost too / RetireSmartIRA models IRMAA alongside Roth conversions, RMDs, Social Security income, and tax brackets..."
- CTA link text updated to "Download RetireSmartIRA on the App Store →"

**All commits on main, deployed to Vercel:**
- f9fa91c feat: add article UI components
- e5c8f26 fix: article components polish
- 748421c feat: ArticleCTA, FAQ, analytics
- 8acbbd4 fix: FAQ accessibility
- b770323 feat: /articles index page
- 238afb2 feat: IRMAA article
- 12f0198 feat: nav + sitemap
- f89f980 feat: share + save-as-pdf
- c09ba7b fix: table visibility + print overflow + product callout
- 96b2f87 fix: disclaimer, mobile tables, CTA text

### Google Search Console — Article URLs Submitted (2026-06-08)
Both article URLs manually submitted for indexing:
- https://www.retiresmartira.com/articles
- https://www.retiresmartira.com/articles/irmaa-brackets-2026
Check back Wednesday June 10 for index coverage.

---

## 2. Bryan Jepson Outreach

**Who:** Bryan Jepson, MD, CFP®, MSF, ChSNC® — Financial Advisor, Targeted Wealth Solutions LLC
- Phone: 512-965-7734
- Email: bryan@targetedwealthsolutions.com
- Web: www.targetedwealthsolutions.com | www.bryanjepson.com

**Note sent (2026-06-08):**
> Bryan — I've been building out a content side for RetireSmartIRA and just published the first article — on 2026 IRMAA brackets and how Roth conversions can cross a Medicare premium cliff: https://www.retiresmartira.com/articles/irmaa-brackets-2026
>
> Advisors like you are exceptional at the strategic layer — knowing when to convert, how to sequence RMDs, where the IRMAA thresholds sit... What I'm trying to build is a tool that sits with you and your client — something you can pull up together and work the numbers: what does a $40K conversion cost versus $50K, once you factor in income tax, the IRMAA tier, RMD interaction, and Social Security taxation together. Not a replacement for the advice, but the analytical layer that makes the conversation more concrete.

**Bryan's response (2026-06-08) — full text:**
> Hi John,
> I think that the article is great. Very informative and well written. I'll definitely refer my clients to it to help them understand IRMAA rules better.
>
> I love the app. I think it is very helpful. I like how it presents the information. The problem is that because I work remotely on a PC with my clients, not a Mac, I don't know how to use it with them during a client meeting. What would be ideal is for me to have it on a separate window that I can refer to when I screen share so that we can both see the impacts of the decisions together. Then I can go through the graphs and the scenarios with them. Our planning software does something similar but I think it is harder to get to and doesn't display it as well as your app does. So, I would probably use your app more if it were practical to do so. Is there a work-around for this problem?
>
> Also, a question. Who is the target audience for the app, ultimately? Is it advisors or is it direct to consumers to use on their own, or is it both? Maybe I'm using it wrong but it looks like the app is set up for a single user at this point. So, if I want to use it, I have to change all the data for that user and get a result. If you want advisors to use it, you would need some sort of client folders built in where you can use and store multiple people's information at once. And it would be awesome if it communicated with the other common planning platforms to glean data so there is not a lot of duplication of date entry effort.
>
> I'd be curious to know more about your vision.
>
> Bryan

**Key signals from Bryan's response:**
1. Loves the app and article — will refer clients to article
2. Platform blocker: works on PC remotely, cannot screen share the iOS/macOS app
3. Wants to show it to clients during meetings (screen share use case)
4. Current planning software does something similar but is harder and displays worse
5. Identified single-user limitation immediately — asked for multi-client/client folders
6. Asked about planning software integration (eMoney, MoneyGuidePro etc.) — data entry duplication
7. Explicitly asked about vision: advisors vs. DTC vs. both

---

## 3. Advisor Product Analysis

### Web-Based Advisor Version
**Complexity:** High. Would require:
- Porting or API-wrapping the Swift engine
- Full React/Next.js frontend rewrite
- Backend: auth, database, multi-tenancy
- iCloud/sync not applicable

**Estimates:**
- Web MVP (single user, screen-share only): 3–4 months, $60–100K
- Advisor MVP (multi-client, folders, auth): 8–12 months, $200–350K
- Full platform with integrations: 2–3 years, $600K–1M+
- Monthly infrastructure: $400–850/month

**Conclusion:** Correct long-term direction but significant investment. Bryan can't use it today.

### Native Mac/iOS Advisor Version ← MORE TRACTABLE
**Complexity:** Much lower. Engine exists. SwiftUI framework exists. Platform exists.

**What needs to be built:**
1. Client data model — add Client entity wrapping existing retirement parameters (SwiftData)
2. Client list UI — create/edit/archive/search clients, master-detail on iPad, three-column sidebar on Mac
3. Per-client data isolation — all existing screens load selected client's data
4. iCloud sync — SwiftData + CloudKit, multi-device (Mac at office + iPad in meeting)
5. macOS sidebar polish — three-column layout optimized for large screen

**Timeline:** 3–4 months focused development
**Cost:** $50–90K contracted ($100–150/hr), or 3–4 months solo
**Risk:** Low — building on proven foundation. iCloud sync is trickiest part.

**Distribution options:**
- Professional subscription tier within existing app ($15–25/month or $150–200/year)
- Separate "RetireSmartIRA for Advisors" app
- Recommendation: Pro subscription unlock in existing app

**Note:** Bryan specifically uses PC remotely — the native Mac/iOS version would NOT solve his immediate problem even if built. But it addresses the broader advisor segment who use Macs.

---

## 4. Strategic Question — Open

**Is there a real addressable market for RetireSmartIRA among financial advisors?**

Bryan's response is the strongest signal to date that advisors see value. Key questions to answer before committing to the build:
- How many advisors are in the target demographic (independent RIAs, fee-only CFPs serving HNW retirees)?
- What do they currently use for retirement tax modeling in client meetings?
- Would they pay $150–200/year for a tool this focused?
- Is Bryan an outlier (heavy Mac user, tech-forward) or representative?
- What are the regulatory considerations (advisors recommending/using third-party tools with client data)?

**Suggested next step:** Have a deeper conversation with Bryan — and 3–5 other advisors — specifically about their current workflow, what they use today, what they'd pay, and whether the gap is real.

**This is a V2.x decision** — should not redirect V2.0 (Plan B / UI) which remains the immediate priority.

---

## 5. Open Action Items

| Item | Due | Notes |
|---|---|---|
| Check Google Search Console | Wed Jun 10 | Index coverage, first search queries, both article URLs + original 7 |
| Press follow-up: Karsten, Fritz, Chris | ✅ Done Jun 8 | Sent personalized follow-ups with IRMAA article link; no further follow-up planned — mark cold if no response |
| Reply to Bryan Jepson | Soon | Draft prepared; address workaround honestly, share vision, invite ongoing conversation |
| Verify Part D Tier 4 surcharge | Before article 2 | Check $83.50 against SSA POMS HI 01101.020 |
| Article #2 | When ready | User provides content as plain text; Claude builds TSX page |
| ConvertKit setup | At article 3 | Email capture at bottom of articles |
| Advisor market research | Future | Determine if advisor segment is real and addressable before building multi-client features |

---

## 6. Website Infrastructure Reminder

| Layer | Provider |
|---|---|
| Domain | Namecheap (account: johnqp — doesn't appear in dashboard, possibly sub-account) |
| DNS | Namecheap nameservers → Vercel |
| Hosting | Vercel (project: retiresmartira-website, private) |
| Repo | GitHub: johnqp801/retiresmartira-website |
| Auto-deploy | Every push to main |
| GA4 | G-K62WBF51P9 (john.urban@me.com) |
| GSC | Verified: https://www.retiresmartira.com (HTML file method) |
