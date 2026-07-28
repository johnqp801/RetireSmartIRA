//
//  InfeasibleYearPresentationTests.swift
//  RetireSmartIRATests
//
//  V2.3: an infeasible year must be visible and explained, not silently folded into
//  totals as though the plan were fundable. These pin the PRESENTATION surfaces (the
//  ladder row, the plan-level headline, and the CPA briefing), not the engine flags.
//

import Testing
import Foundation
import SwiftUI
@testable import RetireSmartIRA

/// Shared builder. `underfunded` carries THIS year's own shortfall; the two flags are
/// independent because a later failure is both infeasible itself AND downstream of the first.
private func makeYear(_ y: Int, shortfall: Double? = nil,
                      infeasible: Bool = false, dependent: Bool = false) -> YearRecommendation {
    YearRecommendation(
        year: y, agi: 200_000, acaMagi: nil, irmaaMagi: nil,
        taxableIncome: 180_000,
        taxBreakdown: TaxBreakdown(federal: 40_000, state: 8_000, irmaa: 0,
                                   acaPremiumImpact: 0, niit: 0),
        endOfYearBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0),
        actions: [],
        underfunded: shortfall,
        executedRothConversion: 100_000,
        isInfeasible: infeasible,
        dependsOnInfeasibleYear: dependent)
}

/// A plan that fails in 2031 and drags 2032 and 2033 with it. 2032 fails on its own too;
/// 2033 does not, which is the distinction the copy must preserve.
private let brokenPath: [YearRecommendation] = [
    makeYear(2030),
    makeYear(2031, shortfall: 8_420, infeasible: true),
    makeYear(2032, shortfall: 12_100, infeasible: true, dependent: true),
    makeYear(2033, dependent: true),
]

@Suite("Infeasible-year presentation")
struct InfeasibleYearPresentationTests {

    // MARK: - The explanation itself

    @Test("Explanation states amount, non-reduction, and downstream effect")
    func explanationIsComplete() {
        let y = makeYear(2031, shortfall: 8_420, infeasible: true)
        let text = V2Disclosures.infeasibleYearExplanation(shortfall: y.underfunded ?? 0)
        #expect(text.contains("8,420"))
        #expect(text.lowercased().contains("not reduced"))
        #expect(text.lowercased().contains("later years"))
    }

    @Test("The depends-on-earlier-failure note says nothing failed HERE")
    func dependentNoteIsItsOwnMessage() {
        let text = V2Disclosures.dependsOnInfeasibleYearExplanation
        #expect(text.lowercased().contains("earlier year"),
                "must attribute the failure to an EARLIER year, not this one")
        #expect(text.lowercased().contains("not reliable"),
                "must state the consequence: this year's figures cannot be trusted")
        // Collapsing the two states would mean claiming a shortfall this year did not have.
        #expect(text.contains("shortfall") == false)
        #expect(text.contains("\u{2014}") == false, "no em dash")
    }

    @Test("The explanation claims no exclusion from comparison, because none happens")
    func explanationPromisesNoExclusion() {
        // The optimizer ranks candidates on objective cost alone and reads none of the
        // feasibility flags, so an infeasible strategy is NOT dropped from lifetime
        // comparisons. This copy is user facing and must not promise behavior that does
        // not exist. If exclusion is ever implemented, delete this test with the fix.
        let text = V2Disclosures.infeasibleYearExplanation(shortfall: 8_420)
        #expect(text.lowercased().contains("excluded") == false)
        #expect(text.lowercased().contains("comparison") == false)
        #expect(text.hasSuffix("Later years that build on this year's balances are not reliable."))
    }

    // MARK: - Per-row presentation (LadderRow drives the year table)

    @Test("The row that FAILED carries the full explanation, with its own amount")
    func failingRowCarriesFullExplanation() {
        let row = LadderRow(makeYear(2031, shortfall: 8_420, infeasible: true))
        #expect(row.isFullyFunded == false)
        let text = row.fundingWarningLabel
        // Pin the substance a user depends on, not merely that a string exists.
        #expect(text.contains("8,420"), "the row must state this year's own shortfall")
        #expect(text.lowercased().contains("not reduced"),
                "the row must say the requested conversion was NOT auto-reduced")
        #expect(text.lowercased().contains("later years"),
                "the row must say downstream years are unreliable")
    }

    @Test("A year that only INHERITS unreliability gets the other message")
    func dependentRowGetsDistinctCopy() {
        let row = LadderRow(makeYear(2033, dependent: true))
        #expect(row.isFullyFunded == false)
        let text = row.fundingWarningLabel
        #expect(text == V2Disclosures.dependsOnInfeasibleYearExplanation)
        // The two states must not be collapsed: this year had no shortfall of its own.
        #expect(text.contains("$") == false,
                "a year that did not fail must not be given a dollar shortfall")
        #expect(text != V2Disclosures.infeasibleYearExplanation(shortfall: 0))
    }

    @Test("A year that fails on its own reports its OWN failure, not the inherited one")
    func selfFailureWinsOverInheritance() {
        // 2032 is both isInfeasible and dependsOnInfeasibleYear. Reporting only the
        // inherited message would hide a $12,100 shortfall the household actually has.
        let row = LadderRow(brokenPath[2])
        #expect(row.isInfeasible)
        #expect(row.dependsOnInfeasibleYear)
        #expect(row.fundingWarningLabel.contains("12,100"))
    }

    @Test("A funded row shows no funding warning at all")
    func fundedRowIsSilent() {
        let row = LadderRow(makeYear(2030))
        #expect(row.isFullyFunded)
        #expect(row.fundingWarningLabel.isEmpty)
        #expect(row.showsFundingWarning == false)
    }

    // MARK: - Plan-level headline

    @Test("Summary counts the two states separately")
    func summarySeparatesTheTwoStates() {
        let s = FundingFeasibilitySummary(path: brokenPath)
        #expect(s.isFullyFunded == false)
        // 2031 and 2032 failed outright; 2033 only inherited. 2032 must NOT be double counted.
        #expect(s.infeasibleYears == [2031, 2032])
        #expect(s.dependentOnlyYears == [2033])
        // Pin the copy itself. `contains("2")` would pass on any string holding that digit.
        #expect(s.headline == "Not fully funded: 2 years cannot pay their modeled tax")
        #expect(s.detail == "The plan totals above include tax that available assets could not cover, so they do not describe an outcome this household can reach. 1 later year did not fail on its own but builds on balances the household could never have held, so its figures are not reliable either.")
    }

    @Test("A fully funded plan produces no headline")
    func fundedPlanIsSilent() {
        let s = FundingFeasibilitySummary(path: [makeYear(2030), makeYear(2031)])
        #expect(s.isFullyFunded)
        #expect(s.headline.isEmpty)
        #expect(s.detail.isEmpty)
        #expect(FundingFeasibilitySummary(path: []).isFullyFunded)
    }

    @Test("The headline does not reprint the row paragraph's sentences")
    func headlineDoesNotDuplicateTheRow() {
        let s = FundingFeasibilitySummary(path: brokenPath)
        let banner = s.headline + " " + s.detail
        let rowCopy = V2Disclosures.infeasibleYearExplanation(shortfall: 8_420)
            + " " + V2Disclosures.dependsOnInfeasibleYearExplanation
        // Both treatments appear in the same scroll view, so no substantial sentence may
        // appear in both. Short fragments are excluded so shared words do not trip this.
        let allSentences = rowCopy.split(separator: ".")
            .map { String($0).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        let sentences = allSentences.filter { $0.count > 25 }
        #expect(sentences.isEmpty == false, "guard against an empty comparison passing vacuously")
        // The length filter currently drops nothing. Pin that, so a future short duplicated
        // fragment cannot be silently filtered out of the comparison and slip through.
        let dropped = allSentences.filter { $0.count <= 25 }
        #expect(sentences.count == allSentences.count,
                "these sentences were dropped by the length filter and are no longer guarded against duplication: \(dropped)")
        for sentence in sentences {
            #expect(banner.contains(sentence) == false,
                    "plan-level headline repeats a row sentence: \(sentence)")
        }
    }

    @Test("No em dash in any new funding-feasibility copy")
    func noEmDash() {
        let s = FundingFeasibilitySummary(path: brokenPath)
        for text in [s.headline, s.detail,
                     V2Disclosures.dependsOnInfeasibleYearExplanation,
                     V2Disclosures.infeasibleYearExplanation(shortfall: 8_420),
                     LadderRow(brokenPath[1]).fundingWarningLabel] {
            #expect(text.contains("\u{2014}") == false, "no em dash: \(text)")
        }
    }

    @Test("Views build with an infeasible plan")
    @MainActor
    func viewsBuild() {
        _ = TaxFundingFeasibilityBanner(summary: FundingFeasibilitySummary(path: brokenPath)).body
        _ = LadderListView(rows: brokenPath.map { LadderRow($0) }).body
        #expect(true)
    }
}

// MARK: - CPA briefing

@Suite("Infeasible years in the CPA briefing")
struct InfeasibleYearBriefingTests {

    private func model(_ rows: [YearRecommendation]) -> CPABriefingModel {
        CPABriefingModel(
            preparedFor: "Test", taxYear: 2030, filingStatusLabel: "Single",
            stateLabel: "CA", primaryBirthYear: 1960,
            summary: PlanSummary(path: rows),
            comparison: PlanComparison(plan: rows, doingNothing: rows, heirSalary: 0,
                                       heirFilingStatus: .single, heirDrawdownYears: 10),
            yearRows: rows, frontier: nil, includeHeirs: false,
            assumptions: MultiYearAssumptions(),
            limitations: V2Disclosures.limitations,
            positioning: V2Disclosures.positioning)
    }

    @Test("Every affected year produces a warning, labeled by year")
    func warningsCoverEveryAffectedYear() {
        let w = model(brokenPath).infeasibilityWarnings
        #expect(w.count == 3, "2031, 2032, and 2033 are all affected; 2030 is not")
        #expect(w[0].hasPrefix("2031:"))
        #expect(w[1].hasPrefix("2032:"))
        #expect(w[2].hasPrefix("2033:"))
    }

    @Test("The warning tells a CPA the modeled tax was not actually payable")
    func warningsCarryTheSubstance() {
        let w = model(brokenPath).infeasibilityWarnings
        #expect(w[0].contains("8,420"), "the failing year's own shortfall must be stated")
        #expect(w[0].lowercased().contains("not reduced"),
                "a CPA must know the conversion was left as requested")
        #expect(w[1].contains("12,100"))
        // The inherited year is a different claim and must not borrow a shortfall.
        #expect(w[2] == "2033: " + V2Disclosures.dependsOnInfeasibleYearExplanation)
        #expect(w[2].contains("$") == false)
    }

    @Test("A fully funded plan adds nothing to the briefing")
    func fundedBriefingIsSilent() {
        let rows = [makeYear(2030), makeYear(2031)]
        #expect(model(rows).infeasibilityWarnings.isEmpty)
        let html = MultiYearCPABriefingHTML.build(model(rows))
        #expect(html.contains("Funding feasibility") == false)
    }

    @Test("The rendered briefing prints the warnings and the count")
    func briefingHTMLIncludesWarnings() {
        let html = MultiYearCPABriefingHTML.build(model(brokenPath))
        #expect(html.contains("Funding feasibility"),
                "the briefing needs its own heading; a CPA must not infer this from the tables")
        #expect(html.contains(MultiYearCPABriefingHTML.escapeForTest("8,420")))
        #expect(html.contains("2033"))
        #expect(html.contains(MultiYearCPABriefingHTML.escapeForTest(
            FundingFeasibilitySummary(path: brokenPath).headline)))
        // It has to lead the document, not hide under Limitations at the very end.
        let feasibilityIndex = html.range(of: "Funding feasibility")?.lowerBound
        let limitationsIndex = html.range(of: "<h2>Limitations</h2>")?.lowerBound
        #expect(feasibilityIndex != nil && limitationsIndex != nil)
        if let f = feasibilityIndex, let l = limitationsIndex { #expect(f < l) }
    }
}
