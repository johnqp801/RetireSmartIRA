# Session: Google Search Console Setup + GA Review
**Date:** 2026-06-07
**Status:** Complete

---

## What We Did

### 1. Reviewed Google Analytics (retiresmartira.com)
- Pulled GA Reports Snapshot for two periods:
  - Last 28 days (May 10 – Jun 6): 34 active users, 33 new, 3m 24s avg engagement, 397 events
  - Last 7 days (May 31 – Jun 6): 7 active users, 6 new, 1m 49s avg engagement, 49 events
- Key findings:
  - Almost all traffic is direct (24/34 first users) — SEO not yet contributing
  - Google organic: only 2 visitors in 28 days — site not indexed well yet
  - Homepage bounce rate rising: 31.4% (28-day) → 54.5% (last 7 days) — worth monitoring
  - Features page (11.1% bounce) and Accuracy & Tax Data page (0% bounce) perform well for engaged visitors
  - Ashburn VA = 10/34 users (29%) — possible bot/crawler inflation; real human audience may be smaller
  - LinkedIn referral = 1 visit; press outreach not yet driving web traffic
  - `accuracy_page / (not set)` session source = 3 sessions — some link somewhere has `?utm_source=accuracy_page` tag

### 2. Set Up Google Search Console
- **Property verified:** `https://www.retiresmartira.com`
- **Verification method:** HTML file upload
- **File:** `google88c45cac05ff1a4a.html` placed in `public/` folder of the website repo
- **Verification status:** ✅ Ownership verified (2026-06-07)

---

## Website Infrastructure

| Layer | Provider | Notes |
|---|---|---|
| Domain registration | **Namecheap** | `retiresmartira.com` registered here; account: johnqp |
| DNS | **Namecheap** | Nameservers point to Vercel |
| Hosting / deployment | **Vercel** | Project: `retiresmartira-website` (Private) |
| Source code | **GitHub** | Repo: `johnqp801/retiresmartira-website` |
| Framework | **Next.js** | `next.config.ts` present; `public/` folder for static assets |
| Auto-deploy | Yes | Every push to `main` triggers Vercel production deploy |

**Note:** `retiresmartira.com` does NOT appear in the Namecheap domain list dashboard — possibly registered under a different Namecheap sub-account or the dashboard pagination hides it. DNS is managed through Namecheap nameservers pointing to Vercel.

---

## How to Add Static Files to the Website

For future reference (e.g., sitemaps, robots.txt, verification files):
1. Go to `github.com/johnqp801/retiresmartira-website`
2. Click `public/` folder → **Add file → Upload files**
3. Upload the file, commit to `main`
4. Vercel auto-deploys in ~60 seconds
5. File is live at `https://www.retiresmartira.com/<filename>`

---

## Action Item: Check Google Search Console — Wednesday June 10

**What to look for on June 10:**
- **Index Coverage** — are all pages indexed? (Home, Features, Press, About, Accuracy, Support, What's New)
- **Search Queries** — what terms is Google showing the site for, even if no clicks yet
- **Impressions vs. Clicks** — if impressions > 0 but clicks = 0, the meta title/description needs work
- **If impressions = 0** — the site is not being crawled; may need to submit a sitemap

**How to get there:** search.google.com/search-console → select `https://www.retiresmartira.com`

---

## Next Steps (SEO)
1. ✅ Google Search Console verified
2. ⬜ Check GSC on June 10 for index coverage + first query data
3. ⬜ Submit XML sitemap to GSC if not already present (`/sitemap.xml`)
4. ⬜ Monitor homepage bounce rate — if still >50% in 2 weeks, review hero section
5. ⬜ Monday June 9 — day-14 press follow-up due (Karsten, Fritz, Chris — final touch before marking cold)
