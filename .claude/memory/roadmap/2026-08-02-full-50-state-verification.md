# Full 51-jurisdiction state retirement-exemption verification, 2026-08-02

Supersedes the partial spot-check earlier today (`2026-08-02-state-retirement-exemption-audit.md`), which stands as the narrative of how this started.

**Scope:** all 50 states + DC. 42 explicit configs in `StateTaxData.swift`, plus 7 no-income-tax states from the loop at line 475, plus NH and WA as `.specialLimited`.

**Result: roughly 29 of 51 jurisdictions have at least one defect.** Not all are material, and they sort into five distinct kinds of problem, only one of which is "wrong number in a table."

**Status of this document: SINGLE-SOURCE, NOT YET CONFIRMED.** Nothing here should reach `StateTaxData.swift` until it clears the two-model confirmation described in §7. See the Colorado entry in §5 for why.

---

## 1. The one that reorders everything

**Iowa exempts Roth conversion income by name.** Iowa DOR's retirement-income guidance lists "Roth conversion income" in the excluded category for anyone 55+, disabled, or a surviving spouse, with no income limit and no dollar cap.

This is a Roth conversion planning tool. For an Iowa user it currently invents state tax on the single transaction the whole app exists to optimize, at 3.8%. A $200,000 conversion shows roughly $7,600 of tax that does not exist, and the optimizer will systematically recommend converting less than it should.

Fixing it takes three edits, not one:

1. **Config** (`StateTaxData.swift:646`): `.full` / `.full`, `regularExemptionMinAge: 55`. The comment on line 652 claiming Iowa "phased out retirement exclusion with flat tax" is factually backwards and should go.
2. **The hardcoded 59½ gate** (`TaxCalculationEngine.swift:570`): `retirementAge = primaryAge >= 59 || (enableSpouse && spouseAge >= 59)`. Iowa qualifies at 55, so config alone still taxes a 55-to-58-year-old Iowan. `regularExemptionMinAge` exists but does not reach this line.
3. **The Roth-conversion `switch state`** (`TaxCalculationEngine.swift:672`): currently PA, IL, MS, all ungated. Iowa would be the first age-gated case.

That same line 570 uses `||`, so **either** spouse being 59+ unlocks the exemption for the whole household's distributions. Iowa's exclusion is explicitly per-qualifying-spouse. Worth its own test regardless of Iowa.

---

## 2. Tier 1 — material, expressible in today's model

Fix these first. Every one is a wrong number or a missing gate that the existing `RetirementIncomeExemptions` shape can already carry.

| State | App today | Verified 2026 rule | Error direction |
|---|---|---|---|
| **Iowa** | `.none` / `.none` | Full exemption at 55+, incl. Roth conversions, no cap | understates |
| **Michigan** | `.full` / `.full` (unlimited) | Capped **$67,610 single / $135,220 MFJ** (RAB 2026-1) | **overstates** |
| **Connecticut** | pension `.none`, IRA `.full` | Both 100%, but only under **$75k/$100k** AGI, phasing out to $100k/$150k | **both** |
| **Virginia** | `.partial(12_000)`, no age gate | $12,000 at **65+**, reduced **$1 per $1** of AFAGI over $50k single / $75k married | **overstates** |
| **Wisconsin** | `.none` / `.none` | **$24,000 per person at 67+** ($48k MFJ), no AGI limit (2025 Act 15) | understates |
| **Alabama** | `.none` / `.none` | DB pensions **fully exempt**; DC plans $6,000/person at 65+ | understates |
| **Rhode Island** | `.none` | **$20,000 per person** at SS full retirement age, AGI-limited | understates |
| **Maine** | `.partial(25_000)` | **$48,216** (TY 2025, indexed), plus a new AGI phase-out | understates |
| **Montana** | `.partial(4_640)` + TODO | Old deduction repealed TY 2025; replaced with **~$5,500** indexed | understates |
| **Maryland** | `.partial(41_200)` | **$40,600** for 2026 | overstates (small) |

Michigan, Connecticut and Virginia are the dangerous three. They all **overstate** the exemption, which pushes users toward converting more than they should. A too-generous number costs the user real money; a too-stingy one only costs them opportunity.

Connecticut and Virginia share a specific failure mode that this app should care about more than most: **the exemption is destroyed by the conversion itself.** A large Roth conversion is exactly what lifts AGI through CT's $100k/$150k phase-out and past VA's $75k threshold. The app models both as if the conversion has no effect on eligibility.

---

## 3. Tier 2 — the per-source wall

These cannot be fixed by editing a number. `RetirementIncomeExemptions` is **per-state**, and every one of these is a rule that depends on **which plan the money came from**.

| State | Rule the model cannot express |
|---|---|
| **Kansas** | KPERS, federal, military and Railroad Retirement fully exempt; private pensions / 401(k) / IRA fully taxable |
| **Massachusetts** | **Contributory** MA state and local pensions exempt; noncontributory municipal taxable; US uniformed services exempt |
| **Hawaii** | **Employer-funded** portion of a qualified pension exempt (no cap, no age); employee contributions, 401(k) deferrals and IRAs taxed |
| **New York** | Government pensions fully excluded (IT-201 line 26); the $20,000 line-29 cap is a separate track — **already logged, Alan's report** |
| **Arizona** | The $2,500 exclusion covers **government pensions only**. App applies it to all pensions → **overstates** |
| **North Carolina** | Bailey/Emory/Patton settlement class (vested before 1989-08-12) fully exempt |
| **Idaho** | Narrow deduction: CSRS, Idaho police/fire, military, 65+ (62 if disabled), income-limited |
| **Vermont** | $10,000 military/CSRS exclusion, AGI-limited ($55k single / $70k MFJ) |
| **DC** | $3,000 at 62+, DC or federal government pensions only |

**Kansas now has two independent defects** (this, plus the missing personal exemption Steve found on 08-01). That is worth knowing before replying to him.

This tier is the same design already scoped as **item 1c in the consolidated backlog** for Alan's NY pension and Steve's 403(b). It is now nine states, not two users. That materially changes its priority: it is not a courtesy fix for two testers, it is the second-largest category of state-tax error in the app.

---

## 4. Tier 3 — missing per-individual flags and age gates

Quiet, systematic, and all in the same direction: **the app under-credits married couples.** `exemptionAppliesPerIndividual` is set for only two states (GA, NY) but the underlying statutes are per-person in at least five more.

| State | Issue |
|---|---|
| **Oklahoma** | $10,000 is **per person** ($20k MFJ). Flag not set. |
| **Delaware** | $12,500 is **per person at 60+**. Neither the flag nor `regularExemptionMinAge: 60` is set. |
| **Louisiana** | $12,000 is at **65+**, per person. No age gate set. |
| **Arkansas** | $6,000 per taxpayer at 59½+. |
| **South Carolina** | Missing the separate **$15,000** age-65 deduction against any income (reduced by the retirement deduction claimed). |
| **West Virginia** | $8,000 senior modification at 65+, per person, reduced by other modifications. App has `.none`. |

---

## 5. Confirmed CORRECT — do not touch

Recording these matters as much as the defects, because two of them are traps.

- **Colorado** — $24,000 at 65+ / $20,000 at 55-64 **stands for 2026.** A widely-syndicated advisor guide states that SB25-136 removed all caps effective 2026-01-01. **The bill was Postponed Indefinitely on 2025-02-27 and is dead.** Acting on the secondary source would have introduced a bug into a correct state.
- **Oklahoma amount** — $10,000 stands. HB2190 ($40,000) is still in committee, not enacted.
- **Kentucky** — $31,110 stands. HB 146 ($41,100) proposed, not enacted.
- **Georgia** — $65,000 at 65+ / $35,000 at 62-64 correct for TY 2026. Rises to **$70,000 in TY 2027**; diary item.
  - **THIS BULLET IS NOW THE DURABLE HOME OF THE TY2027 FACT.** To be exact about what rises: the $70,000 is the RETIREMENT-INCOME EXCLUSION. Georgia's standard deduction is a separate figure, $15,000 single / $30,000 married, and does not change with it.
  - `statetax-2026-GA.json` carried a `verification.knownLimitations` sentence stating this, and that sentence was REMOVED from production on 2026-08-06. Four problems: it called the $70,000 a standard deduction; it said "this config" on a user-facing surface; it stated no over/under direction where every other sentence does; and it was tagged `pension`, so it rendered inside the pension editor under "What kind of pension is this?", which is the placement `LimitationTopic` exists to prevent. It predated the accuracy-disclosure branch, had NO production consumer until that branch built two readers for it, and was never among the thirteen sentences John approved.
  - Georgia now ships an EMPTY limitations list, alongside Iowa and Indiana. A replacement sentence, if one is wanted, is John's copy to approve; three PROPOSED drafts are in `.superpowers/sdd/whole-branch-fix-report.md`.
- **New Jersey** — stepped phaseout, correct.
- **New York** — $20,000 amount and the per-individual flag correct. Only the government-pension track is missing.
- **Illinois, Mississippi, Pennsylvania** — full exemption, correct.
- **Missouri** — substantively right for 2026, but the code comment cites **HB 798**; the operative bill is **HB 426**. Also the *public* pension exemption is capped at each individual's maximum Social Security benefit, which is not modeled.
- **California, Nebraska, North Dakota, Indiana, Oregon** — no retirement exclusion. Correct.
- **The seven no-tax states + New Hampshire** — correct. NH's interest/dividends tax was fully repealed effective 2025.

---

## 6. Tier 4 — structurally different, low priority for this audience

**Credits, not exclusions.** The model has no representation for these and `.none` is arguably the honest encoding. All are income-limited well below this app's typical user.

- **Ohio** — retirement income credit up to $200 + $50 senior credit, MAGI under $100,000
- **Utah** — up to $450 per person, full at ≤$54,000 single / $90,000 joint, cannot combine with the SS credit
- **New Mexico** — $8,000 at 65+, but AGI must be under $28,500 single / $51,000 MFJ

**Not a retirement exemption at all:**

- **Washington** — app sets `capitalGainsTreatment: .noStateTax` and the comment on line 503 says "7% on gains > $250K". WA actually levies **7% above the standard deduction (~$278,000 for 2025, 2026 TBD) and 9.9% above $1M** after SB 5813. The app's audience skews affluent enough that this will eventually be reported.

---

## 7. Two-model confirmation plan

Nothing in §§2-4 goes into the config on my say-so. The existing project pattern is right: **models flag, primary sources decide, tests hold the gate.**

### Why this is not optional here

Three concrete failures already happened during this audit, all from respectable-looking sources:

1. A syndicated advisor guide asserted **Colorado removed its caps**. The bill died in committee.
2. The same guide listed **Maine at $25,000**, the figure the app already has, when the real number is $48,216. A single-source check would have "confirmed" the bug.
3. That guide also claimed **New York gives no IRA exclusion**, which is wrong; the app is right.

A model asked to "verify state retirement exemptions" will happily reproduce all three. Consensus among models that read the same secondary sources is worth very little. The design has to force independent primary-source citation.

### Mechanics

**Packet.** Emit one JSON row per jurisdiction from `StateTaxConfig` itself, so the artifact cannot drift from what the engine actually does:

```
{ state, currentClaim: {ssExempt, pension, ira, minAge, perIndividual, capGains},
  proposedChange: {...} | null, myCitation: url, confidence, tier }
```

Write it to `RetireSmartIRATests/StateTaxAudit/packets/`, mirroring the display-audit harness convention.

**Prompt rubric, identical for both models, each run cold with no sight of the other:**

- Return a verdict per state: `CONFIRMS` / `CONTRADICTS` / `CANNOT_VERIFY`.
- **Every non-`CANNOT_VERIFY` verdict must carry a citation to a state DOR page, a statute, or an enrolled bill.** Advisor blogs, tax-prep vendor help pages and news articles are explicitly inadmissible as the sole basis.
- For any claimed 2024-2026 law change, **state the bill number and its final disposition** (signed / vetoed / died in committee). This is the check that catches the Colorado class of error.
- `CANNOT_VERIFY` is a valid and encouraged answer. Say so in the prompt, because the failure mode is confident fabrication, not silence.

**Calibration probes, seeded into the packet.** Include Colorado, Maine and New York as stated above. A model that says Colorado removed its caps, or that Maine is $25,000, or that NY has no IRA exclusion, has demonstrated it is reading secondary sources. **Score the model before scoring the states.** If a model fails two of three probes, discard its whole run rather than adjudicating it state by state.

**Consensus rule:**

- Both models `CONFIRMS` + a primary source in hand → accept, write the change with a dated stamp.
- Any `CONTRADICTS` → John adjudicates against the primary source. No automatic resolution.
- Both `CANNOT_VERIFY` → leave the config untouched and record the state as unverified. **Unverified is a legitimate end state.** It is what §8 surfaces to users.
- Never let agreement between two models substitute for a primary source. Two models agreeing on the same wrong blog is the exact failure this is designed to catch.

**The gate stays deterministic.** Every accepted change lands as a test in the existing state-tax suite with the statutory figure hardcoded. `StateRetirementExemptionTests.swift` is the natural home. The suite is what blocks a release, never a model verdict.

**Suggested models.** GPT-5 and Gemini 3 Pro, matching the Stage-2 harness plan. A third pass from Perplexity is worth it here specifically because it cites as it retrieves, which suits primary-source hunting. Treat it as a tiebreaker, not a third vote.

---

## 8. Steve's suggestion F, as a feature

> *"Communicate how accurate the state modeling is; per-state, per-income-type treatment text."*

He asked for this on 08-01 and then found a second state bug on 08-02. That sequence is the argument.

### The design idea worth having

**Generate the disclosure from `StateTaxConfig`, never hand-write it.** A prose accuracy page maintained separately from the engine will drift, and a drifted accuracy page is worse than none because it makes a false promise specifically to the users who went looking for the truth.

Add to `StateTaxConfig`:

```swift
struct StateVerification {
    let lastVerified: Date
    let primarySource: URL
    let billReference: String?
    let knownLimitations: [String]   // e.g. "Government pensions not distinguished from private"
}
```

Three things fall out of that, and the second is the real prize:

1. **A per-state "What we model" view.** Reads the live config: brackets, standard deduction, SS treatment, pension/IRA exemption with amounts and ages, local tax. Then `knownLimitations` verbatim.
2. **`knownLimitations` becomes the honest home for every Tier 2 item.** Hawaii, Massachusetts, Kansas, NC, NY, AZ, ID, VT, DC all get a plain sentence today, before the per-source engine work is done. That converts nine silent wrong answers into nine disclosed limitations, immediately, for the cost of writing sentences. **This is the highest value-per-hour item on the entire backlog.**
3. **A staleness signal.** `lastVerified` older than N months renders differently. The audit stops depending on anyone remembering to re-run it.

### Where it surfaces

Not buried in Settings. An info affordance next to the state tax line in results, opening the state's page. The user sees it at the moment the number matters, which is the only moment they can act on it.

### The forcing function

Make `StateVerification` non-optional. A new state config cannot compile without a verification date and a source URL. That is what stops this document from being needed again in a year.

Worth pairing with the site's existing `/accuracy` page so the app and the web make the same claim.

---

## 9. Sequencing

1. **Iowa, complete** — config + 59½ gate + Roth switch + tests. Reported bug, written commitment, and the one that most distorts the core recommendation.
2. **Michigan, Connecticut, Virginia** — the overstating three. Wrong in the direction that costs users money.
3. **Kansas personal exemption + I2**, already queued as backlog item 1. Now knowing Kansas has a public-pension gap too, decide whether to do both at once.
4. **`knownLimitations` + the per-state disclosure view.** Ship the honesty before the engine work. It covers all of Tier 2 at once and it is what Steve actually asked for.
5. **Tier 1 remainder** — WI, AL, RI, ME, MT, MD. Mechanical once the shapes exist.
6. **Tier 3** — per-individual flags and age gates. One structural pass, not eight patches.
7. **Per-source exemption design** — the Tier 2 engine work. Nine states, two named users.
8. **A general AGI-phaseout mechanism.** CT, VA, ME, RI, WV, NM all need it and only NJ has a bespoke one today. For a conversion tool this is arguably more important than any single state.

Do not run 1-2 before the §7 confirmation clears.

---

## Sources

Iowa: [DOR retirement income guidance](https://revenue.iowa.gov/taxes/tax-guidance/individual-income-tax/retirement-income-tax-guidance) · [HF 2317 enrolled](https://www.legis.iowa.gov/docs/publications/LGE/89/HF2317.pdf)
Michigan: [RAB 2026-1](https://www.michigan.gov/taxes/rep-legal/rab/2026-revenue-administrative-bulletins/revenue-administrative-bulletin-2026-1) · [Retirement and Pension Benefits](https://www.michigan.gov/taxes/iit/tax-guidance/tax-situations/retirement-and-pension-benefits)
Connecticut: [OLR 2024-R-0130](https://cga.ct.gov/2024/rpt/pdf/2024-R-0130.pdf)
Wisconsin: [LFB 2025-27 budget, Act 15 distribution](https://docs.legis.wisconsin.gov/misc/lfb/budget/2025_27_biennial_budget/509_estimated_distribution_of_individual_income_tax_reductions_in_motion_44_6_18_25)
Alabama: [DOR income exempt](https://www.revenue.alabama.gov/individual-corporate/income-exempt-from-alabama-income-taxation/) · [Act 2022-294 summary](https://alabamaretail.org/news/retirement-income-tax-cut/)
Rhode Island: [PUB 2026-01 Retirement Income Guide](https://tax.ri.gov/sites/g/files/xkgbur541/files/2026-02/PUB_2026-01_Retirement_Income_Guide.pdf)
Maine: [MainePERS pension income deduction](https://www.mainepers.org/retirement/benefit-payment-and-tax-information/important-information-about-the-maine-pension-income-deduction-and-your-mainepers-benefit/)
Colorado: [SB25-136 status, Postponed Indefinitely](https://leg.colorado.gov/bills/sb25-136) · [DOR retirees](https://tax.colorado.gov/retirees)
Massachusetts: [Tax treatment of government pensions](https://www.mass.gov/info-details/tax-treatment-of-government-pensions-in-massachusetts)
Kansas: [Schedule S Part A instructions](https://www.ksrevenue.gov/webfile/help/scheduleS_A.html) · [KPERS and taxes](https://www.kspers.gov/taxes)
Minnesota: [Qualified Public Pension Subtraction](https://www.revenue.state.mn.us/public-pension-subtraction)
Missouri: [DOR pension FAQs](https://dor.mo.gov/faq/taxation/individual/pension.html) · [HB 426](https://www.senate.mo.gov/25info/BTS_Web/Bill.aspx?SessionType=R&BillID=18266206)
Oklahoma: [OAC 710:50-15-49](https://www.law.cornell.edu/regulations/oklahoma/OAC-710-50-15-49) · [HB2190 status](https://legiscan.com/OK/bill/HB2190/2026)
Idaho: [Retirement Benefits Deduction](https://tax.idaho.gov/taxes/income-tax/individual-income/popular-credits-and-deductions/idaho-retirement-benefits-deduction/) · [Idaho Code 63-3022A](https://legislature.idaho.gov/statutesrules/idstat/title63/t63ch30/sect63-3022a/)
Vermont: [Seniors and retirees](https://tax.vermont.gov/individuals/seniors-and-retirees)
West Virginia: [Senior citizen SS modification](https://tax.wv.gov/Individuals/SeniorCitizens/Pages/SeniorCitizenSocialSecurityModification.aspx)
Ohio: [Retirement income credit](https://tax.ohio.gov/static/ohio_individual/individual/supportingdocumentation/pages/soc-2_retinc.html)
DC: [DC Code 47-1803.02](https://code.dccouncil.gov/us/dc/council/code/sections/47-1803.02)
Louisiana: [DOR retirement benefit exclusions](https://revenue.louisiana.gov/tax-education-and-faqs/faqs/individual-income-tax/is-there-a-list-of-retirement-system-benefits-that-may-be-excluded-from-louisiana-income-tax/)
Arkansas: [Subject 206, Pensions and Annuities](https://www.arkansas.gov/dfa/income_tax/documents/206-PensionsandAnnuities.pdf)
Washington: [DOR tiered capital gains rates](https://dor.wa.gov/forms-publications/publications-subject/special-notices/new-tiered-rates-washingtons-capital-gains-tax)
