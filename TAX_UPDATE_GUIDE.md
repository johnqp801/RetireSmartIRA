# Annual Tax Year Update Guide

This guide documents how to update RetireSmartIRA for a new tax year. All year-dependent tax constants live in a single JSON file, so annual updates require **only a new JSON file** (e.g., `tax-2027.json`) plus test verification.

## Quick Start

1. Copy `RetireSmartIRA/tax-2026.json` to `RetireSmartIRA/tax-YYYY.json`
2. Update all values in the new file using the IRS sources listed below
3. Build and run tests: all 557+ tests should pass
4. The app automatically loads the correct config based on the user's `currentYear`

## JSON Field Reference

### Federal Income Tax Brackets
| Field | Source | Typical Release |
|---|---|---|
| `federalBracketsSingle` | IRS Revenue Procedure (e.g., Rev. Proc. 2025-32) | October-November |
| `federalBracketsMFJ` | Same Rev. Proc. | October-November |
| `federalCapGainsBracketsSingle` | Same Rev. Proc. | October-November |
| `federalCapGainsBracketsMFJ` | Same Rev. Proc. | October-November |

### Standard Deduction
| Field | Source | Notes |
|---|---|---|
| `standardDeductionSingle` | IRS Revenue Procedure | Annual inflation adjustment |
| `standardDeductionMFJ` | IRS Revenue Procedure | Annual inflation adjustment |
| `additionalDeduction65Single` | IRS Revenue Procedure | Age 65+ additional |
| `additionalDeduction65MFJ` | IRS Revenue Procedure | Age 65+ per person |

### OBBBA Senior Bonus (2025-2028)
| Field | Source | Notes |
|---|---|---|
| `seniorBonusPerPerson` | One Big Beautiful Bill Act (OBBBA), signed July 4, 2025 | $6,000; fixed for 2025-2028 |
| `seniorBonusPhaseoutSingle` | OBBBA | $75,000 MAGI threshold |
| `seniorBonusPhaseoutMFJ` | OBBBA | $150,000 MAGI threshold |
| `seniorBonusPhaseoutRate` | OBBBA | 6% of excess MAGI |
| `seniorBonusFirstYear` | OBBBA | 2025 |
| `seniorBonusLastYear` | OBBBA | 2028 |

### SALT Cap (OBBBA 2025-2029)
| Field | Source | Notes |
|---|---|---|
| `saltBaseCap` | OBBBA | $40,000 base in 2025 |
| `saltInflationRate` | OBBBA | 1% annual adjustment |
| `saltBaseYear` | OBBBA | 2025 (year inflation starts from) |
| `saltPhaseoutBaseThreshold` | OBBBA | $500,000 MAGI (also inflation-adjusted) |
| `saltPhaseoutRate` | OBBBA | 30% reduction of excess MAGI |
| `saltFloor` | OBBBA | $10,000 minimum |
| `saltExpandedFirstYear` / `saltExpandedLastYear` | OBBBA | 2025-2029 |
| `saltDefaultCap` | TCJA / post-2029 reversion | $10,000 |

### AMT (Alternative Minimum Tax)
| Field | Source | Typical Release |
|---|---|---|
| `amtExemptionSingle` / `amtExemptionMFJ` | IRS Revenue Procedure | October-November |
| `amtPhaseoutThresholdSingle` / `amtPhaseoutThresholdMFJ` | IRS Revenue Procedure | October-November |
| `amtPhaseoutRate` | IRC Section 55 | Fixed at 0.50 (25% rate applies) |
| `amt26PercentLimit` | IRS Revenue Procedure | October-November |
| `amtRate26` / `amtRate28` | IRC Section 55 | Fixed at 0.26 / 0.28 |

### IRMAA (Medicare Income-Related Monthly Adjustment)
| Field | Source | Typical Release |
|---|---|---|
| `irmaaStandardPartB` | CMS Medicare Premiums announcement | November |
| `irmaaTiers[].singleThreshold` / `mfjThreshold` | CMS / SSA | November |
| `irmaaTiers[].partBMonthly` / `partDMonthly` | CMS Medicare Premiums | November |

IRMAA uses income from **2 years prior** (e.g., 2027 premiums based on 2025 MAGI). The thresholds are inflation-adjusted annually by CMS.

### NIIT (Net Investment Income Tax)
| Field | Source | Notes |
|---|---|---|
| `niitRate` | IRC Section 1411 | Fixed at 3.8% |
| `niitThresholdSingle` / `niitThresholdMFJ` | IRC Section 1411 | NOT inflation-adjusted ($200K/$250K) |

### Social Security Taxation Thresholds
| Field | Source | Notes |
|---|---|---|
| `ssTaxationThreshold1Single` / `ssTaxationThreshold2Single` | IRC Section 86 | NOT inflation-adjusted ($25K/$34K since 1984) |
| `ssTaxationThreshold1MFJ` / `ssTaxationThreshold2MFJ` | IRC Section 86 | NOT inflation-adjusted ($32K/$44K since 1984) |

These thresholds have **never been adjusted for inflation** since 1984. They remain constant unless Congress acts.

### QCD (Qualified Charitable Distribution)
| Field | Source | Typical Release |
|---|---|---|
| `qcdAnnualLimit` | IRS Notice (e.g., Notice 2025-67) | Late in prior year |

SECURE 2.0 Act requires annual inflation adjustment starting 2024.

### California Exemption Credits
| Field | Source | Notes |
|---|---|---|
| `caExemptionCreditPerPerson` | CA FTB | $144 (rarely changes) |
| `caExemptionPhaseoutSingle` / `caExemptionPhaseoutMFJ` | CA FTB | Annual inflation adjustment |
| `caExemptionPhaseoutReductionPer2500` | CA FTB | $6 per $2,500 excess |

### Medical Deduction
| Field | Source | Notes |
|---|---|---|
| `medicalAGIFloorRate` | IRC Section 213 | 7.5% (made permanent by TCJA) |

## Where to Find Updates

### IRS (Federal)
- **Revenue Procedures**: Search "IRS Revenue Procedure [year]" — typically Rev. Proc. 20XX-YY released in October/November for the following tax year
- **IRS Newsroom**: https://www.irs.gov/newsroom — announces inflation adjustments
- **Key search**: "IRS inflation adjustments [year]"

### CMS / SSA (Medicare/IRMAA)
- **CMS Medicare Premiums**: Search "CMS Medicare Part B premiums [year]" — announced in November
- **SSA IRMAA**: https://www.ssa.gov/medicare — IRMAA bracket thresholds

### California FTB (State)
- **CA FTB Tax Rates**: Search "California FTB tax rates schedules [year]"
- Exemption credit amounts and phaseout thresholds updated annually

### State Tax Data
State brackets and exemptions are in `StateTaxData.swift`, not in the JSON config. These change less frequently but should be checked annually. Each state's department of revenue publishes updated brackets.

## Values That Rarely Change

These are included in the JSON for completeness but are unlikely to change without new legislation:
- `niitRate` (3.8%) — fixed by statute
- `niitThresholdSingle` / `niitThresholdMFJ` — not inflation-indexed
- `ssTaxationThreshold1Single/MFJ` / `ssTaxationThreshold2Single/MFJ` — not inflation-indexed since 1984
- `amtPhaseoutRate` (0.50) — fixed by statute
- `amtRate26` / `amtRate28` — fixed by statute
- `medicalAGIFloorRate` (0.075) — made permanent at 7.5% by TCJA

## Architecture Notes

- `TaxYearConfig.swift` defines the JSON schema (`Codable` struct)
- `TaxCalculationEngine.swift` loads config at startup and exposes values via computed properties
- `ProfileManager.swift` triggers `TaxCalculationEngine.loadConfig(forYear:)` when `currentYear` changes
- `TaxYearConfig.loadOrFallback(forYear:)` walks backward from the requested year to find the most recent available config, so the app never crashes if a future year's JSON is missing
- The Xcode project uses `PBXFileSystemSynchronizedRootGroup` — just drop the new JSON file in the `RetireSmartIRA/` directory and it's automatically included as a bundle resource
