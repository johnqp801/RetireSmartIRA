# Session: Press Outreach Launch — Karsten, Fritz, Chris

> **Provenance:** This session note came from a parallel Claude chat session
> (not Claude Code), saved here by John on 2026-05-25 evening for cross-session
> continuity. Future Claude Code sessions should treat it as authoritative for
> press-outreach state. Content below is preserved verbatim from the source
> chat; light formatting only.

**Date:** 2026-05-25 (Memorial Day weekend — self-labeled "Sunday" in the source, actual day was Memorial Day Mon 5/25)
**Topic:** Press outreach strategy and first wave of pitches

## Outcome

Three pitches sent in one session, each to a different audience flavor with a different angle. First real press outreach campaign for RetireSmartIRA.

## Pitches sent

| Recipient | Outlet | Email | Angle | Reference anchor |
|---|---|---|---|---|
| Karsten Jeske | Early Retirement Now | ernretirenow@gmail.com | Analytical rigor, "skeptical math-first reaction," find-my-edge-cases hook | SWR Series Part 45 retirement tax-planning case study |
| Fritz Gilbert | The Retirement Manifesto | Fritz@TheRetirementManifesto.com | Warm storyteller, 71-year-old fellow retiree, phase-based mental model | Trifecta Theory post + Ultimate Retirement Planning Guide stage organization |
| Chris Mamula | Can I Retire Yet? | chris@caniretireyet.com | Practical tool, complementary to Boldin/Pralana, 2027 piece companion | "Year Beginning Tax Planning Tips" (January 2026) |

## Follow-up schedule

Since pitches sent on US federal holiday (Memorial Day), day-7 bump adjusted to give recipients a full business week from first real read:

- **Day-7 bump:** Tue 6/2 or Wed 6/3
- **Day-14 cold:** Mon 6/8 — mark cold permanently if no reply, no third email

## Strategic decisions made

### Why these three, in this order
Rejected Christine Benz-first approach in favor of credibility-laddering: build coverage at Tier 1 (Substacks/FIRE blogs) and Tier 2 (niche podcasts) before pitching summit targets (Benz, WSJ, NYT). Each piece of coverage makes the next pitch easier — "as featured in" lines and lifted quotes compound.

### Why pitches were not copy-paste
Each writer has a different identity to flatter and a different audience to reach:
- Karsten = analytical economist, wants intellectual respect, audience cares about edge cases
- Fritz = warm retired storyteller, audience identifies with him personally, cares about phases of retirement life
- Chris = practical educator, ecosystem-aware (Boldin/Pralana affiliates), audience downloads tools

### Hooks dropped that didn't fit
- "Lifetime free unlock" language removed entirely — relevant for planner outreach (where it was a real perk), irrelevant for bloggers (who care about discovery, credibility, narrative material, not free access)
- Test count (950+) included for Karsten and Chris, omitted for Fritz (wrong vocabulary for his audience)
- ACA cliff at 401%-of-FPL boundary specificity included for Karsten only (his beat)
- 2027 hook (planted seed about Chris's hypothetical "2027 Year Beginning" post) used only for Chris — too specific for the others

## Press page state at time of outreach

Press page (retiresmartira.com/press) ready for pitches with:
- Dual boilerplate (1-sentence + 1-paragraph)
- "By the numbers" stats strip (50 states, 2026 limits, 7 tax mechanics, 950+ tests) — the 950 tests is the standout
- Five Story Angles section (ACA cliff, widow's penalty, RSU/NQDC unwind, "can I retire" reframe, on-device privacy)
- Downloadable press kit (.zip), app icon, founder headshot
- Three App Store quotable reviews (anonymous handles)
- LinkedIn URL added to founder section
- Footer email consistency fixed (no more gmail address in footer)

LinkedIn profile (linkedin.com/in/john-urban-isp) verified live and clickable from press page. About section flagged as needing rewrite — currently still leads with supply chain identity rather than RetireSmartIRA. Suggested rewrite drafted, not yet applied.

## App state context

- Current version: 1.8.4 (released 5/21/26)
- Recent additions since 1.6 (visible on marketing site): Social Security Couples Planner, ACA cliff modeling, Family Legacy Planning, 2026 IRS limits + ACA repayment warnings
- Pricing: Free through 2026, subscription planned for 2027 (disclosed to Chris only, since it aligned with the 2027 hook)

## Next prospects in queue

Held off sending more pitches this week — three in flight is the right pace. Next candidates:

**Tier 1 (similar to today's wave):**
- Darrow Kirkpatrick at Can I Retire Yet? — *deprioritized after recon revealed Chris Mamula is the active author*
- The Mad Fientist (Brandon) — selective, mostly podcast now
- Wade Pfau / Retirement Researcher — academic, would lend serious credibility if covered, but higher bar

**Tier 2 — podcasts (different template entirely, reframe as guest-appearance):**
- Andy Panko, Retirement Planning Education
- Ben Brandt, Retirement Starts Today
- Jeremy Keil
- Taylor Schulte

## What to remember next time

- Bryan Jepson pattern (warm-but-stalled — said yes three times, never followed through) is the trap to avoid. Three-touch maximum: send, bump at day 7, final at day 14, then dead. Don't let warm-but-stalled prospects occupy mental space that should go to new outreach.
- Different writers care about different things. Don't carry forward template language across audiences.
- Vercel CDN cache requires empty git commit (`git commit --allow-empty -m "..." && git push`) to force refresh. Web_fetch from this side may still serve cached version for 5–15 minutes after fresh deploy.
- LinkedIn About section still needs rewrite — drafted but not applied. Higher priority than other LinkedIn polish items because a journalist clicking through from /press will see it.
- Phone number removed from email signature — generally cleaner for cold outreach.

## Open items / blockers

- LinkedIn About section rewrite — drafted, not yet applied
- GTNexus listing in LinkedIn Experience section — needs verification that it's visible (press boilerplate leans on this credibility heavily)
- Demo video for press kit — not blocker for written press, becomes a blocker for podcast outreach
- Named real-user testimonials — current reviews are anonymous handles; one named retiree would punch harder for press

---

## Cross-references to Claude Code sessions

This press outreach used assets shipped during these Claude Code sessions:

- **2026-05-23** (`sessions/2026-05-23-jonggie-thankyou-mac-review-support-alias.md`):
  `support@retiresmartira.com` alias set up; CONTACT_EMAIL discovery and punch list.
- **2026-05-24** (`sessions/2026-05-24-contact-email-swap-and-asc-cleanup.md`):
  CONTACT_EMAIL swap deployed (footer email consistency fix) + ASC cleanup.
- **2026-05-24 evening** (commit `d60cb39` in website repo):
  LinkedIn link + Story angles (5) + By-the-numbers stats strip + version bump
  to 1.8.4 on `/press` — directly enabled the credibility-laddering pitch
  approach described above.

---

## 2026-05-26 update — DMARC delivery confirmation for 2 of 3 pitches

Google DMARC aggregate report for retiresmartira.com covering the
2026-05-24 UTC window (`report_id: 8828400257156459342`) showed two records
consistent with successful delivery to Karsten and Chris. Source file:
`~/Downloads/google.com!retiresmartira.com!1779667200!1779753599.xml`.

| Pitch | Recipient | DMARC evidence | Interpretation |
|---|---|---|---|
| Karsten Jeske | ernretirenow@gmail.com | Record 2: SPF pass for `gmail.com`, header_from `retiresmartira.com`, disposition `none` | Likely received at Gmail. Karsten's address is a Gmail. |
| Chris Mamula | chris@caniretireyet.com | Record 1: DKIM pass for both `cloudflare-email.net` AND `caniretireyet.com` (selector `cf2024-1`), SPF pass for `caniretireyet.com`, disposition `none` | **Strong evidence of routing through Chris's mail infrastructure.** Chris uses Cloudflare Email Routing for `caniretireyet.com`; the `caniretireyet.com` DKIM pass only happens when CF re-signs forwarded mail with that domain's key. |
| Fritz Gilbert | Fritz@TheRetirementManifesto.com | Not in this report window | Either Fritz's mail host doesn't report to Google, the message landed in a different report window, or processing was outside the 5/24 UTC window. Inconclusive — not evidence of failure. |

**Important caveat:** DMARC reports confirm *delivery to the recipient's mail
infrastructure*, not that the human read the message. Two-of-three reaching
their inboxes is the floor of what we know, not the ceiling.

**Alignment status unchanged:** Both records show SPF and DKIM alignment
failing against `retiresmartira.com` (expected — no DKIM signing for the
domain, Gmail Send-As sends envelope-from = gmail.com). Disposition `none`
on both records because policy is `p=none`. No action needed.

**Follow-up reminder still stands:** day-7 bumps on Tue 6/2 or Wed 6/3
regardless of this delivery evidence. Delivery ≠ read; absence of reply
by day 7 still warrants a polite bump.
