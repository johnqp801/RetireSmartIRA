//
//  DataManagerTests.swift
//  RetireSmartIRA
//
//  Tests for core tax calculation logic
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("IRMAA Calculations", .serialized)
@MainActor struct IRMAATests {
    
    @Test("IRMAA Tier 0: Below $109,001 (Single) has no surcharge")
    func irmaaStandardTier() {
        let dm = DataManager(skipPersistence: true)
        dm.filingStatus = .single
        
        let result = dm.calculateIRMAA(magi: 109_000, filingStatus: .single)
        
        #expect(result.tier == 0)
        #expect(result.annualSurchargePerPerson == 0)
        #expect(result.monthlyPartB == DataManager.irmaaStandardPartB)
    }
    
    @Test("IRMAA Tier 1: $109,001 triggers FULL surcharge (cliff-based)")
    func irmaaTier1Cliff() {
        let dm = DataManager(skipPersistence: true)
        dm.filingStatus = .single
        
        // $1 over threshold should trigger FULL Tier 1 surcharge
        let result = dm.calculateIRMAA(magi: 109_001, filingStatus: .single)
        
        #expect(result.tier == 1)
        #expect(result.monthlyPartB == 284.10)
        #expect(result.monthlyPartD == 14.50)
        
        // Annual surcharge = (Part B surcharge + Part D surcharge) × 12
        let expectedAnnual = ((284.10 - 202.90) + 14.50) * 12
        #expect(result.annualSurchargePerPerson == expectedAnnual)
    }
    
    @Test("IRMAA distance to next tier is accurate")
    func irmaaDistanceCalculation() {
        let dm = DataManager(skipPersistence: true)
        dm.filingStatus = .single
        
        let result = dm.calculateIRMAA(magi: 120_000, filingStatus: .single)
        
        // Currently in Tier 1 ($109,001–$137,000)
        // Distance to Tier 2 threshold ($137,001) should be $17,001
        #expect(result.tier == 1)
        #expect(result.distanceToNextTier == 17_001)
        #expect(result.distanceToPreviousTier == 10_999) // $120k - $109,001
    }
    
    @Test("IRMAA Married Filing Jointly uses different thresholds")
    func irmaaMFJThresholds() {
        let dm = DataManager(skipPersistence: true)
        
        // MFJ Tier 1 threshold is $218,001 (vs. $109,001 Single)
        let justBelow = dm.calculateIRMAA(magi: 218_000, filingStatus: .marriedFilingJointly)
        let justAbove = dm.calculateIRMAA(magi: 218_001, filingStatus: .marriedFilingJointly)
        
        #expect(justBelow.tier == 0)
        #expect(justAbove.tier == 1)
    }
    
    @Test("IRMAA top tier (5) has no next tier")
    func irmaaTopTier() {
        let dm = DataManager(skipPersistence: true)
        dm.filingStatus = .single
        
        // $600k puts you in top tier (Tier 5 threshold is $500,001)
        let result = dm.calculateIRMAA(magi: 600_000, filingStatus: .single)
        
        #expect(result.tier == 5)
        #expect(result.distanceToNextTier == nil)
        #expect(result.monthlyPartB == 689.90)
    }
}

@Suite("RMD Calculations", .serialized)
@MainActor struct RMDTests {
    
    @Test("RMD age is 73 for birth years 1951-1959")
    func rmdAge73() {
        let dm = DataManager(skipPersistence: true)
        
        var components = DateComponents()
        components.year = 1955
        components.month = 1
        components.day = 1
        dm.birthDate = Calendar.current.date(from: components)!
        
        #expect(dm.birthYear == 1955)
        #expect(dm.rmdAge == 73)
    }
    
    @Test("RMD age is 75 for birth years 1960+")
    func rmdAge75() {
        let dm = DataManager(skipPersistence: true)
        
        var components = DateComponents()
        components.year = 1965
        components.month = 1
        components.day = 1
        dm.birthDate = Calendar.current.date(from: components)!
        
        #expect(dm.birthYear == 1965)
        #expect(dm.rmdAge == 75)
    }
    
    @Test("RMD calculation uses correct life expectancy factor")
    func rmdCalculationAccuracy() {
        let dm = DataManager(skipPersistence: true)
        
        // Age 73 has factor 26.5 per IRS Uniform Lifetime Table
        let balance = 100_000.0
        let rmd = dm.calculateRMD(for: 73, balance: balance)
        
        let expected = balance / 26.5
        #expect(abs(rmd - expected) < 0.01) // Allow for floating point precision
    }
    
    @Test("RMD not required before RMD age")
    func rmdNotRequiredBeforeAge() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        
        var components = DateComponents()
        components.year = 1960
        components.month = 1
        components.day = 1
        dm.birthDate = Calendar.current.date(from: components)!
        
        // Born 1960, current year 2026 → age 66, RMD age 75
        #expect(dm.currentAge == 66)
        #expect(dm.isRMDRequired == false)
        #expect(dm.calculatePrimaryRMD() == 0)
    }
    
    @Test("Combined RMD includes both spouses when enabled")
    func combinedSpouseRMD() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.enableSpouse = true
        
        // Primary: born 1951, age 75, RMD required
        var primaryComponents = DateComponents()
        primaryComponents.year = 1951
        primaryComponents.month = 1
        primaryComponents.day = 1
        dm.birthDate = Calendar.current.date(from: primaryComponents)!
        
        // Spouse: born 1953, age 73, RMD required
        var spouseComponents = DateComponents()
        spouseComponents.year = 1953
        spouseComponents.month = 1
        spouseComponents.day = 1
        dm.spouseBirthDate = Calendar.current.date(from: spouseComponents)!
        
        // Add accounts
        dm.iraAccounts = [
            IRAAccount(name: "Primary IRA", accountType: .traditionalIRA, balance: 100_000, owner: .primary),
            IRAAccount(name: "Spouse IRA", accountType: .traditionalIRA, balance: 150_000, owner: .spouse)
        ]
        
        let primaryRMD = dm.calculatePrimaryRMD()
        let spouseRMD = dm.calculateSpouseRMD()
        let combined = dm.calculateCombinedRMD()
        
        #expect(primaryRMD > 0)
        #expect(spouseRMD > 0)
        #expect(combined == primaryRMD + spouseRMD)
    }
}

@Suite("QCD Logic", .serialized)
@MainActor struct QCDTests {
    
    @Test("QCD reduces RMD but not below zero")
    func qcdOffsetsRMD() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026

        // Set up age 75 (RMD required)
        var components = DateComponents()
        components.year = 1951
        components.month = 1
        components.day = 1
        dm.birthDate = Calendar.current.date(from: components)!

        // Balance must be large enough that RMD ($200K/24.6 ≈ $8,130) exceeds QCD ($5K)
        dm.iraAccounts = [
            IRAAccount(name: "IRA", accountType: .traditionalIRA, balance: 200_000, owner: .primary)
        ]

        let baseRMD = dm.calculatePrimaryRMD()
        #expect(baseRMD > 5_000) // Confirm RMD exceeds QCD
        dm.yourQCDAmount = 5_000

        let adjustedRMD = dm.scenarioAdjustedRMD

        #expect(adjustedRMD == baseRMD - 5_000)
    }
    
    @Test("QCD does not offset inherited IRA RMDs")
    func qcdDoesNotOffsetInheritedRMD() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        
        var components = DateComponents()
        components.year = 1951
        components.month = 1
        components.day = 1
        dm.birthDate = Calendar.current.date(from: components)!
        
        // Regular IRA with RMD
        dm.iraAccounts = [
            IRAAccount(name: "Regular IRA", accountType: .traditionalIRA, balance: 100_000, owner: .primary),
            IRAAccount(name: "Inherited IRA", accountType: .inheritedTraditionalIRA, balance: 50_000, owner: .primary,
                      beneficiaryType: .nonEligibleDesignated, decedentRBDStatus: .beforeRBD,
                      yearOfInheritance: 2024, beneficiaryBirthYear: 1951)
        ]
        
        let regularRMD = dm.calculatePrimaryRMD()
        let inheritedRMD = dm.inheritedIRARMDTotal
        
        dm.yourQCDAmount = 10_000
        let adjusted = dm.scenarioAdjustedRMD
        
        // QCD should only offset regular RMD, not inherited
        let expected = max(0, regularRMD - 10_000) + inheritedRMD
        #expect(adjusted == expected)
    }
    
    @Test("QCD eligibility requires age 70½")
    func qcdEligibilityAge() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        
        // Age 69 (not eligible)
        var components = DateComponents()
        components.year = 1957
        components.month = 1
        components.day = 1
        dm.birthDate = Calendar.current.date(from: components)!
        
        #expect(dm.isQCDEligible == false)
        
        // Age 71 (eligible)
        components.year = 1955
        dm.birthDate = Calendar.current.date(from: components)!
        #expect(dm.isQCDEligible == true)
    }
}

@Suite("SALT Cap Calculations", .serialized)
@MainActor struct SALTCapTests {
    
    @Test("SALT cap is $40,000 base for 2025")
    func saltCap2025() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2025
        dm.filingStatus = .marriedFilingJointly
        
        // Below phaseout threshold ($500k)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        
        #expect(dm.saltCap == 40_000)
    }
    
    @Test("SALT cap phases out at high income (30% of MAGI over $500k)")
    func saltCapPhaseout() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2025
        dm.filingStatus = .marriedFilingJointly
        
        // MAGI of $600k → $100k over threshold → 30% reduction = $30k
        // Cap: $40k - $30k = $10k (floor)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 600_000)
        ]
        
        #expect(dm.saltCap == 10_000) // Hits the $10k floor
    }
    
    @Test("SALT cap has $10,000 floor regardless of income")
    func saltCapFloor() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2025
        dm.filingStatus = .marriedFilingJointly
        
        // Very high income that would reduce cap below $10k
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 2_000_000)
        ]
        
        // Should never go below $10k
        #expect(dm.saltCap >= 10_000)
    }
    
    @Test("SALT cap reverts to $10,000 in 2030+")
    func saltCapPost2029() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2030
        dm.filingStatus = .marriedFilingJointly
        
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 100_000)
        ]
        
        #expect(dm.saltCap == 10_000)
    }
}

@Suite("Standard Deduction with OBBBA Senior Bonus", .serialized)
@MainActor struct StandardDeductionTests {
    
    @Test("2026 standard deduction: $16,100 Single")
    func standardDeduction2026Single() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.filingStatus = .single
        
        var components = DateComponents()
        components.year = 1990 // Age 36, no senior bonus
        components.month = 1
        components.day = 1
        dm.birthDate = Calendar.current.date(from: components)!
        
        #expect(dm.standardDeductionAmount == 16_100)
    }
    
    @Test("Senior bonus: $6,000 for 65+ with phaseout")
    func seniorBonusWithPhaseout() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2025
        dm.filingStatus = .single
        
        // Age 70
        var components = DateComponents()
        components.year = 1955
        components.month = 1
        components.day = 1
        dm.birthDate = Calendar.current.date(from: components)!
        
        // MAGI $80,000 → $5k over threshold → 6% reduction = $300
        // Bonus: $6,000 - $300 = $5,700
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 80_000)
        ]
        
        let expectedBase = 15_750.0 // 2025 base Single
        let expectedAge65Plus = 2_000.0 // 2025 additional
        let expectedBonus = 6_000.0 - ((80_000 - 75_000) * 0.06)
        
        let expected = expectedBase + expectedAge65Plus + expectedBonus
        
        #expect(abs(dm.standardDeductionAmount - expected) < 0.01)
    }
    
    @Test("Senior bonus phases out completely at very high income")
    func seniorBonusPhaseoutComplete() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2025
        dm.filingStatus = .single
        
        var components = DateComponents()
        components.year = 1955
        components.month = 1
        components.day = 1
        dm.birthDate = Calendar.current.date(from: components)!
        
        // MAGI $175,000 → $100k over threshold → 6% reduction = $6,000 (full phaseout)
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 175_000)
        ]
        
        // Should get base + age 65+ additional, but NO senior bonus
        let expectedBase = 15_750.0
        let expectedAge65Plus = 2_000.0
        let expected = expectedBase + expectedAge65Plus
        
        #expect(abs(dm.standardDeductionAmount - expected) < 0.01)
    }
}
