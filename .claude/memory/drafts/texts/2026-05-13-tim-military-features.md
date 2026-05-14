# Text to Tim — V1.8.1 military features + word-of-mouth ask

**Date drafted:** 2026-05-13
**Recipient:** Tim (retired military beta tester)
**Status:** Draft — sent / intended to send via text message
**Context:** Tim's input in earlier feedback rounds drove the 1.8.1 Military Retirement + VA Disability features. This text closes the loop on what shipped, names the underserved segment, and asks for word-of-mouth + continued feedback.

---

Hey Tim — quick 1.8.1 update.

Everything you asked for around retired military households is now in the app:

• **Military Retirement** as a distinct income type (not lumped in with generic "pension")
• **State-by-state exemption table** — the ~30 states that fully exempt military retirement pay are properly recognized, so your effective state tax is right
• **Dynamic state-treatment hints** when you enter Military Retirement — the app tells you how your current state handles it
• **VA Disability** as its own income type, properly excluded from federal *and* state tax per IRC §104(a)(4)
• All wired into the Scenarios builder and quarterly tax math
• **Integration tests built specifically around your scenario** so it doesn't regress in future updates

Since you flagged this gap, I've been doing some research. The major retirement planning apps — **Boldin (formerly NewRetirement), Pralana, MaxiFi, Empower (formerly Personal Capital), and the Fidelity / Vanguard / Schwab retirement calculators** — all share the same blind spot. None of them properly model military retirement. None handle the state exemptions. None treat VA Disability as a first-class concept. Retired military is a real and seriously underserved segment.

I'd like RetireSmartIRA to fill that gap.

Two asks:

1. **Word of mouth.** Please mention the app to your retired-military counterparts. It's the only retirement tax app I'm aware of that's actually built for their situation.

2. **More importantly — please keep sending feedback.** Your input directly shapes the roadmap. The more retired-military voices contributing, the better this gets for everyone in your community.

Feel free to share **retiresmartira.com** with anyone. Free download, runs natively on iPhone, iPad, and Mac.

Thank you for putting this segment on my radar in the first place. Genuinely couldn't have built the right thing without you.

— John

---

## Related commits

- `2aadee1` — Add IncomeType.militaryRetirement enum case (Tim feedback)
- `9fe8ce3` — Add MilitaryRetirementExemption state lookup table
- `dd5d2ea` — Wire MilitaryRetirementExemption into state-tax computation
- `3041ee8` — Add dynamic state-treatment hint for Military Retirement income type
- `4075a45` — Add integration tests for Tim's retired-military scenario
- `6ca1283` — Add VA Disability income type (excluded from all tax calculations)
