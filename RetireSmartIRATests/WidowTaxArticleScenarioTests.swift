//
//  WidowTaxArticleScenarioTests.swift
//  RetireSmartIRATests
//
//  Pins the published figures in the "Widow Tax" article (Humble Dollar,
//  2026-07-25) and its expanded companion on retiresmartira.com
//  (/articles/widow-tax-by-the-numbers-2026).
//
//  WHY THIS FILE EXISTS
//  --------------------
//  These numbers appear under John's byline in a third-party publication. If an
//  engine change moves any of them, that is a correction the published article
//  needs, not a test to rebaseline. Treat a failure here as "go look at what
//  changed and decide whether the article is now wrong", never as "update the
//  expected value".
//
//  It also exists because the article's figures were, for a while, effectively
//  unverifiable. A note claimed a regression test pinned them; no such file
//  existed anywhere in the repo. When the figures were later re-checked from the
//  web draft alone, that draft described Household A only as "$360,000,
//  including about $70,000 of qualified dividends and long-term gains" and never
//  mentioned its $80,000 of Social Security. The check therefore modeled the
//  other $290,000 as pension, taxed every dollar of it, and came out $2,876 high
//  on the couple and $4,027 high on the survivor -- a false alarm that cost real
//  time and briefly looked like an engine bug. Only 85% of a benefit is taxable,
//  so $80,000 of Social Security keeps $12,000 permanently out of taxable
//  income; at a 24% marginal rate that IS the discrepancy. The full income
//  composition is written out below for every household so that can never
//  happen again.
//
//  ENGINE CHOICE: the single-year engine (DataManager), because each household is
//  a one-year snapshot comparing a couple against a survivor, not a projection.
//
//  Federal tax and Medicare IRMAA only; state tax excluded by using Florida.
//  Both spouses over 65. 2026 federal parameters.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Widow Tax article scenarios (published figures)", .serialized)
@MainActor
struct WidowTaxArticleScenarioTests {

    /// The published figures are stated to the dollar or to the nearest hundred
    /// ("~$53,900" against an actual $53,896). $10 absorbs that rounding while
    /// still catching any real regression, which would move these by hundreds.
    private let tolerance = 10.0

    private func household(
        _ filingStatus: FilingStatus,
        spouse: Bool,
        income: [(IncomeType, Double)]
    ) -> DataManager {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.filingStatus = filingStatus
        dm.selectedState = .florida          // no state income tax: isolates federal + IRMAA
        var dob = DateComponents(); dob.year = 1960; dob.month = 1; dob.day = 1
        dm.birthDate = Calendar.current.date(from: dob)!
        if spouse {
            dm.enableSpouse = true
            dm.spouseBirthDate = Calendar.current.date(from: dob)!
        } else {
            dm.enableSpouse = false
        }
        dm.iraAccounts = []
        dm.deductionItems = []               // standard deduction; no itemizing
        dm.deductionOverride = nil
        dm.yourRothConversion = 0; dm.spouseRothConversion = 0
        dm.yourExtraWithdrawal = 0; dm.spouseExtraWithdrawal = 0
        dm.yourQCDAmount = 0; dm.spouseQCDAmount = 0
        dm.stockDonationEnabled = false; dm.cashDonationAmount = 0
        dm.inheritedExtraWithdrawals = [:]
        dm.incomeSources = income.map {
            IncomeSource(name: $0.0.rawValue, type: $0.0, annualAmount: $0.1)
        }
        return dm
    }

    private func check(
        _ label: String,
        _ dm: DataManager,
        publishedFederalTax: Double,
        publishedIRMAA: Double
    ) {
        #expect(
            abs(dm.scenarioFederalTax - publishedFederalTax) < tolerance,
            "\(label): federal tax \(dm.scenarioFederalTax), article published \(publishedFederalTax)"
        )
        #expect(
            abs(dm.scenarioIRMAATotalSurcharge - publishedIRMAA) < tolerance,
            "\(label): IRMAA \(dm.scenarioIRMAATotalSurcharge), article published \(publishedIRMAA)"
        )
    }

    // MARK: - Household A: the $360,000 couple ("a widow discount")

    /// $80,000 Social Security + $210,000 pension/RMD + $30,000 qualified
    /// dividends + $40,000 long-term gains.
    private func householdACouple() -> DataManager {
        household(.marriedFilingJointly, spouse: true, income: [
            (.socialSecurity, 80_000),
            (.pension, 210_000),
            (.qualifiedDividends, 30_000),
            (.capitalGainsLong, 40_000),
        ])
    }

    /// Survivor keeps the larger Social Security check and most of the other
    /// income, landing at ~$308,000. The $52,000 loss is split as the smaller
    /// $32,000 benefit stopping plus a $20,000 pension reduction; the taxable
    /// brokerage income does not shrink because a spouse died, so the $70,000 of
    /// preferential income carries over intact. This split is a reconstruction
    /// (the article states only the $308,000 total) and it reproduces the
    /// published tax and IRMAA to within $4.
    private func householdASurvivor() -> DataManager {
        household(.single, spouse: false, income: [
            (.socialSecurity, 48_000),
            (.pension, 190_000),
            (.qualifiedDividends, 30_000),
            (.capitalGainsLong, 40_000),
        ])
    }

    @Test("A: couple pays ~$53,900 federal and ~$9,240 IRMAA")
    func householdACoupleFigures() {
        check("A couple", householdACouple(),
              publishedFederalTax: 53_896, publishedIRMAA: 9_240)
    }

    @Test("A: survivor pays ~$55,000 federal and ~$6,355 IRMAA")
    func householdASurvivorFigures() {
        check("A survivor", householdASurvivor(),
              publishedFederalTax: 55_004, publishedIRMAA: 6_355.20)
    }

    @Test("A: only 85% of the benefit is taxable, so AGI is $348,000 not $360,000")
    func householdANonTaxableBenefitPortion() {
        // The exact fact whose omission from the web draft caused a false alarm.
        // $80,000 of benefits, provisional income far above the second threshold,
        // so taxable benefits hit the 85% ceiling at $68,000 and $12,000 never
        // enters income.
        let dm = householdACouple()
        let taxableSS = dm.calculateTaxableSocialSecurity(filingStatus: .marriedFilingJointly)
        #expect(abs(taxableSS - 68_000) < 1.0, "taxable benefits \(taxableSS), expected 68,000")
        #expect(abs(dm.estimatedAGI - 348_000) < 1.0, "AGI \(dm.estimatedAGI), expected 348,000")
    }

    @Test("A: the survivor's combined tax and Medicare bill FALLS about $1,800")
    func householdAIsADiscount() {
        // The article's central counterintuitive claim: the rate rises, the
        // dollars fall, because two enrollees in the couple's tier cost more than
        // one survivor a tier higher.
        let couple = householdACouple()
        let survivor = householdASurvivor()
        let coupleBill = couple.scenarioFederalTax + couple.scenarioIRMAATotalSurcharge
        let survivorBill = survivor.scenarioFederalTax + survivor.scenarioIRMAATotalSurcharge
        let delta = survivorBill - coupleBill
        #expect(delta < 0, "must be a DISCOUNT; survivor paid \(delta) more")
        #expect(abs(delta - -1_800) < 100, "combined change \(delta), article published about -1,800")
        // And the surcharge specifically must fall, which is the mechanism.
        #expect(survivor.scenarioIRMAATotalSurcharge < couple.scenarioIRMAATotalSurcharge)
    }

    // MARK: - Household B: the $180,000 couple ("where it actually bites")

    /// $60,000 Social Security + $120,000 pension/RMD, all ordinary.
    private func householdBCouple() -> DataManager {
        household(.marriedFilingJointly, spouse: true, income: [
            (.socialSecurity, 60_000),
            (.pension, 120_000),
        ])
    }

    /// Survivor keeps the larger benefit and the full $120,000: the entire
    /// $30,000 loss is the smaller Social Security check stopping.
    private func householdBSurvivor() -> DataManager {
        household(.single, spouse: false, income: [
            (.socialSecurity, 30_000),
            (.pension, 120_000),
        ])
    }

    @Test("B: couple pays ~$17,148 federal and no IRMAA")
    func householdBCoupleFigures() {
        check("B couple", householdBCouple(),
              publishedFederalTax: 17_148.40, publishedIRMAA: 0)
    }

    @Test("B: survivor pays ~$22,737 federal and a new ~$2,885 IRMAA")
    func householdBSurvivorFigures() {
        check("B survivor", householdBSurvivor(),
              publishedFederalTax: 22_737.20, publishedIRMAA: 2_884.80)
    }

    @Test("B: the senior deduction collapsing is a named driver of the tax jump")
    func householdBSeniorDeductionCollapse() {
        // The article attributes "a surprising chunk" of the $5,600 tax rise to
        // the new senior deduction phasing out against the lower single
        // threshold. These two values are the ones the 2026-07-11 drafting notes
        // recorded, and they are the mechanism the sentence rests on.
        #expect(abs(householdBCouple().seniorBonusDeductionAmount - 9_480) < 1.0)
        #expect(abs(householdBSurvivor().seniorBonusDeductionAmount - 1_770) < 1.0)
    }

    @Test("B: widowhood costs about $8,500 a year")
    func householdBTotalCost() {
        let couple = householdBCouple()
        let survivor = householdBSurvivor()
        let delta = (survivor.scenarioFederalTax + survivor.scenarioIRMAATotalSurcharge)
            - (couple.scenarioFederalTax + couple.scenarioIRMAATotalSurcharge)
        #expect(abs(delta - 8_500) < 100, "combined change \(delta), article published about 8,500")
        // The surcharge appears from zero here; that is half the story.
        #expect(couple.scenarioIRMAATotalSurcharge == 0)
        #expect(survivor.scenarioIRMAATotalSurcharge > 0)
    }

    // MARK: - Household C: the $90,000 couple (the Social Security torpedo)

    /// $38,500 Social Security (near the national average for two retired
    /// spouses) + $51,500 pension and distributions.
    private func householdCCouple() -> DataManager {
        household(.marriedFilingJointly, spouse: true, income: [
            (.socialSecurity, 38_500),
            (.pension, 51_500),
        ])
    }

    /// Survivor keeps the larger benefit and the full pension, landing at $73,500.
    private func householdCSurvivor() -> DataManager {
        household(.single, spouse: false, income: [
            (.socialSecurity, 22_000),
            (.pension, 51_500),
        ])
    }

    @Test("C: couple pays ~$3,433 federal, survivor ~$5,278, neither pays IRMAA")
    func householdCFigures() {
        check("C couple", householdCCouple(),
              publishedFederalTax: 3_432.50, publishedIRMAA: 0)
        check("C survivor", householdCSurvivor(),
              publishedFederalTax: 5_278, publishedIRMAA: 0)
    }

    @Test("C: the torpedo adds about $1,845 and there is never a surcharge")
    func householdCTorpedo() {
        let couple = householdCCouple()
        let survivor = householdCSurvivor()
        let delta = survivor.scenarioFederalTax - couple.scenarioFederalTax
        #expect(abs(delta - 1_845) < 10, "added tax \(delta), article published about 1,845")
        #expect(couple.scenarioIRMAATotalSurcharge == 0)
        #expect(survivor.scenarioIRMAATotalSurcharge == 0,
                "the article states there is no surcharge at this income and never will be")
    }

    // MARK: - The shape of the whole argument

    @Test("The dollars form an arch while the rate rises at every income")
    func theArchHolds() {
        // The chart's claim, and the article's thesis: net change in the
        // survivor's yearly tax+Medicare bill is positive-small at $90,000,
        // positive-large at $180,000, and NEGATIVE at $360,000.
        func netChange(_ couple: DataManager, _ survivor: DataManager) -> Double {
            (survivor.scenarioFederalTax + survivor.scenarioIRMAATotalSurcharge)
                - (couple.scenarioFederalTax + couple.scenarioIRMAATotalSurcharge)
        }
        let c = netChange(householdCCouple(), householdCSurvivor())     // $90,000
        let b = netChange(householdBCouple(), householdBSurvivor())     // $180,000
        let a = netChange(householdACouple(), householdASurvivor())     // $360,000

        #expect(c > 0, "$90,000 household should pay MORE: \(c)")
        #expect(b > c, "$180,000 should be the peak of the arch: \(b) vs \(c)")
        #expect(a < 0, "$360,000 household should pay LESS: \(a)")
    }
}
