//
//  SeniorBonusDeductionTests.swift
//  RetireSmartIRATests
//
//  Verifies `DataManager.seniorBonusDeductionAmount` surfaces the engine-
//  computed OBBBA senior bonus (already embedded inside
//  `standardDeductionAmount`). Mirrors that math so the UI can display the
//  bonus as a named line. (H4 — 1.8.2 Phase 3)
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("OBBBA Senior Bonus Deduction — named accessor", .serialized)
@MainActor
struct SeniorBonusDeductionTests {

    /// Configure `dm` so `currentAge` returns `your` and (optionally)
    /// `spouseCurrentAge` returns `spouse`. Matches the pattern used in
    /// IRMAAInlineWarningPreMedicareTests.
    private func setAges(_ dm: DataManager, your: Int, spouse: Int? = nil, year: Int = 2026) {
        dm.currentYear = year
        var c = DateComponents()
        c.year = year - your
        c.month = 6
        c.day = 1
        dm.birthDate = Calendar.current.date(from: c)!
        if let spouse {
            var sc = DateComponents()
            sc.year = year - spouse
            sc.month = 6
            sc.day = 1
            dm.spouseBirthDate = Calendar.current.date(from: sc)!
        }
    }

    @Test("MFJ both 65+ below phaseout → full $12K bonus")
    func fullBonusBelowPhaseoutMFJBoth65() {
        let dm = DataManager(skipPersistence: true)
        setAges(dm, your: 67, spouse: 66)
        dm.filingStatus = .marriedFilingJointly
        dm.enableSpouse = true
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 140_000)
        ]
        #expect(abs(dm.seniorBonusDeductionAmount - 12_000) < 1)
    }

    @Test("MFJ both 65+ MAGI $170K → phased to $9,600")
    func phasesOutAboveMAGI150KMFJ() {
        let dm = DataManager(skipPersistence: true)
        setAges(dm, your: 67, spouse: 66)
        dm.filingStatus = .marriedFilingJointly
        dm.enableSpouse = true
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 170_000)
        ]
        // Per IRC § 151(d)(5)(B), phaseout is per qualifying individual:
        // MFJ both 65+, MAGI $170K
        // Per-person reduction = (170K - 150K) × 0.06 = $1,200
        // Per-person bonus = max(0, 6_000 - 1_200) = $4,800
        // Total = $4,800 × 2 = $9,600
        #expect(abs(dm.seniorBonusDeductionAmount - 9_600) < 1)
    }

    @Test("MFJ both 65+ MAGI $220K → per-person discriminator ($3,600 not $7,800)")
    func mfjDeepPhaseoutDiscriminatesPerPersonVsCombined() {
        let dm = DataManager(skipPersistence: true)
        setAges(dm, your: 67, spouse: 66)
        dm.filingStatus = .marriedFilingJointly
        dm.enableSpouse = true
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 220_000)
        ]
        // MFJ both 65+, MAGI $220K (deep in phaseout)
        // Per-person reduction = (220K - 150K) × 0.06 = $4,200
        // Per-person bonus = max(0, 6_000 - 4_200) = $1,800
        // Total = $1,800 × 2 = $3,600
        // (Combined-base Option A would give $7,800 — this test discriminates.)
        #expect(abs(dm.seniorBonusDeductionAmount - 3_600) < 1)
    }

    @Test("Single under 65 → zero")
    func zeroWhenUnder65() {
        let dm = DataManager(skipPersistence: true)
        setAges(dm, your: 60)
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "Wages", type: .consulting, annualAmount: 50_000)
        ]
        #expect(dm.seniorBonusDeductionAmount == 0)
    }

    @Test("After 2028 (TY 2029) → zero")
    func zeroAfter2028() {
        let dm = DataManager(skipPersistence: true)
        setAges(dm, your: 70, year: 2029)
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 40_000)
        ]
        #expect(dm.seniorBonusDeductionAmount == 0)
    }

    @Test("Single age 70 MAGI $200K → fully phased out")
    func fullyPhasedOutAtHighMAGISingle() {
        let dm = DataManager(skipPersistence: true)
        setAges(dm, your: 70)
        dm.filingStatus = .single
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 200_000)
        ]
        // reduction = (200K - 75K) * 0.06 = 7_500; bonus = max(0, 6_000 - 7_500) = 0
        #expect(dm.seniorBonusDeductionAmount == 0)
    }
}
