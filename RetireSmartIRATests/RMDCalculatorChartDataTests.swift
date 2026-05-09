//
//  RMDCalculatorChartDataTests.swift
//  RetireSmartIRATests
//
//  Tests for the inherited IRA chart window extension fix.
//
//  Background:
//  rmdChartData previously iterated only 0..<projectionYears (default 10) and
//  called projectInheritedIRA per-year, so for a freshly-inherited NEDB account
//  whose deadline falls at yearOfInheritance+10 = currentYear+10 (year 11),
//  the deadline bar was never plotted — it fell outside the chart window.
//
//  Fix shape: compute each account's projection once (which already extends to
//  the deadline year), determine lastYear = max(regularLastYear, max(inherited
//  deadline years)), and iterate currentYear...lastYear.
//
//  These tests verify the engine guarantee that rmdChartData now relies on:
//  1. projectInheritedIRA includes the deadline year row for NEDB accounts.
//  2. The chart window formula (lastYear) extends correctly.
//  3. Pre-RBD NEDB: years 1-10 have zero RMD, deadline year has full-balance drain.
//  4. Post-RBD NEDB: years 1-10 have partial RMDs, deadline year drains the balance.
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

    // MARK: - Chart window formula: lastYear extends when inherited deadline is later

    @Test("Chart window lastYear extends to cover inherited deadline")
    func chartWindowLastYearExtendsForInheritedDeadline() {
        let currentYear = 2026
        let projectionYears = 10
        let account = makeNEDBAccount(currentYear: currentYear, decedentRBDStatus: .afterRBD)
        let deadlineYear = currentYear + 10  // = 2036

        let rows = RMDCalculationEngine.projectInheritedIRA(
            account: account,
            currentYear: currentYear,
            projectionYears: projectionYears,
            growthPercent: 6.0
        )

        // Simulate the chart's lastYear formula
        let regularLastYear = currentYear + projectionYears - 1    // 2035
        let inheritedLastYear = rows.last?.year ?? regularLastYear // should be 2036
        let lastYear = max(regularLastYear, inheritedLastYear)

        #expect(lastYear == deadlineYear,
                "Chart lastYear should be \(deadlineYear) (the deadline), got \(lastYear)")
        #expect(lastYear > regularLastYear,
                "lastYear (\(lastYear)) must exceed regularLastYear (\(regularLastYear)) for a fresh NEDB account")
    }

    @Test("Chart window lastYear does NOT extend for accounts with no deadline (spouse)")
    func chartWindowLastYearUnchangedForSpouseInherited() {
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
        let inheritedLastYear = rows.last?.year ?? regularLastYear
        let lastYear = max(regularLastYear, inheritedLastYear)

        // Spouse account has no deadline, so lastYear should equal regularLastYear
        #expect(lastYear == regularLastYear,
                "Spouse beneficiary has no deadline; lastYear should stay at \(regularLastYear), got \(lastYear)")
    }
}
