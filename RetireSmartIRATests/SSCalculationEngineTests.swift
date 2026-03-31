//
//  SSCalculationEngineTests.swift
//  RetireSmartIRATests
//
//  Comprehensive unit tests for the Social Security calculation engine.
//  Validates all formulas against published SSA rules and known examples.
//

import XCTest
@testable import RetireSmartIRA

final class SSFRATests: XCTestCase {

    func testFRA1937() {
        let fra = SSCalculationEngine.fullRetirementAge(birthYear: 1937)
        XCTAssertEqual(fra.years, 65)
        XCTAssertEqual(fra.months, 0)
    }

    func testFRA1943to1954() {
        for year in 1943...1954 {
            let fra = SSCalculationEngine.fullRetirementAge(birthYear: year)
            XCTAssertEqual(fra.years, 66, "Birth year \(year)")
            XCTAssertEqual(fra.months, 0, "Birth year \(year)")
        }
    }

    func testFRA1955() {
        let fra = SSCalculationEngine.fullRetirementAge(birthYear: 1955)
        XCTAssertEqual(fra.years, 66)
        XCTAssertEqual(fra.months, 2)
    }

    func testFRA1960Plus() {
        for year in [1960, 1965, 1970, 1980, 2000] {
            let fra = SSCalculationEngine.fullRetirementAge(birthYear: year)
            XCTAssertEqual(fra.years, 67, "Birth year \(year)")
            XCTAssertEqual(fra.months, 0)
        }
    }

    func testFRAInMonths() {
        let months = SSCalculationEngine.fraInMonths(birthYear: 1955)
        XCTAssertEqual(months, 66 * 12 + 2)
    }
}

// MARK: - Early Reduction

final class SSEarlyReductionTests: XCTestCase {

    func testNoReduction() {
        let result = SSCalculationEngine.applyEarlyReduction(pia: 2000, monthsEarly: 0)
        XCTAssertEqual(result, 2000)
    }

    func test36MonthsEarly() {
        let result = SSCalculationEngine.applyEarlyReduction(pia: 2000, monthsEarly: 36)
        XCTAssertEqual(result, 2000.0 * 0.80, accuracy: 0.01)
    }

    func test60MonthsEarly_30PercentReduction() {
        let result = SSCalculationEngine.applyEarlyReduction(pia: 2000, monthsEarly: 60)
        XCTAssertEqual(result, 2000.0 * 0.70, accuracy: 0.01)
    }

    func test48MonthsEarly_25PercentReduction() {
        let result = SSCalculationEngine.applyEarlyReduction(pia: 2000, monthsEarly: 48)
        XCTAssertEqual(result, 2000.0 * 0.75, accuracy: 0.01)
    }

    func testSSAExample_PIA1000_At62_FRA67() {
        let result = SSCalculationEngine.applyEarlyReduction(pia: 1000, monthsEarly: 60)
        XCTAssertEqual(result, 700.0, accuracy: 0.01)
    }

    func testSSAExample_PIA1000_At62_FRA66() {
        let result = SSCalculationEngine.applyEarlyReduction(pia: 1000, monthsEarly: 48)
        XCTAssertEqual(result, 750.0, accuracy: 0.01)
    }
}

// MARK: - Spousal Early Reduction

final class SSSpousalReductionTests: XCTestCase {

    func testNoReduction() {
        let result = SSCalculationEngine.applySpousalEarlyReduction(maxSpousal: 1000, monthsEarly: 0)
        XCTAssertEqual(result, 1000)
    }

    func test36MonthsEarly_25PercentReduction() {
        let result = SSCalculationEngine.applySpousalEarlyReduction(maxSpousal: 1000, monthsEarly: 36)
        XCTAssertEqual(result, 1000.0 * 0.75, accuracy: 0.01)
    }

    func test60MonthsEarly_35PercentReduction() {
        let result = SSCalculationEngine.applySpousalEarlyReduction(maxSpousal: 1000, monthsEarly: 60)
        XCTAssertEqual(result, 1000.0 * 0.65, accuracy: 0.01)
    }

    func testSpousalSteeperThanRetirement() {
        let retirement = SSCalculationEngine.applyEarlyReduction(pia: 1000, monthsEarly: 60)
        let spousal = SSCalculationEngine.applySpousalEarlyReduction(maxSpousal: 1000, monthsEarly: 60)
        XCTAssertGreaterThan(retirement, spousal, "Spousal reduction should be steeper")
        XCTAssertEqual(retirement, 700.0, accuracy: 0.01)
        XCTAssertEqual(spousal, 650.0, accuracy: 0.01)
    }

    func testSSAExample_WorkerPIA2000_SpousalAt62() {
        let maxSpousal = SSCalculationEngine.maxSpousalBenefit(workerPIA: 2000)
        XCTAssertEqual(maxSpousal, 1000)
        let reduced = SSCalculationEngine.applySpousalEarlyReduction(maxSpousal: maxSpousal, monthsEarly: 60)
        XCTAssertEqual(reduced, 650.0, accuracy: 0.01)
    }
}

// MARK: - Delayed Credits

final class SSDelayedCreditsTests: XCTestCase {

    func testNoDelay() {
        let result = SSCalculationEngine.applyDelayedCredits(pia: 2000, monthsDelayed: 0)
        XCTAssertEqual(result, 2000)
    }

    func test12Months_8Percent() {
        let result = SSCalculationEngine.applyDelayedCredits(pia: 2000, monthsDelayed: 12)
        XCTAssertEqual(result, 2000.0 * 1.08, accuracy: 0.01)
    }

    func test36Months_24Percent() {
        let result = SSCalculationEngine.applyDelayedCredits(pia: 2000, monthsDelayed: 36)
        XCTAssertEqual(result, 2000.0 * 1.24, accuracy: 0.01)
    }

    func testSSA_PIA1000_At70_FRA67() {
        let result = SSCalculationEngine.applyDelayedCredits(pia: 1000, monthsDelayed: 36)
        XCTAssertEqual(result, 1240.0, accuracy: 0.01)
    }

    func testSSA_PIA1000_At70_FRA66() {
        let result = SSCalculationEngine.applyDelayedCredits(pia: 1000, monthsDelayed: 48)
        XCTAssertEqual(result, 1000.0 * 1.32, accuracy: 0.01)
    }
}

// MARK: - Benefit At Age Integration

final class SSBenefitAtAgeTests: XCTestCase {

    func testAtFRA_ReturnsPIA() {
        let benefit = SSCalculationEngine.benefitAtAge(
            claimingAge: 67, claimingMonth: 0,
            pia: 2660, fraYears: 67, fraMonths: 0)
        XCTAssertEqual(benefit, 2660)
    }

    func testAt62_FRA67_30PercentReduction() {
        let benefit = SSCalculationEngine.benefitAtAge(
            claimingAge: 62, claimingMonth: 0,
            pia: 2660, fraYears: 67, fraMonths: 0)
        XCTAssertEqual(benefit, 2660.0 * 0.70, accuracy: 0.01)
    }

    func testAt70_FRA67_24PercentIncrease() {
        let benefit = SSCalculationEngine.benefitAtAge(
            claimingAge: 70, claimingMonth: 0,
            pia: 2660, fraYears: 67, fraMonths: 0)
        XCTAssertEqual(benefit, 2660.0 * 1.24, accuracy: 0.01)
    }

    func testAt62_FRA66and2() {
        let benefit = SSCalculationEngine.benefitAtAge(
            claimingAge: 62, claimingMonth: 0,
            pia: 1000, fraYears: 66, fraMonths: 2)
        let expectedReduction = (36.0 * 5.0/9.0/100.0) + (14.0 * 5.0/12.0/100.0)
        XCTAssertEqual(benefit, 1000.0 * (1.0 - expectedReduction), accuracy: 0.01)
    }
}

// MARK: - PIA Calculation

final class SSPIATests: XCTestCase {

    func testPIAFormula_90_32_15() {
        let pia = SSCalculationEngine.piaFromAIME(aime: 8000, bendPoint1: 1174.0, bendPoint2: 7078.0)
        let expected: Double = 0.90 * 1174.0 + 0.32 * (7078.0 - 1174.0) + 0.15 * (8000.0 - 7078.0)
        XCTAssertEqual(pia, expected, accuracy: 0.01)
    }

    func testPIA_BelowBP1_90PercentOnly() {
        let pia = SSCalculationEngine.piaFromAIME(aime: 1000, bendPoint1: 1174.0, bendPoint2: 7078.0)
        XCTAssertEqual(pia, 1000.0 * 0.90, accuracy: 0.01)
    }

    func testPIA_BetweenBPs() {
        let pia = SSCalculationEngine.piaFromAIME(aime: 5000, bendPoint1: 1174.0, bendPoint2: 7078.0)
        let expected: Double = 0.90 * 1174.0 + 0.32 * (5000.0 - 1174.0)
        XCTAssertEqual(pia, expected, accuracy: 0.01)
    }

    func testAIMECalculation() {
        var records: [SSEarningsRecord] = []
        for year in 1990...2024 {
            records.append(SSEarningsRecord(year: year, earnings: 50000))
        }
        let result = SSCalculationEngine.calculatePIA(records: records, birthYear: 1962)
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result!.aime, 0)
        XCTAssertGreaterThan(result!.pia, 0)
        XCTAssertEqual(result!.top35Years.count, 35)
    }

    func testFewerThan35Years() {
        var records: [SSEarningsRecord] = []
        for year in 2015...2024 {
            records.append(SSEarningsRecord(year: year, earnings: 60000))
        }
        let result = SSCalculationEngine.calculatePIA(records: records, birthYear: 1962)
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result!.aime, 0)
        XCTAssertLessThan(result!.aime, 5000, "AIME with only 10 work years should be modest")
    }
}

// MARK: - Bend Points

final class SSBendPointTests: XCTestCase {

    func testBP2024() {
        let bp = SSCalculationEngine.piaBendPoints(yearTurning62: 2024)
        XCTAssertEqual(bp.bp1, 1174)
        XCTAssertEqual(bp.bp2, 7078)
    }

    func testBP2025() {
        let bp = SSCalculationEngine.piaBendPoints(yearTurning62: 2025)
        XCTAssertEqual(bp.bp1, 1226)
        XCTAssertEqual(bp.bp2, 7391)
    }

    func testBP2022() {
        let bp = SSCalculationEngine.piaBendPoints(yearTurning62: 2022)
        XCTAssertEqual(bp.bp1, 1024)
        XCTAssertEqual(bp.bp2, 6172)
    }

    func testBP2023() {
        let bp = SSCalculationEngine.piaBendPoints(yearTurning62: 2023)
        XCTAssertEqual(bp.bp1, 1115)
        XCTAssertEqual(bp.bp2, 6721)
    }

    func testBP2000() {
        let bp = SSCalculationEngine.piaBendPoints(yearTurning62: 2000)
        XCTAssertEqual(bp.bp1, 531)
        XCTAssertEqual(bp.bp2, 3202)
    }

    func testBP2010() {
        let bp = SSCalculationEngine.piaBendPoints(yearTurning62: 2010)
        XCTAssertEqual(bp.bp1, 761)
        XCTAssertEqual(bp.bp2, 4586)
    }
}

// MARK: - AWI & Taxable Max

final class SSAWITests: XCTestCase {

    func testAWI1951() { XCTAssertEqual(SSCalculationEngine.awiTable[1951], 2799.16) }
    func testAWI2000() { XCTAssertEqual(SSCalculationEngine.awiTable[2000], 32154.82) }
    func testAWI2020() { XCTAssertEqual(SSCalculationEngine.awiTable[2020], 55628.60) }
    func testAWI2023() { XCTAssertEqual(SSCalculationEngine.awiTable[2023], 66621.80) }

    func testAWITableCoverage() {
        XCTAssertEqual(SSCalculationEngine.awiTable.count, 73)
        XCTAssertNotNil(SSCalculationEngine.awiTable[1951])
        XCTAssertNotNil(SSCalculationEngine.awiTable[2023])
    }
}

final class SSTaxableMaxTests: XCTestCase {

    func testMax2024() { XCTAssertEqual(SSCalculationEngine.taxableMaxTable[2024], 168600) }
    func testMax2025() { XCTAssertEqual(SSCalculationEngine.taxableMaxTable[2025], 176100) }
    func testMax2000() { XCTAssertEqual(SSCalculationEngine.taxableMaxTable[2000], 76200) }
    func testMax1990() { XCTAssertEqual(SSCalculationEngine.taxableMaxTable[1990], 51300) }
}

// MARK: - Spousal Benefit Integration

final class SSSpousalBenefitTests: XCTestCase {

    func testMaxSpousal() {
        XCTAssertEqual(SSCalculationEngine.maxSpousalBenefit(workerPIA: 3000), 1500)
    }

    func testOwnBenefitHigher() {
        let benefit = SSCalculationEngine.spousalBenefit(
            workerPIA: 2000, spouseOwnPIA: 2500,
            spouseClaimingAge: 67, spouseBirthYear: 1960)
        XCTAssertEqual(benefit, 2500)
    }

    func testSpousalAtFRA() {
        let benefit = SSCalculationEngine.spousalBenefit(
            workerPIA: 3000, spouseOwnPIA: 500,
            spouseClaimingAge: 67, spouseBirthYear: 1960)
        XCTAssertEqual(benefit, 1500, accuracy: 0.01)
    }

    func testSpousalAt62_ZeroOwnPIA() {
        let benefit = SSCalculationEngine.spousalBenefit(
            workerPIA: 3000, spouseOwnPIA: 0,
            spouseClaimingAge: 62, spouseBirthYear: 1960)
        XCTAssertEqual(benefit, 1500.0 * 0.65, accuracy: 0.01)
    }

    func testNoDRCForSpousal() {
        let atFRA = SSCalculationEngine.spousalBenefit(
            workerPIA: 3000, spouseOwnPIA: 0,
            spouseClaimingAge: 67, spouseBirthYear: 1960)
        let at70 = SSCalculationEngine.spousalBenefit(
            workerPIA: 3000, spouseOwnPIA: 0,
            spouseClaimingAge: 70, spouseBirthYear: 1960)
        XCTAssertEqual(atFRA, at70, "No DRC on spousal benefits")
    }

    func testDeemedFilingAt62() {
        let benefit = SSCalculationEngine.spousalBenefit(
            workerPIA: 3000, spouseOwnPIA: 800,
            spouseClaimingAge: 62, spouseBirthYear: 1960)
        let expectedOwn = 800.0 * 0.70
        let expectedExcess = 700.0 * 0.65
        XCTAssertEqual(benefit, expectedOwn + expectedExcess, accuracy: 0.01)
    }

    func testDeemedFilingAtFRA() {
        let benefit = SSCalculationEngine.spousalBenefit(
            workerPIA: 3000, spouseOwnPIA: 800,
            spouseClaimingAge: 67, spouseBirthYear: 1960)
        XCTAssertEqual(benefit, 1500.0, accuracy: 0.01)
    }
}

// MARK: - Survivor Benefits

final class SSSurvivorTests: XCTestCase {

    func testSurvivorGetsHigher() {
        let result = SSCalculationEngine.survivorBenefit(
            survivorOwnBenefit: 1500, deceasedActualBenefit: 2500)
        XCTAssertEqual(result, 2500)
    }

    func testSurvivorKeepsOwn() {
        let result = SSCalculationEngine.survivorBenefit(
            survivorOwnBenefit: 3000, deceasedActualBenefit: 2000)
        XCTAssertEqual(result, 3000)
    }

    func testRIBLIM() {
        let result = SSCalculationEngine.survivorBenefit(
            survivorOwnBenefit: 800, deceasedActualBenefit: 1400, deceasedPIA: 2000)
        XCTAssertEqual(result, 1650.0, accuracy: 0.01)
    }

    func testRIBLIM_NotAppliedAtFRA() {
        let result = SSCalculationEngine.survivorBenefit(
            survivorOwnBenefit: 800, deceasedActualBenefit: 2000, deceasedPIA: 2000)
        XCTAssertEqual(result, 2000)
    }

    func testRIBLIM_WithDRC() {
        let result = SSCalculationEngine.survivorBenefit(
            survivorOwnBenefit: 800, deceasedActualBenefit: 2480, deceasedPIA: 2000)
        XCTAssertEqual(result, 2480)
    }

    func testSurvivorAgeReduction() {
        let result = SSCalculationEngine.survivorBenefit(
            survivorOwnBenefit: 800, deceasedActualBenefit: 2500,
            survivorAge: 60, survivorFRAYears: 67)
        XCTAssertEqual(result, 2500.0 * 0.715, accuracy: 1.0)
    }

    func testSurvivorAtFRA_NoReduction() {
        let result = SSCalculationEngine.survivorBenefit(
            survivorOwnBenefit: 800, deceasedActualBenefit: 2500,
            survivorAge: 67, survivorFRAYears: 67)
        XCTAssertEqual(result, 2500)
    }
}

// MARK: - Adjustment Percentage

final class SSAdjustmentPercentageTests: XCTestCase {

    func testAtFRA() {
        let pct = SSCalculationEngine.adjustmentPercentage(claimingAge: 67, fraYears: 67, fraMonths: 0)
        XCTAssertEqual(pct, 0)
    }

    func testAt62_FRA67() {
        let pct = SSCalculationEngine.adjustmentPercentage(claimingAge: 62, fraYears: 67, fraMonths: 0)
        XCTAssertEqual(pct, -30.0, accuracy: 0.01)
    }

    func testAt70_FRA67() {
        let pct = SSCalculationEngine.adjustmentPercentage(claimingAge: 70, fraYears: 67, fraMonths: 0)
        XCTAssertEqual(pct, 24.0, accuracy: 0.01)
    }

    func testAt70_FRA66() {
        let pct = SSCalculationEngine.adjustmentPercentage(claimingAge: 70, fraYears: 66, fraMonths: 0)
        XCTAssertEqual(pct, 32.0, accuracy: 0.01)
    }
}

// MARK: - Text Parser

final class SSTextParserTests: XCTestCase {

    func testSimpleLines() {
        let text = "2020  137,700\n2021  142,800\n2022  147,000"
        if case .success(let parsed) = SSCalculationEngine.parseEarningsHistory(text) {
            XCTAssertEqual(parsed.records.count, 3)
            XCTAssertEqual(parsed.records[0].year, 2020)
            XCTAssertEqual(parsed.records[0].earnings, 137700)
        } else { XCTFail("Should parse") }
    }

    func testDollarSigns() {
        let text = "2020  $137,700"
        if case .success(let parsed) = SSCalculationEngine.parseEarningsHistory(text) {
            XCTAssertEqual(parsed.records[0].earnings, 137700)
        } else { XCTFail("Should parse") }
    }

    func testYearRanges() {
        let text = "1966-1980  $48,273"
        if case .success(let parsed) = SSCalculationEngine.parseEarningsHistory(text) {
            XCTAssertEqual(parsed.records.count, 15)
            let perYear = 48273.0 / 15.0
            for record in parsed.records {
                XCTAssertEqual(record.earnings, perYear, accuracy: 0.01)
            }
            XCTAssertEqual(parsed.records.first?.year, 1966)
            XCTAssertEqual(parsed.records.last?.year, 1980)
        } else { XCTFail("Should parse year range") }
    }

    func testSkipsNotYetRecorded() {
        let text = "2024  $168,600\n2025  Not yet recorded"
        if case .success(let parsed) = SSCalculationEngine.parseEarningsHistory(text) {
            XCTAssertEqual(parsed.records.count, 1)
        } else { XCTFail("Should parse") }
    }

    func testTwoColumnFormat() {
        let text = "2020  $137,700  $200,000"
        if case .success(let parsed) = SSCalculationEngine.parseEarningsHistory(text) {
            XCTAssertEqual(parsed.records[0].earnings, 137700)
        } else { XCTFail("Should parse") }
    }

    func testEmptyReturnsError() {
        if case .failure(.noValidRows) = SSCalculationEngine.parseEarningsHistory("") {
            // Expected
        } else { XCTFail("Should fail for empty input") }
    }

    func testSortedByYear() {
        let text = "2022  $100,000\n2020  $90,000\n2021  $95,000"
        if case .success(let parsed) = SSCalculationEngine.parseEarningsHistory(text) {
            XCTAssertEqual(parsed.records[0].year, 2020)
            XCTAssertEqual(parsed.records[1].year, 2021)
            XCTAssertEqual(parsed.records[2].year, 2022)
        } else { XCTFail("Should parse") }
    }
}

// MARK: - XML Parser

final class SSXMLParserTests: XCTestCase {

    func testSingleYearEarnings() {
        let xml = """
        <?xml version="1.0"?>
        <osss:OnlineSocialSecurityStatementData xmlns:osss="http://ssa.gov/osss">
        <osss:EarningsRecord>
        <osss:Earnings startYear="2020" endYear="2020">
        <osss:FicaEarnings>137700</osss:FicaEarnings>
        </osss:Earnings>
        </osss:EarningsRecord>
        </osss:OnlineSocialSecurityStatementData>
        """
        let data = xml.data(using: .utf8)!
        if case .success(let parsed) = SSCalculationEngine.parseEarningsXML(data) {
            XCTAssertEqual(parsed.earnings.records.count, 1)
            XCTAssertEqual(parsed.earnings.records[0].year, 2020)
            XCTAssertEqual(parsed.earnings.records[0].earnings, 137700)
        } else { XCTFail("Should parse XML") }
    }

    func testSkipsNegativeOne() {
        let xml = """
        <?xml version="1.0"?>
        <osss:OnlineSocialSecurityStatementData xmlns:osss="http://ssa.gov/osss">
        <osss:EarningsRecord>
        <osss:Earnings startYear="2024" endYear="2024">
        <osss:FicaEarnings>100000</osss:FicaEarnings>
        </osss:Earnings>
        <osss:Earnings startYear="2025" endYear="2025">
        <osss:FicaEarnings>-1</osss:FicaEarnings>
        </osss:Earnings>
        </osss:EarningsRecord>
        </osss:OnlineSocialSecurityStatementData>
        """
        let data = xml.data(using: .utf8)!
        if case .success(let parsed) = SSCalculationEngine.parseEarningsXML(data) {
            XCTAssertEqual(parsed.earnings.records.count, 1)
        } else { XCTFail("Should parse XML") }
    }

    func testEmptyXMLFails() {
        let xml = """
        <?xml version="1.0"?>
        <osss:OnlineSocialSecurityStatementData xmlns:osss="http://ssa.gov/osss">
        </osss:OnlineSocialSecurityStatementData>
        """
        let data = xml.data(using: .utf8)!
        if case .failure(.noValidRows) = SSCalculationEngine.parseEarningsXML(data) {
            // Expected
        } else { XCTFail("Should fail for empty XML") }
    }
}

// MARK: - Couples Matrix

final class SSCouplesMatrixTests: XCTestCase {

    func testMatrixSize() {
        let matrix = SSCalculationEngine.couplesMatrix(
            primaryPIA: 2660, primaryBirthYear: 1960, primaryLifeExpectancy: 90,
            spousePIA: 1700, spouseBirthYear: 1960, spouseLifeExpectancy: 90)
        XCTAssertEqual(matrix.count, 81)
    }

    func testMatrixAgeRange() {
        let matrix = SSCalculationEngine.couplesMatrix(
            primaryPIA: 2660, primaryBirthYear: 1960, primaryLifeExpectancy: 90,
            spousePIA: 1700, spouseBirthYear: 1960, spouseLifeExpectancy: 90)
        let primaryAges = Set(matrix.map(\.primaryClaimingAge))
        let spouseAges = Set(matrix.map(\.spouseClaimingAge))
        XCTAssertEqual(primaryAges, Set(62...70))
        XCTAssertEqual(spouseAges, Set(62...70))
    }

    func testLaterClaimingWinsWithLongLife() {
        let matrix = SSCalculationEngine.couplesMatrix(
            primaryPIA: 2660, primaryBirthYear: 1960, primaryLifeExpectancy: 95,
            spousePIA: 1700, spouseBirthYear: 1960, spouseLifeExpectancy: 95)
        let cell62 = matrix.first { $0.primaryClaimingAge == 62 && $0.spouseClaimingAge == 62 }!
        let cell70 = matrix.first { $0.primaryClaimingAge == 70 && $0.spouseClaimingAge == 70 }!
        XCTAssertGreaterThan(cell70.combinedLifetimeBenefit, cell62.combinedLifetimeBenefit)
    }

    func testEarlyClaimingWinsWithShortLife() {
        let matrix = SSCalculationEngine.couplesMatrix(
            primaryPIA: 2660, primaryBirthYear: 1960, primaryLifeExpectancy: 72,
            spousePIA: 1700, spouseBirthYear: 1960, spouseLifeExpectancy: 72)
        let cell62 = matrix.first { $0.primaryClaimingAge == 62 && $0.spouseClaimingAge == 62 }!
        let cell70 = matrix.first { $0.primaryClaimingAge == 70 && $0.spouseClaimingAge == 70 }!
        XCTAssertGreaterThan(cell62.combinedLifetimeBenefit, cell70.combinedLifetimeBenefit)
    }

    func testPVDiscounting() {
        let noPV = SSCalculationEngine.couplesMatrix(
            primaryPIA: 2660, primaryBirthYear: 1960, primaryLifeExpectancy: 90,
            spousePIA: 1700, spouseBirthYear: 1960, spouseLifeExpectancy: 90, discountRate: 0)
        let withPV = SSCalculationEngine.couplesMatrix(
            primaryPIA: 2660, primaryBirthYear: 1960, primaryLifeExpectancy: 90,
            spousePIA: 1700, spouseBirthYear: 1960, spouseLifeExpectancy: 90, discountRate: 3.0)
        let noPVAmount = noPV.first { $0.primaryClaimingAge == 70 && $0.spouseClaimingAge == 70 }!.combinedLifetimeBenefit
        let pvAmount = withPV.first { $0.primaryClaimingAge == 70 && $0.spouseClaimingAge == 70 }!.combinedLifetimeBenefit
        XCTAssertLessThan(pvAmount, noPVAmount)
    }

    func testMatrixIncludesSpousalTopUp() {
        let matrix = SSCalculationEngine.couplesMatrix(
            primaryPIA: 3000, primaryBirthYear: 1960, primaryLifeExpectancy: 90,
            spousePIA: 400, spouseBirthYear: 1960, spouseLifeExpectancy: 90)
        let cell = matrix.first { $0.primaryClaimingAge == 67 && $0.spouseClaimingAge == 67 }!
        XCTAssertEqual(cell.spouseMonthly, 1500, "Spouse should get spousal top-up to 50% of $3000")
    }

    func testMatrixSurvivorWithRIBLIM() {
        let matrix = SSCalculationEngine.couplesMatrix(
            primaryPIA: 2000, primaryBirthYear: 1960, primaryLifeExpectancy: 90,
            spousePIA: 500, spouseBirthYear: 1960, spouseLifeExpectancy: 90)
        let cell = matrix.first { $0.primaryClaimingAge == 62 && $0.spouseClaimingAge == 67 }!
        XCTAssertEqual(cell.survivorBenefitIfPrimaryDies, 1650.0, accuracy: 1.0,
                       "Survivor should reflect 82.5% RIB-LIM floor")
    }
}

// MARK: - Formatting

final class SSFormattingTests: XCTestCase {

    func testFormatCurrency() {
        let result = SSCalculationEngine.formatCurrency(2660)
        XCTAssertTrue(result.contains("2,660"))
    }

    func testFormatLargeMillions() {
        XCTAssertEqual(SSCalculationEngine.formatLargeCurrency(1_500_000), "$1.5M")
    }

    func testFormatLargeThousands() {
        XCTAssertEqual(SSCalculationEngine.formatLargeCurrency(350_000), "$350K")
    }
}
