# Task 8 report: close Phase 5a

## Status: DONE

## Headline counts, verified independently

```
defect cases remaining: 99 across 32 jurisdictions   (Phase 4 closed at 118 across 35)
baseline values moved: 75 across 4 jurisdictions      (GA 19, IA 18, NM 19, UT 19)
```

Parsed directly from the shipped fixtures and movement ledger on the merged branch (996104a),
not copied from any prior report. Matches the brief's stated figures exactly.

Fully corrected: Iowa (0/6), Georgia (0/5), Indiana (0/4).
Partially corrected: Kansas (3/6 remain, waits on `perSourceExemptions`), New Mexico (2/4
remain, waits on an age-65 income-graduated PIT-ADJ exemption field), Utah (4/5 remain, waits on
any credit representation at all).

## The two promises

**Iowa: fully corrected.** A 60-year-old Iowan converting $200,000 now owes what Iowa actually
charges instead of ~$7,600 of invented state tax.

**Kansas: NOT fully corrected.** Steve Nicolai's own scenario is fixed to the cent ($2,171.52 to
$1,218.88). Kansas's second defect stands: KPERS/federal/military/Railroad Retirement pensions
should be fully exempt while private pensions stay taxable, and the app still over-taxes a
Kansas filer holding a KPERS pension. Do not describe Kansas as fixed without that qualification.

## Full suite

```
xcodebuild test -project .../state-tax-phase5/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS'
Test run with 1857 tests in 293 suites passed after 316.432 seconds.
** TEST SUCCEEDED **
```

`xcresulttool get test-results summary`: `"result":"Passed"`, `"failedTests":0`,
`"skippedTests":6` (pre-existing env-gated). 1,857 Swift Testing + 509 XCTest = 2,366 total.
`MultiYearPerfTests` did not flake in this run; nothing to isolate.

## Production diff confinement

```
git diff --stat main -- RetireSmartIRA/
```
Six files under `Resources/StateTaxData/2026/` (GA, IA, IN, KS, NM, UT) plus
`RetireSmartIRA/StateTaxData.swift`. Read the full `StateTaxData.swift` diff directly: all 21
added lines are `///` doc comments above `configs2026Legacy`, zero braces, zero code, zero data.
No Swift logic and no data moved anywhere in this phase; every tax-value correction is confined
to the six JSON files.

## Ledger

Written to `.claude/memory/roadmap/2026-08-04-state-tax-phase5a-ledger.md`. Carries: every
correction with its authority; the exact missing model field each partial correction waits on
(Kansas: perSourceExemptions; New Mexico: income-graduated age-65 exemption; Utah: any credit
representation); the two promises stated plainly; the Iowa withheld-portion open item ($1,520.00
vs $2,356.00, $836 swing, dollar-consequential because this app has a Roth conversion
withholding feature); the movement-ledger mechanism and how Phase 5b extends it, including the
structural reason Kansas/Indiana show zero baseline movements; the legacy-table freeze decision,
its residual risk, and the precise distinction between `phase5CorrectedJurisdictions` (6 states)
and `layerAProvenDivergentJurisdictions` (4 states, and why Kansas/Indiana are correctly absent
from the second); what Phase 5b inherits organized by missing model field; and method findings
(seven subagent-caught brief errors, the NM partial-quote fixture gap, Georgia's three
zero-crossing tests).

## Em dash check

Verified via Python character count (`content.count('—')`) on the ledger file: 0.

## Commit

`0bb9685` on `feature/state-tax-phase5`, one file
(`.claude/memory/roadmap/2026-08-04-state-tax-phase5a-ledger.md`), added and committed by
explicit path, no `git add -A`.
