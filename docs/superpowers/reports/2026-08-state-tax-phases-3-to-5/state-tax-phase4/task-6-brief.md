# Task 6 brief


---

Assembled from the plan's global constraints, four-case matrix, fixture shape invariant, shared batch procedure, and this task's own notes. All of it binds you.


---

## Global Constraints

- **Spec:** `docs/superpowers/specs/2026-08-02-state-tax-verification-and-maintenance-design.md`. §3.4 governs fixture shape and citation discipline; §4a defines this phase's gate.
- **Phase 4 corrects NO tax value.** Not one line of `StateTaxData.swift`, `TaxCalculationEngine.swift` or any `Resources/StateTaxData/2026/*.json` changes in this phase. Every correction is Phase 5. A task that "fixes" a state has failed.
- **`expectedStateTax` MUST be derived from the state's own published form, instructions or worked example.** Never from this app's output. A fixture whose expected value came from the engine proves only that the engine agrees with itself.
- **Citation discipline (§3.4, the PROCESS control this phase carries):** every fixture carries `source` and a resolvable https `sourceURL`. **The fixture author, and the reviewer, must each state in their report that they personally opened every `sourceURL` and checked every clause of `source` against it.** Not "a citation is present". Not "the URL resolves". Every clause, against the page. This exists because three fixtures in Phase 2 had confidently wrong citations whose expected VALUES were correct, so every test passed.
- **Admissible sources:** state DOR pages, statutes, enrolled bills, official form instructions. Advisor blogs, tax-prep vendor help pages and news articles are inadmissible as sole basis. Any claimed 2024-2026 change must state the bill number and its final disposition (signed, vetoed, died). This is the check that catches the Colorado class of error, where a syndicated guide reported a bill that was Postponed Indefinitely on 2025-02-27 as enacted law.
- **`CANNOT_VERIFY` is a legitimate outcome.** If a state's rule cannot be established from a primary source, record the jurisdiction as unverified per §3.4 rather than guessing. The failure mode is confident fabrication, not silence.
- **No em dashes** in any file, per user preference. This has been a recurring review finding; a report claiming there are none when there are is treated as the worse half of the defect.
- **Suite is the source of truth** (CLAUDE.md). Baseline at branch point, MEASURED on this branch 2026-08-04: 1,845 Swift Testing in 290 suites + 509 XCTest, 0 failures. (The 1,752 + 505 figure in the Phase 3b ledger was measured on the phase3b branch tip, BEFORE the RMD spouse attribution work merged; that work added five test files and 1,835 lines, which accounts for the whole difference. Do not cite the Phase 3b number as this branch's baseline.)
- **Never edit files by chained `cd`.** Bash cwd resets between calls. Use absolute paths and `git -C`. This bit the previous phase four times, once committing a ledger to the wrong branch.

**Worktree:** `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4`, branch `feature/state-tax-phase4`, off `main` @ `6097430`.

**Build command (always pass `-project` explicitly, per the build trap in the 2026-08-04 session note):**

```bash
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tail -40
```

---

## The four-case matrix (§3.4)

Every jurisdiction gets **at least four** scenarios:

1. **Single filer BELOW any age threshold** the state applies.
2. **Single filer ABOVE it.**
3. **MFJ, both spouses qualifying.**
4. **MFJ, only one spouse qualifying.**

Case 4 is the one that matters most and the one a lazy fixture set omits. It is what would have caught Iowa's per-qualifying-spouse rule against the engine's household-wide `||` at `TaxCalculationEngine.swift:570`, and the systematic under-crediting of married couples across the six Tier 3 states.

**States with an AGI phase-out get a fifth case above the threshold**, because for those the Roth conversion is precisely what destroys the exemption, and that interaction is the one most likely to be modeled wrongly.

**At least one fifth case must be MFJ with income BETWEEN `thresholdSingle` and `thresholdMFJ`.** Virginia is the designated carrier ($50,000 single against $75,000 married): an MFJ filer at $60,000 keeps the full $12,000 under the correct flag and drops to $2,000 under a mutant that hardcodes `isMarried: false`. Only the band between the two thresholds distinguishes them, so a scenario outside it proves nothing. Assigned explicitly in Task 6.

**If a state genuinely has no age threshold and no phase-out** (most no-tax states, and the no-exclusion states), cases 1 and 2 collapse. Write the four cases anyway, varying income instead of age, so the matrix stays uniform and a later phase that adds an age gate has a case waiting. Say so in the fixture `name`.

---

## The fixture shape invariant, and why it is load-bearing

`federalAGI` MUST equal `pensionIncome + iraWithdrawals + rothConversion + taxableSocialSecurity + otherOrdinaryIncome` (with `classifiedPensionSources` amounts summed in place of `pensionIncome` when present).

This is not a style rule. The single-year runner reads `federalAGI` directly, but the multi-year runner **derives its own AGI from the income components and never reads `federalAGI` at all** (`ProjectionEngine.swift:680-690`). A Phase 2 fixture set `federalAGI` to $95,000 while pension was $80,000, and that $15,000 mismatch moved the single-year figure by $210 while the multi-year figure could not move at all. It read as an engine divergence and was a **fixture authoring artifact**. Task 2 makes that unrepresentable by asserting it across every fixture.

**`otherOrdinaryIncome` exists because the excess is sometimes legitimate, and must then be DECLARED rather than implied.** New York's first fixture is the precedent: `federalAGI` is $90,000 against a $70,000 classified pension, and the remaining $20,000 is deliberate unrelated ordinary income, described in that fixture's own `source` string and in no machine-readable field. A bare equality check would fail a correct fixture; a bare `>=` check would let the Phase 2 artifact back in. Declaring the excess keeps the check exact and moves the intent out of prose.

**`otherOrdinaryIncome` is DECLARATIVE ONLY.** It is never added to anything and never passed to any engine. `federalAGI` remains the single number the single-year runner hands the engine. An implementer who "wires it up" changes New York's shipped fixture values and has broken the phase's no-behavior-change rule.

**A fixture with nonzero `otherOrdinaryIncome` can never join `GoldenScenarioCrossPathTests.agreeing`,** because the multi-year runner is structurally blind to that income. Record that alongside the field so Phase 5d does not have to rediscover it.

---

### Tasks 3 through 9: The fixture batches

**Every batch task follows the identical procedure below.** It is written once here rather than repeated seven times; the per-batch sections that follow carry only what differs (the jurisdictions, the expectation, and the batch-specific traps).

**Files, for a batch covering jurisdictions X, Y, Z:**
- Create: `RetireSmartIRATests/GoldenScenarios/statetax-2026-X.golden.json` (one per jurisdiction)
- Modify: `RetireSmartIRATests/GoldenScenarioCoverageTests.swift:covered` (append the batch's abbreviations)
- Test: the existing suites, which pick the new fixtures up automatically through `covered`

**Procedure:**

- [ ] **Step 1: Research each jurisdiction from primary sources.** For each state in the batch, find its 2026 (or latest published) form instructions, DOR retirement-income guidance, or statute. Establish: bracket schedule, standard deduction, personal exemption, retirement-income exemption with its amount, age threshold, per-person versus household attribution, any AGI phase-out, and Social Security treatment. Record the URL you actually opened.

- [ ] **Step 2: Read the app's current config** at `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-<XX>.json` so you know what the engine will do. Do NOT let it influence `expectedStateTax`. You are reading it to predict whether this fixture will need a `knownDefect` block, not to derive an answer.

> **CARRIED FORWARD FROM THE TASK 3 REVIEW (2026-08-04): do not reuse one income template across a batch.** Task 3 wrote all eight jurisdictions against an identical set of four incomes ($40k pension; $120k; $90k MFJ; $150k MFJ), with the same ages throughout. That was defensible there, because no-tax states have no threshold for a case to sit either side of, and the batch's only job was proving the harness scales. **It stops being defensible from Task 4 onward.** Every state from here has brackets, deductions, thresholds or age gates, and a case that does not straddle one of them proves nothing about that state. Choose each state's four incomes from that state's own thresholds. If two states happen to share a figure, that should be because their statutes do, not because the file was copied.
>
> **The same review found the defect this phase is built to catch, so treat the citation step as the real work.** Wyoming's `source` cited "Slide 4" for text that sits on Slide 5 of the very PDF it links. The URL was right, the document was right, the quoted words were right, and a reader following the citation would still have found nothing supporting it. Naming a document is not citing it. Name the exact location and check that location.

- [ ] **Step 3: Derive the four cases BY HAND from the form.** Show the arithmetic in the fixture's `source` string: which lines, which subtraction, which bracket. A reader must be able to re-derive your number from your citation without running the app. Honor the shape invariant: `federalAGI` equals the sum of its components.

- [ ] **Step 4: Write the fixture file** with no `knownDefect` blocks yet.

- [ ] **Step 5: Append the batch's abbreviations to `GoldenScenarioCoverageTests.covered`.**

- [ ] **Step 6: Run and observe.**

```bash
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/GoldenScenarioSingleYearTests 2>&1 | tail -60
```

Each failure message prints both the engine figure and the form figure.

- [ ] **Step 7: For each failure, decide which side is wrong.**

This is the judgment the whole phase turns on, and it has two outcomes, not one:

  - **The engine is wrong** → add a `knownDefect` block with the MEASURED `observedToday` (copy it from the failure message, never predict it), the tier, and a one-sentence mechanism. This is a Phase 4 deliverable.
  - **The fixture is wrong** → fix the fixture. A misread form is the more likely explanation for a state the audit listed as CORRECT, and the less likely one for a state it listed as defective. Weight your prior accordingly, but verify either way rather than assuming the audit was right. The audit is single-source and says so.

  If you cannot tell which side is wrong from primary sources, mark the jurisdiction `CANNOT_VERIFY` in the ledger and leave the fixture out of `covered` rather than guessing. An unverified jurisdiction is a legitimate end state per §3.4; a fabricated one is not.

- [ ] **Step 8: Re-run until the batch is green** (every case either matches its form or carries a pinned defect).

- [ ] **Step 9: Run the FULL suite** to confirm nothing else moved.

- [ ] **Step 10: Report, with the citation attestation.** The report MUST state, in these terms: *"I personally opened every sourceURL in this batch and checked every clause of each `source` string against the page."* If that is not true, say what you actually did instead. A false attestation in a phase whose method is evidence before assertion is worse than the defect it hides.

- [ ] **Step 11: Commit** the batch as one commit.

```bash
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 add RetireSmartIRATests/GoldenScenarios/ RetireSmartIRATests/GoldenScenarioCoverageTests.swift
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 commit -m "test(state-tax): golden scenarios for <batch name>"
```

Stage explicit paths. Never `git add -A`: it raced a reviewer's in-flight mutation in the previous phase and committed a temporary revert.

---

---

### Task 6: Tier 1, wrong values

**Jurisdictions:** IA, MI, CT, VA, WI, AL, RI, ME, MT, MD, 10 fixtures.

**Expectation: failures, and they are the deliverable.** Every one of these is a wrong number or a missing gate that the existing model shape can already carry.

**Batch-specific notes:**

- **Iowa is the highest-value fixture in the entire phase.** Iowa excludes retirement income from 55+ including **Roth conversion income by name**, no cap, no income limit. The app has `.none`/`.none`. For a Roth conversion planning tool this invents state tax on the exact transaction the product exists to optimize, roughly $7,600 on a $200,000 conversion at 3.8%. Write a case that carries a large `rothConversion` explicitly; the four-case matrix alone would not exercise it. Iowa needs **five or six** cases: the standard four plus a conversion case, plus the 55-to-58 age band that the hardcoded 59½ gate at `TaxCalculationEngine.swift:570` will fail independently of the config.
- **Iowa also carries the `||` attribution defect.** `TaxCalculationEngine.swift:570` grants the household the exemption when EITHER spouse is 59+; Iowa's exclusion is explicitly per-qualifying-spouse. Matrix case 4 (MFJ, only one qualifying) is what exposes it. Make sure the qualifying spouse is the one whose income is NOT being tested, so the household-wide grant is visible.
- **VIRGINIA IS THE DESIGNATED CARRIER OF THE BETWEEN-THRESHOLDS CASE**, per §3.4 and the Phase 3a Task 4 review. Write an MFJ case at **$60,000**, between VA's $50,000 single and $75,000 married thresholds. Under the correct `isMarried` flag the filer keeps the full $12,000; under a mutant that hardcodes `isMarried: false` it drops to $2,000. This case is REQUIRED and its absence fails the phase, because the entire Phase 3a suite stays green under that mutation (every engine test there is single-only). Say in the fixture `name` that it is the between-thresholds carrier so a later reader does not "simplify" it away.
- **Michigan, Connecticut and Virginia are the dangerous three.** All three OVERSTATE the exemption, which pushes users toward converting more than they should. A too-generous number costs real money; a too-stingy one costs only opportunity. Their `knownDefect` summaries should say "overstates" explicitly so Phase 5 can prioritize by error direction.
- **Connecticut and Virginia share the conversion-destroys-the-exemption failure mode**, so both need the fifth AGI-phase-out case. CT: 100% exempt under $75k single / $100k MFJ, phasing out to $100k/$150k. VA: $12,000 at 65+, reduced $1 per $1 of AFAGI over $50k/$75k.
- **Montana:** the old deduction was repealed for TY 2025 and replaced with roughly $5,500 indexed. The app has `.partial(4_640)` plus a stale TODO. Establish the actual 2026 indexed figure from the DOR, and if it is not published yet, say so and mark `CANNOT_VERIFY` rather than interpolating.
- Wisconsin ($24,000 per person at 67+, 2025 Act 15), Alabama (DB fully exempt, DC $6,000/person at 65+), Rhode Island ($20,000/person at SS full retirement age, AGI-limited), Maine ($48,216 indexed, plus a new phase-out, against the app's $25,000), Maryland ($40,600 for 2026 against the app's $41,200).
- **Alabama's rule is per-source in disguise:** defined-benefit pensions fully exempt, defined-contribution capped. That is expressible only through the Phase 3b `PlanStructure` axis. Use `classifiedPensionSources` for Alabama's cases and note in `source` that the structure axis is what the rule keys on.

---
