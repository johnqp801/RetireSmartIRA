# Alan Levy: how to categorize a 457, and does it calculate differently

**Status: SENT 2026-08-03** from john@retiresmartira.com.
**His question, 1:59 PM:** "How would I categorize a 457 account in add account, account type?
Are there any differences between a 457 and traditional 401k or Ira in your app calculations?"

## Why this arrived at a useful moment

Alan independently asked the question State Tax Phase 3b's design turns on. He is the NYC
government-pension user whose report started the per-source work, and a 457 is the exact
salary-reduction case that must NOT receive New York's IT-201 line 26 exclusion. His question is
a live validation that the classification is worth its scope.

## Verified before answering

- **No 457 account type exists.** `AccountType` has traditionalIRA, rothIRA, traditional401k,
  roth401k, and the two inherited variants. The only occurrences of "457" in the whole codebase
  are comments in Maryland's and New Jersey's state configs.
- **The app models no early-withdrawal penalty at all.** Confirmed by grep across the source, and
  stated in the app's own UI at `RothConversionWithholdingCard.swift:123`: "This app does not yet
  model that penalty."
- **RMD age varies by birth year** (`ProfileManager.swift:101-109`): 72 before 1951, 73 for
  1951-1959, **75 for 1960 or later**. An earlier draft said "RMDs begin at 73" flatly, which
  would be wrong for anyone born 1960+. Corrected to "the same age", since the sentence's job is
  to say 457 and 401(k) behave alike.

## SENT TEXT

Alan,

Use Traditional 401(k). There is no 457 option today, and that is the closest fit.

For everything the app actually calculates, a governmental 457(b) behaves identically to a
traditional 401(k): distributions are ordinary income, RMDs begin at the same age, balances grow
and draw down the same way, and a rollover to an IRA followed by a Roth conversion is treated the
same. So categorizing it as a Traditional 401(k) does not distort anything the app is computing
today.

Two real-world differences it does not capture, both worth knowing:

1. The 10% early-withdrawal penalty. A governmental 457(b) is exempt from it once you separate
   from service, at any age, which a 401(k) and an IRA are not. The app does not model that
   penalty for any account type, so nothing is being calculated wrongly, but it also will not
   show you that particular 457 advantage.
2. For New York state tax, a 457 does not qualify for the government pension exclusion on IT-201
   line 26, even though your employer is governmental. Line 26 covers the pension itself. A 457
   or a 403(b) is a salary-reduction plan and falls under the separate $20,000 line 29 exclusion
   along with other retirement income. So your pension and a 457 would be treated differently by
   New York, and the app does not yet distinguish them.

That distinction is exactly what I am building now, off the back of your pension report. The work
adds a plan type to each account so a 457 or 403(b) can be identified as itself, shown as itself
rather than as a 401(k), and taxed correctly by states that treat them differently.

Your question is a good check on the design, because it is the case that has to work.

John

## Two open questions about the sent version

1. Whether the "RMDs begin at the same age" correction was applied before sending. If it went out
   saying 73 and Alan was born in 1960 or later, expect a follow-up.
2. Whether the optional closing line about the caret fix was added. It was offered and not
   confirmed either way. The caret fix has been owed to Alan since 2026-07-19, missed 2.3.0, and
   still sits unshipped on `main` ([[pending-fixes-next-release]]).
