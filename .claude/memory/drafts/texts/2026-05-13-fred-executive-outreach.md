# Text to Fred — three-phase planning framework + 3PL executive outreach

**Date drafted:** 2026-05-13
**Recipient:** Fred (retired 3PL / supply chain executive; beta tester)
**Status:** Draft — sent / intended to send via text message
**Context:** Fred caught the inherited IRA projection chart truncation bug in earlier feedback. This text closes that loop, then frames the broader executive-in-retirement audience using the three-phase planning framework, names competitors that miss this segment, and asks for word-of-mouth across his 3PL executive network.

---

Hey Fred — quick 1.8.1 update.

First, thank you for the inherited IRA chart feedback. Your diagnosis led to a real fix that's now live. Beta input from someone who actually *uses* this stuff is what shapes the product — and catching a misleading visual that a less attentive user might have missed is exactly the input that matters.

Since 1.8.1 wrapped, I've been thinking about the broader audience this app serves. You and I have walked similar career paths in 3PL and supply chain. Executives who built careers in our world end up in retirement with a fairly specific financial profile:

• Significant taxable savings AND large 401(k) / IRA balances — both moving at once
• Concentrated stock or deferred comp still unwinding post-retirement
• High marginal brackets that compress the planning window dramatically
• Three distinct phases, each demanding different decisions

**Pre-65 retirees** are managing: when to claim Social Security, how to keep MAGI low for ACA subsidies if pre-Medicare, when to unwind deferred comp, how to fund living expenses without triggering IRMAA two years downstream.

**The conversion window (65-72)** is the highest-leverage period most people don't fully use: how much to convert to Roth each year given IRMAA tiers, NIIT, and the 32% bracket cliff. Most retirement tools optimize *portfolios*. Almost none model the actual annual tax decisions a 65-year-old with a $4M IRA is facing.

**RMD age (73+)** brings forced distributions, QCDs to keep MAGI manageable, charitable timing, and the surviving-spouse bracket jump if one of you passes. The math gets more complex precisely when most people want it to get simpler.

I've been researching what's out there. The major retirement planning apps — **Boldin (formerly NewRetirement), Pralana, MaxiFi, Empower (formerly Personal Capital), and the Fidelity / Vanguard / Schwab retirement calculators** — all answer some version of "Can I retire?" None of them really answer the question executives at our stage actually have: *what should I do this year?* Roth conversions, MAGI management, IRMAA cliffs, QCD timing, charitable stock donations — these are the levers that move the most money in retirement, and none of these tools model them well together.

I'd like RetireSmartIRA to be that tool for executives like you and your peers.

Two asks:

**1. Word of mouth across your 3PL executive network.** Retired peers, former colleagues, board contacts — anyone navigating the same transition. This segment is genuinely underserved by existing tools.

**2. Keep the feedback coming.** Your inherited IRA catch already shaped the product. Anything you bump into — UX friction, math you don't trust, scenarios the app handles awkwardly — please send it. Your input drives the roadmap.

Share **retiresmartira.com** with anyone. Free, native on iPhone, iPad, and Mac.

Thanks again, Fred. The product is meaningfully better because of your input.

— John

---

## Related commits

- `3a3481c` — Fix Inherited IRA projection chart truncation (Fred feedback)
- Earlier diagnosis note: `docs/superpowers/notes/2026-05-09-fred-inherited-ira-chart-diagnosis.md`

## Reusable framing extracted from this message

The three-phase executive framework here is a clean restatement of personas 1b / 2 / 3 from the website's PersonaGrid. If we ever want a dedicated "for executives" landing-page section or a longer-form blog post for the executive segment, this language is the starting point:

- Pre-65: SS, ACA, deferred-comp unwind, IRMAA-2-year-lookback awareness
- 65-72: Roth conversion sizing under IRMAA / NIIT / bracket-cliff constraints
- 73+: RMDs, QCDs, charitable timing, surviving-spouse bracket jump
