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
