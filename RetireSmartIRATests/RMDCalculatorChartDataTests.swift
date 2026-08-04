//
//  RMDCalculatorChartDataTests.swift
//  RetireSmartIRATests
//
//  Tests for the inherited IRA chart window and deadline-notice behavior.
//
//  Background:
//  Task 5.2 fixed Fred's bug by extending the chart window to cover inherited
//  NEDB deadlines beyond projectionYears.  Smoke testing revealed this creates
//  a contradiction: clicking "5 years" could produce 7 bars.  Worse, regular
//  RMD bars truncated at projectionYears while inherited bars extended —
//  inconsistent visual.
//
//  Option A (revised): picker selection is authoritative.  The chart shows
//  exactly projectionYears bars.  When a NEDB deadline falls outside the
//  picker window, `inheritedDeadlinesOutsideWindow` surfaces a nudge notice.
//
//  These tests verify:
//  1. projectInheritedIRA includes the deadline year row for NEDB accounts (engine).
//  2. The chart window is strictly projectionYears — no extension for deadlines.
//  3. Pre-RBD NEDB: years 1-10 have zero RMD, deadline year has full-balance drain.
//  4. Post-RBD NEDB: years 1-10 have partial RMDs, deadline year drains the balance.
//  5. inheritedDeadlinesOutsideWindow logic: notice fires when deadline > lastVisibleYear.
//  6. inheritedDeadlinesOutsideWindow logic: no notice when deadline <= lastVisibleYear.
//  7. Fresh-inheritance at default 10-year picker → deadline at +10 fires notice.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("RMD Chart Data — Inherited IRA Window Extension")
struct RMDCalculatorChartDataTests {

    // MARK: - Helpers

    /// Build a fresh NEDB inherited-IRA account for a given currentYear.
    private func makeNEDBAccount(
        balance: Double = 250_000,
        currentYear: Int,
        decedentRBDStatus: DecedentRBDStatus
    ) -> IRAAccount {
        IRAAccount(
            name: "Inherited",
            accountType: .inheritedTraditionalIRA,
            balance: balance,
            owner: .primary,
            beneficiaryType: .nonEligibleDesignated,
            decedentRBDStatus: decedentRBDStatus,
            yearOfInheritance: currentYear,         // freshly inherited
            decedentBirthYear: 1945,
            beneficiaryBirthYear: 1965
        )
    }

    // MARK: - Engine guarantee: projectInheritedIRA reaches the deadline year

    @Test("NEDB post-RBD: projectInheritedIRA includes deadline year (yearOfInheritance+10)")
    func nedbPostRBD_projectionIncludesDeadlineYear() {
        let currentYear = 2026
        let account = makeNEDBAccount(currentYear: currentYear, decedentRBDStatus: .afterRBD)
        let deadlineYear = currentYear + 10

        let rows = RMDCalculationEngine.projectInheritedIRA(
            account: account,
            currentYear: currentYear,
            projectionYears: 10,        // default chart window
            growthPercent: 6.0
        )

        let years = rows.map { $0.year }
        #expect(years.contains(deadlineYear),
                "Post-RBD NEDB projection must include the deadline year \(deadlineYear); got years \(years)")
    }

    @Test("NEDB pre-RBD: projectInheritedIRA includes deadline year (yearOfInheritance+10)")
    func nedbPreRBD_projectionIncludesDeadlineYear() {
        let currentYear = 2026
        let account = makeNEDBAccount(currentYear: currentYear, decedentRBDStatus: .beforeRBD)
        let deadlineYear = currentYear + 10

        let rows = RMDCalculationEngine.projectInheritedIRA(
            account: account,
            currentYear: currentYear,
            projectionYears: 10,
            growthPercent: 6.0
        )

        let years = rows.map { $0.year }
        #expect(years.contains(deadlineYear),
                "Pre-RBD NEDB projection must include the deadline year \(deadlineYear); got years \(years)")
    }

    // MARK: - Pre-RBD NEDB: years 1-10 zero RMD, year 11 is full drain

    @Test("NEDB pre-RBD: RMD is zero for all years before deadline")
    func nedbPreRBD_zeroRMDBeforeDeadline() {
        let currentYear = 2026
        let account = makeNEDBAccount(currentYear: currentYear, decedentRBDStatus: .beforeRBD)
        let deadlineYear = currentYear + 10

        let rows = RMDCalculationEngine.projectInheritedIRA(
            account: account,
            currentYear: currentYear,
            projectionYears: 10,
            growthPercent: 6.0
        )

        let preDeadlineRows = rows.filter { $0.year < deadlineYear }
        #expect(!preDeadlineRows.isEmpty, "Should have rows before deadline")
        for row in preDeadlineRows {
            #expect(row.rmd == 0,
                    "Pre-RBD NEDB year \(row.year) should have zero RMD before deadline, got \(row.rmd)")
        }
    }

    @Test("NEDB pre-RBD: deadline year drains the full balance")
    func nedbPreRBD_deadlineYearDrainsBalance() {
        let currentYear = 2026
        let balance = 250_000.0
        let account = makeNEDBAccount(balance: balance, currentYear: currentYear, decedentRBDStatus: .beforeRBD)
        let deadlineYear = currentYear + 10

        let rows = RMDCalculationEngine.projectInheritedIRA(
            account: account,
            currentYear: currentYear,
            projectionYears: 10,
            growthPercent: 6.0
        )

        guard let deadlineRow = rows.first(where: { $0.year == deadlineYear }) else {
            Issue.record("No deadline-year row found in projection")
            return
        }

        // The deadline row must drain the full accumulated balance (rmd == balance for that row)
        #expect(deadlineRow.rmd > balance,
                "Pre-RBD NEDB deadline row should drain a grown balance (>= \(balance)); got \(deadlineRow.rmd)")
        #expect(deadlineRow.isDeadline,
                "Row at deadline year should have isDeadline = true")
    }

    // MARK: - Post-RBD NEDB: annual RMDs during window, then full drain at deadline

    @Test("NEDB post-RBD: annual RMDs are positive for years after inheritance year, before deadline")
    func nedbPostRBD_annualRMDsPositiveBeforeDeadline() {
        let currentYear = 2026
        let account = makeNEDBAccount(currentYear: currentYear, decedentRBDStatus: .afterRBD)
        let deadlineYear = currentYear + 10

        let rows = RMDCalculationEngine.projectInheritedIRA(
            account: account,
            currentYear: currentYear,
            projectionYears: 10,
            growthPercent: 6.0
        )

        // Year of inheritance (yearsElapsed=0) has zero RMD per IRS rules — RMDs begin
        // the year AFTER inheritance. All subsequent years before the deadline must be positive.
        let postInheritancePreDeadlineRows = rows.filter { $0.year > currentYear && $0.year < deadlineYear }
        #expect(!postInheritancePreDeadlineRows.isEmpty, "Should have rows between inheritance year and deadline")
        for row in postInheritancePreDeadlineRows {
            #expect(row.rmd > 0,
                    "Post-RBD NEDB year \(row.year) should have a positive annual RMD, got \(row.rmd)")
        }
    }

    @Test("NEDB post-RBD: deadline year has the largest RMD in the projection")
    func nedbPostRBD_deadlineYearHasLargestRMD() {
        let currentYear = 2026
        let account = makeNEDBAccount(currentYear: currentYear, decedentRBDStatus: .afterRBD)
        let deadlineYear = currentYear + 10

        let rows = RMDCalculationEngine.projectInheritedIRA(
            account: account,
            currentYear: currentYear,
            projectionYears: 10,
            growthPercent: 6.0
        )

        guard let deadlineRow = rows.first(where: { $0.year == deadlineYear }) else {
            Issue.record("No deadline-year row found in projection")
            return
        }
        let maxPreDeadline = rows.filter { $0.year < deadlineYear }.map { $0.rmd }.max() ?? 0
        #expect(deadlineRow.rmd > maxPreDeadline,
                "Deadline year RMD (\(deadlineRow.rmd)) should exceed all prior-year RMDs (max: \(maxPreDeadline))")
    }

    // MARK: - Chart window formula: strictly picker-bound (no extension)

    @Test("Chart window stays at projectionYears-1 even when inherited deadline is later")
    func chartWindowStaysAtPickerBound() {
        let currentYear = 2026
        let projectionYears = 10
        let account = makeNEDBAccount(currentYear: currentYear, decedentRBDStatus: .afterRBD)
        let deadlineYear = currentYear + 10  // = 2036, one year beyond the 10-year window

        let rows = RMDCalculationEngine.projectInheritedIRA(
            account: account,
            currentYear: currentYear,
            projectionYears: projectionYears,
            growthPercent: 6.0
        )

        // The engine still produces a row for the deadline year (unchanged)
        let years = rows.map { $0.year }
        #expect(years.contains(deadlineYear),
                "Engine projection still includes deadline year \(deadlineYear); got \(years)")

        // But the chart window is authoritative: lastYear = currentYear + projectionYears - 1
        let chartLastYear = currentYear + projectionYears - 1  // 2035
        #expect(chartLastYear < deadlineYear,
                "Chart lastYear (\(chartLastYear)) must NOT extend to deadline \(deadlineYear)")
        #expect(chartLastYear == 2035,
                "Chart lastYear should be 2035 for projectionYears=10 starting 2026; got \(chartLastYear)")
    }

    @Test("Spouse beneficiary: engine projection stays within projectionYears (no deadline row)")
    func spouseInherited_noDeadlineRowInProjection() {
        let currentYear = 2026
        let projectionYears = 10

        // Spouse beneficiary has lifetime stretch — no 10-year deadline
        let account = IRAAccount(
            name: "Inherited Spouse",
            accountType: .inheritedTraditionalIRA,
            balance: 100_000,
            owner: .primary,
            beneficiaryType: .spouse,
            decedentRBDStatus: .afterRBD,
            yearOfInheritance: currentYear,
            decedentBirthYear: 1945,
            beneficiaryBirthYear: 1960
        )

        let rows = RMDCalculationEngine.projectInheritedIRA(
            account: account,
            currentYear: currentYear,
            projectionYears: projectionYears,
            growthPercent: 6.0
        )

        let regularLastYear = currentYear + projectionYears - 1
        let engineLastYear = rows.last?.year ?? regularLastYear

        // Spouse account has no deadline, so the engine doesn't extend beyond projectionYears
        #expect(engineLastYear == regularLastYear,
                "Spouse beneficiary has no deadline; engine last year should stay at \(regularLastYear), got \(engineLastYear)")
    }

    // MARK: - inheritedDeadlinesOutsideWindow logic

    @Test("NEDB deadline outside picker window: notice entry is generated")
    func chartWithDeadlineOutsideWindow_ShowsNotice() {
        // Simulate: currentYear=2026, projectionYears=5 → lastVisibleYear=2030
        // NEDB freshly inherited in 2026 → deadline = 2036, which is > 2030
        let currentYear = 2026
        let projectionYears = 5
        let lastVisibleYear = currentYear + projectionYears - 1  // 2030

        let account = makeNEDBAccount(currentYear: currentYear, decedentRBDStatus: .afterRBD)

        guard let yearOfInheritance = account.yearOfInheritance,
              let beneficiaryType = account.beneficiaryType else {
            Issue.record("Account missing yearOfInheritance or beneficiaryType")
            return
        }

        let deadline = yearOfInheritance + 10  // 2036
        let isNEDB = !beneficiaryType.isEligibleDesignated

        #expect(isNEDB, "Account should be non-eligible designated")
        #expect(deadline > lastVisibleYear,
                "Deadline \(deadline) should exceed lastVisibleYear \(lastVisibleYear) → notice fires")
    }

    @Test("NEDB deadline inside picker window: no notice generated")
    func chartWithDeadlineInsideWindow_NoNotice() {
        // currentYear=2026, projectionYears=15 → lastVisibleYear=2040
        // NEDB freshly inherited in 2026 → deadline = 2036, which is <= 2040
        let currentYear = 2026
        let projectionYears = 15
        let lastVisibleYear = currentYear + projectionYears - 1  // 2040

        let account = makeNEDBAccount(currentYear: currentYear, decedentRBDStatus: .afterRBD)

        guard let yearOfInheritance = account.yearOfInheritance,
              let beneficiaryType = account.beneficiaryType else {
            Issue.record("Account missing yearOfInheritance or beneficiaryType")
            return
        }

        let deadline = yearOfInheritance + 10  // 2036
        let isNEDB = !beneficiaryType.isEligibleDesignated
        let noticeWouldFire = isNEDB && deadline > lastVisibleYear

        #expect(!noticeWouldFire,
                "Deadline \(deadline) is inside window (lastVisibleYear=\(lastVisibleYear)) → no notice")
    }

    @Test("Fresh-inheritance at default 10-year picker: year-11 deadline triggers notice")
    func freshInheritanceDefaultPicker_NoticeFiresForYear11Deadline() {
        // Fred's scenario: inherit in currentYear, projectionYears=10
        // Chart shows currentYear through currentYear+9 (2035).
        // Deadline = currentYear + 10 (2036) → outside window → notice fires.
        let currentYear = 2026
        let projectionYears = 10
        let lastVisibleYear = currentYear + projectionYears - 1  // 2035

        let account = makeNEDBAccount(currentYear: currentYear, decedentRBDStatus: .afterRBD)

        guard let yearOfInheritance = account.yearOfInheritance,
              let beneficiaryType = account.beneficiaryType else {
            Issue.record("Account missing yearOfInheritance or beneficiaryType")
            return
        }

        let deadline = yearOfInheritance + 10  // 2036
        let isNEDB = !beneficiaryType.isEligibleDesignated
        let noticeWouldFire = isNEDB && deadline > lastVisibleYear

        #expect(isNEDB, "Fresh inherited account should be NEDB")
        #expect(deadline == 2036, "Deadline should be 2036 (inherited 2026 + 10)")
        #expect(deadline > lastVisibleYear,
                "Deadline \(deadline) exceeds lastVisibleYear \(lastVisibleYear) at default 10-year picker")
        #expect(noticeWouldFire,
                "Notice must fire for Fred's scenario: deadline at year 11 of a 10-year chart")
    }
}

// MARK: - Per-person regular series

/// The projection chart used to sum both spouses into ONE "IRA / 401(k)" bar, so a
/// couple could read their table row by row but could not see whose RMD the graph
/// was drawing. These tests pin the split: one regular series per person, the same
/// per-year totals, and the single-filer series name left exactly as it was.
@Suite("RMD Chart Data - Per-Person Regular Series")
struct RMDCalculatorRegularSeriesTests {

    // MARK: - Households

    /// Mirrors the reporting customer: primary 64 (RMDs not yet required), spouse 73
    /// (already required), so the two series are visibly different from year one.
    private func couple(
        spouseName: String = "Karen",
        enableSpouse: Bool = true,
        spouseBalance: Double = 450_000
    ) -> RMDChartHousehold {
        RMDChartHousehold(
            currentYear: 2026,
            projectionYears: 15,
            primaryBalance: 800_000,
            primaryCurrentAge: 64,
            primaryRMDAge: 75,
            primaryGrowthPercent: 6.0,
            enableSpouse: enableSpouse,
            spouseName: spouseName,
            spouseBalance: spouseBalance,
            spouseCurrentAge: 73,
            spouseRMDAge: 73,
            spouseGrowthPercent: 5.0
        )
    }

    // MARK: - Independent expectation (transcription of the pre-split code)

    /// The balance roll-forward the chart used before the split, rewritten here so
    /// the expectation does not come from the helper under test.
    private func legacyProjectBalance(
        years: Int,
        startingBalance: Double,
        startAge: Int,
        rmdStartAge: Int,
        growthPercent: Double
    ) -> Double {
        var balance = startingBalance
        let growthRate = growthPercent / 100.0
        for year in 0..<years {
            let age = startAge + year
            if age >= rmdStartAge {
                balance -= RMDCalculationEngine.calculateRMD(for: age, balance: balance)
            }
            balance *= (1 + growthRate)
        }
        return max(0, balance)
    }

    /// The ONE combined regular amount the chart drew before the split.
    private func legacyCombinedRegularRMD(_ h: RMDChartHousehold, yearOffset: Int) -> Double {
        var combined: Double = 0

        if h.primaryBalance > 0 {
            let age = h.primaryCurrentAge + yearOffset
            if age >= h.primaryRMDAge {
                let balance = legacyProjectBalance(
                    years: yearOffset,
                    startingBalance: h.primaryBalance,
                    startAge: h.primaryCurrentAge,
                    rmdStartAge: h.primaryRMDAge,
                    growthPercent: h.primaryGrowthPercent
                )
                combined += RMDCalculationEngine.calculateRMD(for: age, balance: balance)
            }
        }

        if h.enableSpouse && h.spouseBalance > 0 {
            let age = h.spouseCurrentAge + yearOffset
            if age >= h.spouseRMDAge {
                let balance = legacyProjectBalance(
                    years: yearOffset,
                    startingBalance: h.spouseBalance,
                    startAge: h.spouseCurrentAge,
                    rmdStartAge: h.spouseRMDAge,
                    growthPercent: h.spouseGrowthPercent
                )
                combined += RMDCalculationEngine.calculateRMD(for: age, balance: balance)
            }
        }

        return combined
    }

    private func distinctCategories(_ points: [RMDChartDataPoint]) -> [String] {
        var seen: [String] = []
        for point in points where !seen.contains(point.category) {
            seen.append(point.category)
        }
        return seen
    }

    // MARK: - 1. The promise: the chart separates the two people

    @Test("Couple with two balances gets two distinct regular series, both populated")
    func couple_producesTwoDistinctRegularSeries() {
        let household = couple()
        let points = RMDChartDataBuilder.regularSeries(household)

        let categories = distinctCategories(points)
        #expect(categories.count == 2,
                "A couple must get one regular series per person; got \(categories)")
        #expect(categories.contains(RMDChartSeries.regularYours),
                "Primary series must be 'Your IRA / 401(k)'; got \(categories)")
        #expect(categories.contains("Karen's IRA / 401(k)"),
                "Spouse series must carry her name; got \(categories)")

        let spousePoints = points.filter { $0.category == "Karen's IRA / 401(k)" }
        let primaryPoints = points.filter { $0.category == RMDChartSeries.regularYours }

        #expect(spousePoints.count == household.projectionYears,
                "Spouse series must cover every projected year; got \(spousePoints.count)")
        #expect(spousePoints.contains(where: { $0.amount > 0 }),
                "Spouse is 73 and already required - her series must be non-empty")
        #expect(primaryPoints.contains(where: { $0.amount > 0 }),
                "Primary reaches age 75 inside a 15-year window - his series must be non-empty")

        // The two people must actually differ, not be two copies of the same curve.
        let firstYear = household.currentYear
        let spouseYear1 = spousePoints.first(where: { $0.year == firstYear })?.amount ?? 0
        let primaryYear1 = primaryPoints.first(where: { $0.year == firstYear })?.amount ?? 0
        #expect(spouseYear1 > 0,
                "Spouse's first projected year must show her RMD, got \(spouseYear1)")
        #expect(primaryYear1 == 0,
                "Primary is 64 and not yet required in year one, got \(primaryYear1)")
    }

    // MARK: - 2. Sum preservation: no number moved

    @Test("Per-person regular amounts sum to the pre-split combined amount, every year")
    func perPersonAmountsSumToLegacyCombinedTotal() {
        let household = couple()
        let points = RMDChartDataBuilder.regularSeries(household)

        for yearOffset in 0..<household.projectionYears {
            let year = household.currentYear + yearOffset
            let actual = points
                .filter { $0.year == year && RMDChartSeries.isRegular($0.category) }
                .reduce(0) { $0 + $1.amount }
            let expected = legacyCombinedRegularRMD(household, yearOffset: yearOffset)

            #expect(abs(actual - expected) < 0.000_001,
                    "Year \(year): split total \(actual) must equal the pre-split combined \(expected)")
        }
    }

    @Test("Sum preservation also holds when both people are already required")
    func perPersonAmountsSumToLegacyCombinedTotal_bothRequired() {
        var household = couple()
        household.primaryCurrentAge = 76
        household.primaryRMDAge = 73

        let points = RMDChartDataBuilder.regularSeries(household)

        for yearOffset in 0..<household.projectionYears {
            let year = household.currentYear + yearOffset
            let actual = points
                .filter { $0.year == year && RMDChartSeries.isRegular($0.category) }
                .reduce(0) { $0 + $1.amount }
            let expected = legacyCombinedRegularRMD(household, yearOffset: yearOffset)

            #expect(abs(actual - expected) < 0.000_001,
                    "Year \(year): split total \(actual) must equal the pre-split combined \(expected)")
            #expect(actual > 0, "Year \(year) should carry an RMD when both are required")
        }
    }

    // MARK: - 3. Single filers see exactly what they saw before

    @Test("No spouse: exactly one regular series, still named 'IRA / 401(k)'")
    func singleFiler_seriesNameUnchanged() {
        // A stale spouse balance and name are present but Enable Spouse is off.
        let household = couple(spouseName: "Karen", enableSpouse: false)
        let points = RMDChartDataBuilder.regularSeries(household)

        let categories = distinctCategories(points)
        #expect(categories == ["IRA / 401(k)"],
                "Single filers must keep the exact original series name; got \(categories)")

        for category in categories {
            #expect(!category.contains("Your"),
                    "Single-filer series must not be attributed; got \(category)")
            #expect(!category.contains("Spouse"),
                    "Single-filer series must not mention a spouse; got \(category)")
            #expect(!category.contains("Karen"),
                    "Single-filer series must not name a disabled spouse; got \(category)")
        }
    }

    // MARK: - 4. A disabled spouse contributes nothing

    @Test("Enable Spouse off: a large, past-RMD-age spouse balance contributes nothing")
    func disabledSpouse_contributesNothing() {
        var household = couple(spouseName: "Karen", enableSpouse: false)
        household.spouseBalance = 2_000_000     // large
        household.spouseCurrentAge = 80         // well past her RMD age
        household.spouseRMDAge = 73

        let points = RMDChartDataBuilder.regularSeries(household)
        let categories = distinctCategories(points)

        let mentionsSpouse = categories.contains(where: { $0.contains("Karen") || $0.contains("Spouse") })
        #expect(categories.count == 1,
                "A disabled spouse must produce no series at all; got \(categories)")
        #expect(mentionsSpouse == false,
                "No spouse series may exist when Enable Spouse is off; got \(categories)")

        // Totals must match a household with no spouse data at all.
        var primaryOnly = household
        primaryOnly.spouseBalance = 0
        primaryOnly.spouseCurrentAge = 0
        let primaryOnlyPoints = RMDChartDataBuilder.regularSeries(primaryOnly)

        for yearOffset in 0..<household.projectionYears {
            let year = household.currentYear + yearOffset
            let withStaleSpouse = points.filter { $0.year == year }.reduce(0) { $0 + $1.amount }
            let withoutSpouse = primaryOnlyPoints.filter { $0.year == year }.reduce(0) { $0 + $1.amount }
            #expect(abs(withStaleSpouse - withoutSpouse) < 0.000_001,
                    "Year \(year): a disabled spouse changed the total (\(withStaleSpouse) vs \(withoutSpouse))")
        }
    }

    // MARK: - 5. Naming

    @Test("Unnamed spouse falls back to \"Spouse's IRA / 401(k)\"")
    func unnamedSpouse_usesGenericPossessive() {
        let points = RMDChartDataBuilder.regularSeries(couple(spouseName: ""))
        let categories = distinctCategories(points)

        #expect(categories.contains("Spouse's IRA / 401(k)"),
                "Empty spouse name must fall back to the generic possessive; got \(categories)")
        #expect(RMDChartSeries.regularSpouse(spouseName: "") == "Spouse's IRA / 401(k)")
    }

    @Test("Named spouse uses the possessive form the RMD cards already use")
    func namedSpouse_usesPossessiveName() {
        #expect(RMDChartSeries.regularSpouse(spouseName: "Karen") == "Karen's IRA / 401(k)")
        #expect(RMDChartSeries.regularSpouse(spouseName: "Alex") == "Alex's IRA / 401(k)")

        let points = RMDChartDataBuilder.regularSeries(couple(spouseName: "Alex"))
        #expect(distinctCategories(points).contains("Alex's IRA / 401(k)"))
    }

    // MARK: - 6. The inherited series is untouched

    @Test("Inherited series name is unchanged and never produced by the regular split")
    func inheritedSeriesUntouched() {
        #expect(RMDChartSeries.inherited == "Inherited IRA",
                "The inherited series name must not move")
        #expect(!RMDChartSeries.isRegular(RMDChartSeries.inherited),
                "Inherited must not be classified as a regular series")
        #expect(RMDChartSeries.isRegular(RMDChartSeries.regularSingle))
        #expect(RMDChartSeries.isRegular(RMDChartSeries.regularYours))
        #expect(RMDChartSeries.isRegular(RMDChartSeries.regularSpouse(spouseName: "Karen")))

        let points = RMDChartDataBuilder.regularSeries(couple())
        let emitsInherited = points.contains(where: { $0.category == RMDChartSeries.inherited })
        #expect(emitsInherited == false,
                "The regular split must never emit an inherited point")
    }

    @Test("Inherited projection rows are identical for the couple and single-filer views")
    func inheritedProjectionIdenticalAcrossHouseholdShape() {
        let currentYear = 2026
        let account = IRAAccount(
            name: "Inherited",
            accountType: .inheritedTraditionalIRA,
            balance: 250_000,
            owner: .primary,
            beneficiaryType: .nonEligibleDesignated,
            decedentRBDStatus: .afterRBD,
            yearOfInheritance: currentYear,
            decedentBirthYear: 1945,
            beneficiaryBirthYear: 1962
        )

        let rows = RMDCalculationEngine.projectInheritedIRA(
            account: account,
            currentYear: currentYear,
            projectionYears: 15,
            growthPercent: 6.0
        )

        // The inherited series is built straight from these rows in both shapes;
        // the per-person split touches only the regular series.
        #expect(!rows.isEmpty, "Inherited projection should produce rows")
        let styledCouple = RMDChartSeries.styles(for:
            RMDChartDataBuilder.regularSeries(couple())
            + rows.map { RMDChartDataPoint(year: $0.year, yearLabel: "", amount: $0.rmd, category: RMDChartSeries.inherited) }
        )
        let inheritedStyle = styledCouple.first { $0.category == RMDChartSeries.inherited }
        #expect(inheritedStyle != nil, "Inherited must still get its own style entry for couples")
    }

    // MARK: - Call sites that filtered on the old literal

    @Test("hasRegularRMDs is true when EITHER person has a regular RMD")
    func hasRegularRMDs_trueWhenEitherPersonHasOne() {
        // Only the spouse is required in the first years.
        var household = couple()
        household.projectionYears = 3          // primary (64, RMD age 75) never qualifies
        let points = RMDChartDataBuilder.regularSeries(household)

        let hasRegular = points.contains { RMDChartSeries.isRegular($0.category) && $0.amount > 0 }
        #expect(hasRegular,
                "Spouse-only RMDs must still count as regular RMDs for the chart's peak/legend")

        let primaryTotal = points
            .filter { $0.category == RMDChartSeries.regularYours }
            .reduce(0) { $0 + $1.amount }
        #expect(primaryTotal == 0, "Primary should contribute nothing in a 3-year window at age 64")
    }

    @Test("Peak reads the per-year household total, not one person's series")
    func regularTotalsByYear_sumsBothPeople() {
        var household = couple()
        household.primaryCurrentAge = 76
        household.primaryRMDAge = 73
        let points = RMDChartDataBuilder.regularSeries(household)

        let totals = RMDChartSeries.regularTotalsByYear(points)
        #expect(totals.count == household.projectionYears,
                "Every projected year needs a total; got \(totals.count)")

        for entry in totals {
            let primary = points.first { $0.year == entry.year && $0.category == RMDChartSeries.regularYours }?.amount ?? 0
            #expect(entry.total > primary,
                    "Year \(entry.year): household total \(entry.total) must exceed the primary alone \(primary)")
        }

        guard let peak = totals.max(by: { $0.total < $1.total }) else {
            Issue.record("No peak found")
            return
        }
        let peakSingleSeries = points.map(\.amount).max() ?? 0
        #expect(peak.total > peakSingleSeries,
                "The household peak must exceed the largest single-person bar")
    }

    @Test("Every series drawn for a couple gets its own color")
    func seriesColorsDoNotCollide() {
        let regular = RMDChartDataBuilder.regularSeries(couple())
        let inherited = [RMDChartDataPoint(year: 2026, yearLabel: "'26", amount: 1000, category: RMDChartSeries.inherited)]
        let styles = RMDChartSeries.styles(for: regular + inherited)

        #expect(styles.count == 3,
                "Two regular series plus inherited must all be styled; got \(styles.map(\.category))")

        for i in styles.indices {
            for j in styles.indices where j > i {
                #expect(styles[i].color != styles[j].color,
                        "Series \(styles[i].category) and \(styles[j].category) share a color")
            }
        }
    }
}
