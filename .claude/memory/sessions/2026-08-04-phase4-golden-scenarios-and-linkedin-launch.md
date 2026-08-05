# 2026-08-04: State Tax Phase 4 built and shipped to main, plus the widow-tax LinkedIn launch

**Start here next session:** `.claude/memory/roadmap/2026-08-04-state-tax-phase4-ledger.md`. That file is the Phase 5 entry point and is written for someone with no memory of today. This file is the context around it.

`origin/main` @ `d1a8618`. Suite green: 1,856 Swift Testing in 292 suites + 509 XCTest.

---

## 1. The widow-tax LinkedIn post went live

Posted ~10:14 AM Tuesday from the personal profile, native image with the link in the body, after being held four days deliberately for a Tue-Thu morning slot. John edited it before posting; the as-posted text is recorded in `drafts/linkedin/2026-07-31-widow-tax-arch-post.md` beside the original.

**What changed and what it cost.** The withheld-insight paragraph became a direct question, which is fine. The real delta is the link: the draft introduced it as "Three households worked all the way through, with the tables:" and as posted the shortened `lnkd.in` URL stands alone, so nothing on that line says what is on the other side of it. **If engagement arrives and clicks do not, that is the first thing to fix**, and it is still fixable in an edit or a first comment. Also dropped: "not the one this usually gets sold to" became "not the one you would expect", which removes the implied shot at advisors and is consistent with why hook candidate 1 was rejected.

### Theresa Reed's comment, and the reply DRAFTED BUT NOT SENT

A first-degree connection replied, disclosing that her husband died and that losing his income cost far more than $50,000. She asked whether $50K was supposed to be the income loss.

**She had generalised the top household's figure.** The article's actual losses, from `WidowTaxArticleScenarioTests`: Household C $90,000 to $73,500 (loses **$16,500**), Household B $180,000 to $150,000 (loses **$30,000**), Household A $360,000 to $308,000 (loses **$52,000**). No flat $50K anywhere; the $52,000 is only the highest-income household.

**The trap in replying, and it is not the arithmetic.** Do NOT assume she was working-age. If her husband held a pension that ended at his death, a fully retired household could also lose far more than anything in the article. The draft below is worded to cover both without presuming which she is.

**Drafted reply, John's to send or change:**

> Theresa, I'm sorry about your husband. Thank you for reading it, and for saying that.
>
> You're right, and it's a gap in the piece. All three households are already retired, and each one keeps its pension and its savings, so what stops is mostly the smaller of the two Social Security checks. That's a much gentler event than losing a salary, or losing a pension that ends at death.
>
> There also isn't a single $50,000 figure. The three households lose $16,500, $30,000 and $52,000. The $52,000 is only the highest-income one, so that may be the number that stuck.
>
> What you went through is the bigger version of this and the piece doesn't reach it.

No mention of the app. She is a bereaved reader, not a lead. Avoid promising a follow-up piece unless willing to be held to it.

---

## 2. Steve's third RMD point: real, distinct, already fixed

The 08-03 email told Steve his Tax Summary point was being checked separately. **It was a third issue and this is the answer owed to him.**

His spouse's RMD dollars were never missing. `DashboardView.swift:309-323` renders a separate line item labelled with her name, and `calculateSpouseRMD` gates on `spouseIsRMDRequired`, which reads her age against her own RMD age (`ProfileManager.swift:166-169`) and never touches the primary. Verified byte-identical between shipped `v2.3.0-build63` and `main`, so it was already correct on his build.

**What WAS wrong is the header card at the top of that tab.** Before `26044c3` it read `isRMDRequired` and `yearsUntilRMD`, both primary-only, so his household saw something like "Years Until RMD: 14" directly above his wife's correctly billed RMD. Same shape as the rest of that branch: primary-only status text above correctly attributed money.

**For the reply:** confirm it was a third issue, say the header now reads the household, and do NOT say the amounts were missing. Detail in `roadmap/2026-08-03-rmd-spouse-attribution-ledger.md`.

---

## 3. Two decisions (both in `decisions/log.md`)

**Phase 4 covers all 51 jurisdictions and the whole program ships as one build 64.** Narrowing to just the promised states was rejected, and the reason is not schedule: Steve's suggestion F and the internal audit are the same object. The per-state view is generated from the JSON and renders unverified jurisdictions as unverified, so shipping it against a mostly-unverified table would tell Steve, state by state, the blast radius John deliberately kept out of the 08-03 email. He posts on Bogleheads. **The disclosure feature's honesty is a function of how much of Phase 4 is done.**

**The caret fix extends to all nine numeric screens**, not `SettingsView` alone. Typing `8` into a field showing `3` silently commits `0.83`. `IncomeSourcesView` was the sharpest remaining risk.

**Mid-session, John chose to PARALLELISE** batches 5 through 9 across five worktrees after the sequential pace became clear. That knowingly forfeited Task 5's role as a gate for the later tiers. Per-batch reviews remained the net.

---

## 4. Phase 4: what was built

50 of 51 jurisdictions carry golden scenarios, 207 scenarios, **118 pinned defects across 35 jurisdictions**. Montana is CANNOT_VERIFY by design. **`git diff main -- RetireSmartIRA/` is empty across all 29 commits**, so nothing about the app's behaviour changed.

The mechanism that made this possible: a `knownDefect` block pinning the engine's MEASURED output while asserting it does NOT match the form. The suite stays green, every defect is a record, and the pin is self-cleaning because a Phase 5 correction turns the case red and forces the stale record's removal.

**The audit that started this program was narrower than it looked.** It examined ONE of thirteen configuration dimensions. Three of its claims were falsified outright (DC described expired law, Vermont and Utah each conflated two rules). The bigger story is what it never looked for: **Utah's rate is stale against even its pre-cut value, New Mexico runs a bracket table deleted by a bill signed in March 2024, and Georgia's rate is wrong.** None is a retirement exemption; all hit every filer in those states. **That is a live scope question for Phase 5 and it did not exist when the plan was approved.**

Full catalogue, four-bucket audit reconciliation, and the traps: the Phase 4 ledger.

---

## 5. Method findings worth carrying forward

**Three distinct citation failure modes, none visible to any test.** (a) Right document, wrong location: eleven instances, Wyoming citing slide 4 for text on slide 5 being the first. (b) **Invented text**: two instances. Hawaii's author diagnosed its own as *"generic domain-memory boilerplate written to match a conclusion I already believed, rather than derived from the source"*. In both cases the underlying claim was TRUE and quotable elsewhere in the same document, so only the evidence was fabricated. **The risk is highest exactly when you already know the answer.** (c) **Right document, wrong edition**: Maryland's figure was verified against a genuinely official worksheet that turned out to be the prior tax year's. Mode (c) is the most dangerous because every other control passes it.

**A reviewer finding is evidence, not fact.** Three times a fix dispatch carried a reviewer finding I had not re-verified, and three times it was wrong: a warning aimed at a state whose figures were correct, a document inconsistency attributed to the wrong state, and a finding mislocated to the wrong file. Only the fixers' refusal to comply blindly kept false statements out of fixtures. **Keep "verify before you comply" in every fix dispatch.**

**One implementer per worktree.** On Task 1 I resumed a stalled agent AND dispatched a replacement into the same worktree. They raced to commit and converged by luck.

**Agents die if they background a long build.** Three did. The Bash `timeout` parameter accepts up to 600000ms; the 120s default is not the ceiling.

**A WebFetch 403 is often a tool artifact.** `ftb.ca.gov` refused WebFetch and answered plain `curl` instantly, and checking the real document caught a typo. Never settle for a third-party mirror before trying curl.

**Parallel isolation has one specific blind spot.** Batch 7 cleared a DC expressibility risk at household scope without noticing that per-source config is per-STATE, so the collision binds across the whole file. Only the whole-branch review could see it. That review also found Vermont unsatisfiable and Idaho and Arizona green-on-wrong-law.

---

## 6. Where the six promises stand

| # | Promised | Status |
|---|---|---|
| 1 | Kansas personal exemption | **Phase 5**, pinned to the cent as Steve's own named scenario |
| 2 | Iowa exclusion incl. Roth conversions | **Phase 5**, pinned in six cases including the 55-58 age band |
| 3 | Per-state detail view | **Phase 6** |
| 4 | RMD summary leads with whoever starts first | done, on `main`, unreleased |
| 5 | RMD chart separates the two people | done, same merge |
| 6 | Caret fix (owed to Alan since 07-19) | on `main`, unshipped, scope now decided as all nine screens |

Nothing has shipped. `main` is well ahead of released 2.3.0.

---

## Next steps

1. **Send Theresa's reply** (drafted above, unsent).
2. **Answer Steve on the Tax Summary point** (analysis done, no draft written yet).
3. **Decide whether stale rates jump the queue in Phase 5.** UT, NM and GA hit every filer in those states. This is new information since the plan was approved.
4. **Phase 5**, opening with the two-model confirmation protocol run against Phase 4's catalogue rather than against the audit memo.
5. Consider whether the LinkedIn link line needs the descriptive lead-in restored.

**Housekeeping:** five `phase4-b*` worktrees and their branches are merged and removable. `feature/state-tax-phase3b` was never pushed to origin.
