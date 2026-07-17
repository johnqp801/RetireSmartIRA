# Email to Fred — long-term vision: Scenarios + Tax Summary + Multi-Year as one system

**Status:** Approved by John 2026-07-14 (final; solo "I" voice per John). John to send from john@retiresmartira.com.
**Recipient:** Fred (external reviewer who found the multi-year withdrawal gap — see backlog / Finding 2026-07-14).
**Purpose:** Lay an early product vision (annual execution connected to long-term planning; decumulation + withdrawal ordering) in front of Fred and ask for his input. Uses his conversion-ladder-ignores-Scenarios-withdrawals finding as the on-ramp.
**Provenance:** Draft 2 — revised after a ChatGPT critique John endorsed. Key adoptions: "recommend / commit / explain" principle; "keep both numbers" (never silently overwrite the plan recommendation); corrected the charitable claim (a plain cash gift generally does NOT move MAGI/IRMAA; a QCD does; appreciated securities differ); categorized the variable list instead of one flat inventory; lighter "still shaping it" tone. Framed as vision, NOT shipped (the Year-1 withdrawal/charitable round-trip is not built; only Year-1 Roth is a live shared lever).

---

**Subject:** Connecting this year's decisions to the long-term plan (early thinking, want your input)

Hi Fred,

Your note on the conversion ladder not seeing Scenarios withdrawals is worth more than a bug report, because it points straight at something I'm still working out. Let me keep this short and put three things in front of you.

**First, you found a real gap, not a missing input.** If someone enters a $100k IRA withdrawal in Scenarios, they'd reasonably assume the multi-year plan knows about it. Today it doesn't, and that quietly throws off conversion room, future balances, current taxable income, IRMAA, and RMDs. It's a break in the promise that the two views are the same plan.

**Second, here's where I'm headed, in one line:** the multi-year plan should *recommend*, Scenarios should let you *commit*, and Tax Summary should *explain*. The long-term plan stays your strategic anchor, but you keep full control of this year. When you depart from the recommendation, and people will, for good reasons, the app shouldn't block you or quietly lose the recommendation. It should keep both numbers, re-plan the future from where you actually landed, and show you what the deviation cost against the original recommendation.

**Third, and this is where I most want your thinking: decumulation and ordering.** The real question isn't "how much do I withdraw," it's "how much cash do I need, from which account, for what purpose, and in what order." Source and use both matter. A $100k IRA distribution spent on living expenses is not the same as one reinvested in a brokerage, even though both create the same ordinary income. And there's no single right withdrawal order. It shifts with marginal rates, IRMAA and ACA thresholds, an inherited IRA on a 10-year clock, basis, and survivor and legacy goals. I want a sensible default sequence the user can override, with an engine still free to deviate when another order serves the goal better.

For the model to support that, here's what eventually has to participate (not all exposed at once):

- **Conversions and distributions:** Roth conversions by spouse; owner IRA/401(k) distributions; inherited-IRA distributions and remaining deadline; RMDs.
- **Charitable:** QCD vs. cash vs. appreciated securities, since only some of those move MAGI and IRMAA (a cash gift generally doesn't; a QCD does).
- **Cash needs and funding:** living expenses, one-time expenses, and how conversion taxes get paid (existing cash, taxable sales, a separate IRA distribution, or withholding, which matters because withholding leaves less in the Roth).
- **Consequences to keep honest:** bracket, MAGI and everything downstream of it (IRMAA two years out, ACA, NIIT, taxable Social Security), federal and state tax, balances over time, and what heirs keep.
- **Preferences:** withdrawal order and any bracket or IRMAA constraints, plus survivor and legacy objectives.

This is early. I'm shaping the model, not shipping it, and I'd rather have your read now than after it's built. Does this match how you actually walk someone through decumulation? What's missing? And where would you start?

Thanks Fred.

John
