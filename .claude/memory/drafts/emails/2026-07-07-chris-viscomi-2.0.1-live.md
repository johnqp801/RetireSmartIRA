# Chris Viscomi — "2.0.1 is live, senior-deduction fix shipped" (SENT 2026-07-07)

**Status:** SENT 2026-07-07, from john@retiresmartira.com.
**Context:** Chris Viscomi (Humble Dollar reader) emailed support@ 2026-07-04 asking whether the $6,000 OBBBA senior-deduction MAGI phaseout was modeled. The code audit that answered him surfaced the senior-bonus *itemization* bug (65+ itemizers under the phaseout silently lost the deduction). Fixed on `main` 2026-07-06 (`f88966b`), shipped in **2.0.1 / build 59**, approved & live both platforms 2026-07-07. This note tells him it's live. (Fix verified as an ancestor of the 2.0.1 build.)

---

**Subject:** RetireSmartIRA 2.0.1 is live — the senior-deduction fix shipped

Hi Chris,

Quick follow-up on your note about the OBBBA senior deduction. The fix is now live — version 2.0.1 is in the App Store for both iPhone/iPad and Mac.

To recap what changed: the $6,000 / $12,000 age-65+ senior deduction now applies whether you take the standard deduction or itemize, and it phases out correctly above the $75,000 (single) / $150,000 (married filing jointly) MAGI thresholds. Your question is exactly what surfaced it, so thank you — it made the app more accurate for everyone in that situation.

If you update to 2.0.1 and anything still looks off, just reply and I'll take a look.

Best,
John
RetireSmartIRA
