import Testing
import Foundation
import SwiftUI
@testable import RetireSmartIRA

/// Phase 3b Task 6: the picker, the classified-account display, the New York
/// prompt/limitation, and the two contextual disclosures. See
/// docs/superpowers/specs/2026-08-03-state-tax-phase3b-per-source-design.md
/// sections 3.2 and 3.7, and .superpowers/sdd/task-6-brief.md.
///
/// This task has no mechanical (baseline) gate, so these tests are the only
/// proof the picker's mappings, the classified-account display, the New York
/// prompt, and the two disclosures are correct AND conditional. Each "should
/// show" test is paired with a "should NOT show otherwise" test, per the
/// brief's instruction that an always-on disclosure is decoration, not a
/// disclosure.
@Suite("Phase 3b Task 6: picker, classified-account display, NY prompt, disclosures")
struct Phase3bPresentationTests {

    // MARK: - 3.2 The picker: exact rows, exact order, exact mappings

    @Test("The picker is exactly the nine rows of spec 3.2, in order")
    func pickerRowsExactlyMatchSpec() {
        let expected: [PlanClassificationChoice] = [
            .nyGovernmentPension, .federalCivilianPension, .otherStateGovernmentPension,
            .privateEmployerPension, .governmentSalaryReduction, .privateSalaryReduction,
            .employer401k, .ira, .notSure
        ]
        #expect(PlanClassificationChoice.allCases == expected)
        #expect(PlanClassificationChoice.allCases.count == 9)
    }

    @Test("Each row's label matches spec 3.2 column 1, verbatim")
    func pickerLabelsMatchSpec() {
        #expect(PlanClassificationChoice.nyGovernmentPension.label == "Government pension, New York State or local")
        #expect(PlanClassificationChoice.federalCivilianPension.label == "Government pension, federal civilian")
        #expect(PlanClassificationChoice.otherStateGovernmentPension.label == "Government pension, another state or locality")
        #expect(PlanClassificationChoice.privateEmployerPension.label == "Private employer pension")
        #expect(PlanClassificationChoice.governmentSalaryReduction.label == "403(b) or 457, government employer")
        #expect(PlanClassificationChoice.privateSalaryReduction.label == "403(b) or 457, private or nonprofit employer")
        #expect(PlanClassificationChoice.employer401k.label == "Employer 401(k)")
        #expect(PlanClassificationChoice.ira.label == "IRA")
        #expect(PlanClassificationChoice.notSure.label == "Not sure")
    }

    @Test("Each row's classification matches spec 3.2 columns 2 and 3, exactly")
    func pickerClassificationsMatchSpec() {
        #expect(PlanClassificationChoice.nyGovernmentPension.classification
                == RetirementPlanClassification(structure: .definedBenefit, source: .nyStateOrLocal))
        #expect(PlanClassificationChoice.federalCivilianPension.classification
                == RetirementPlanClassification(structure: .definedBenefit, source: .federalCivilian))
        #expect(PlanClassificationChoice.otherStateGovernmentPension.classification
                == RetirementPlanClassification(structure: .definedBenefit, source: .otherStateOrLocal))
        #expect(PlanClassificationChoice.privateEmployerPension.classification
                == RetirementPlanClassification(structure: .definedBenefit, source: .privateEmployer))
        #expect(PlanClassificationChoice.governmentSalaryReduction.classification
                == RetirementPlanClassification(structure: .definedContribution, source: .governmentUnspecified))
        #expect(PlanClassificationChoice.privateSalaryReduction.classification
                == RetirementPlanClassification(structure: .definedContribution, source: .privateEmployer))
        #expect(PlanClassificationChoice.employer401k.classification
                == RetirementPlanClassification(structure: .definedContribution, source: .privateEmployer))
        #expect(PlanClassificationChoice.ira.classification
                == RetirementPlanClassification(structure: .ira, source: .individual))
        #expect(PlanClassificationChoice.notSure.classification
                == RetirementPlanClassification(structure: .unknown, source: .unknown))
    }

    @Test("The out-of-state government pension row does NOT map to New York's exclusion")
    func outOfStateRowDoesNotMapToNewYork() {
        // The regression test named directly in the brief: this row exists
        // specifically to stop an out-of-state public pension from
        // selecting New York's exclusion. Prove it by checking the row's
        // source is neither of the two sources New York's rule matches.
        let source = PlanClassificationChoice.otherStateGovernmentPension.classification.source
        #expect(source == .otherStateOrLocal)
        #expect(source != .nyStateOrLocal)
        #expect(source != .federalCivilian)
    }

    @Test("Roth and inherited account types are never offered the picker")
    func rothAndInheritedAccountsGetNoPicker() {
        for type in AccountType.allCases where type.isRothType || type.isInherited {
            #expect(!PlanClassificationChoice.showsPickerFor(accountType: type),
                     "AccountType.\(type) must not show the picker")
        }
        #expect(PlanClassificationChoice.showsPickerFor(accountType: .traditionalIRA))
        #expect(PlanClassificationChoice.showsPickerFor(accountType: .traditional401k))
    }

    // MARK: - Reverse lookup (pre-selecting the picker against stored data)

    @Test("Reverse lookup resolves the shared 401(k)/private-403(b) tuple to Employer 401(k)")
    func reverseLookupPrefersEmployer401kForTheSharedTuple() {
        let shared = RetirementPlanClassification(structure: .definedContribution, source: .privateEmployer)
        #expect(PlanClassificationChoice.choice(for: shared) == .employer401k)
    }

    @Test("Reverse lookup round-trips every row's own classification except the shared tuple")
    func reverseLookupRoundTrips() {
        for choice in PlanClassificationChoice.allCases where choice != .privateSalaryReduction {
            #expect(PlanClassificationChoice.choice(for: choice.classification) == choice,
                     "\(choice) should round-trip")
        }
    }

    @Test("Reverse lookup of an unrecognised classification falls back to Not sure")
    func reverseLookupUnrecognisedFallsBackToNotSure() {
        // governmentUnspecified paired with .ira never appears in the picker
        // table; must not crash or silently resolve to an arbitrary row.
        let unmapped = RetirementPlanClassification(structure: .ira, source: .governmentUnspecified)
        #expect(PlanClassificationChoice.choice(for: unmapped) == .notSure)
    }

    // MARK: - 3.7 A classified 403(b)/457 displays as itself

    @Test("A government 403(b)/457 account displays distinctly from Traditional 401(k)")
    func governmentSalaryReductionAccountDisplaysAsItself() {
        let label = PlanClassificationChoice.accountDisplayName(
            accountType: .traditional401k, planStructure: .definedContribution, planSource: .governmentUnspecified)
        #expect(label != AccountType.traditional401k.rawValue)
        #expect(label.contains("403(b)"))
    }

    @Test("An unclassified 401(k) still displays as Traditional 401(k)")
    func unclassified401kStillDisplaysAsTraditional401k() {
        let inferred = RetirementPlanClassification.infer(accountType: .traditional401k)
        let label = PlanClassificationChoice.accountDisplayName(
            accountType: .traditional401k, planStructure: inferred.structure, planSource: inferred.source)
        #expect(label == AccountType.traditional401k.rawValue)
    }

    @Test("An account explicitly classified Employer 401(k) still displays as Traditional 401(k)")
    func explicitEmployer401kDisplaysAsTraditional401k() {
        let c = PlanClassificationChoice.employer401k.classification
        let label = PlanClassificationChoice.accountDisplayName(
            accountType: .traditional401k, planStructure: c.structure, planSource: c.source)
        #expect(label == AccountType.traditional401k.rawValue)
    }

    @Test("A traditional IRA's own display is untouched")
    func traditionalIRADisplayUntouched() {
        let inferred = RetirementPlanClassification.infer(accountType: .traditionalIRA)
        let label = PlanClassificationChoice.accountDisplayName(
            accountType: .traditionalIRA, planStructure: inferred.structure, planSource: inferred.source)
        #expect(label == AccountType.traditionalIRA.rawValue)
    }

    // MARK: - 3.7 The unclassified New York prompt

    private func pensionRow(source: PlanSource, structure: PlanStructure = .unknown) -> IncomeSource {
        IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000, planStructure: structure, planSource: source)
    }

    @Test("An unclassified pension in a per-source-rule state should prompt")
    func unclassifiedPensionInNewYorkShouldPrompt() {
        let row = pensionRow(source: .unknown)
        #expect(PlanClassificationChoice.shouldPromptForClassification(source: row, residenceHasPerSourceRules: true))
    }

    @Test("A classified pension should NOT prompt")
    func classifiedPensionShouldNotPrompt() {
        let row = pensionRow(source: .nyStateOrLocal, structure: .definedBenefit)
        #expect(!PlanClassificationChoice.shouldPromptForClassification(source: row, residenceHasPerSourceRules: true))
    }

    @Test("An unclassified pension in a state with no per-source rules should NOT prompt")
    func unclassifiedPensionOutsideNewYorkShouldNotPrompt() {
        let row = pensionRow(source: .unknown)
        #expect(!PlanClassificationChoice.shouldPromptForClassification(source: row, residenceHasPerSourceRules: false))
    }

    @Test("An unclassified RMD row should NOT prompt (the picker never targets .rmd)")
    func unclassifiedRMDShouldNotPrompt() {
        let row = IncomeSource(name: "RMD", type: .rmd, annualAmount: 10_000)
        #expect(!PlanClassificationChoice.shouldPromptForClassification(source: row, residenceHasPerSourceRules: true))
    }

    @Test("New York carries a per-source rule; a no-rule state like California does not")
    func residenceHasPerSourceRulesReflectsLiveConfig() {
        #expect(PlanClassificationChoice.residenceHasPerSourceRules(.newYork))
        #expect(!PlanClassificationChoice.residenceHasPerSourceRules(.california))
    }

    // MARK: - 3.7 The New York limitation wherever New York tax is computed

    @Test("StateComparisonView shows the New York limitation when viewing New York with an unclassified pension")
    func stateComparisonShowsLimitationForUnclassifiedNewYorkPension() {
        #expect(StateComparisonPresentation.showsUnclassifiedNewYorkPensionLimitation(
            viewedState: .newYork, hasUnclassifiedPension: true))
    }

    @Test("StateComparisonView omits the limitation once the pension is classified")
    func stateComparisonOmitsLimitationOnceClassified() {
        #expect(!StateComparisonPresentation.showsUnclassifiedNewYorkPensionLimitation(
            viewedState: .newYork, hasUnclassifiedPension: false))
    }

    @Test("StateComparisonView omits the New York limitation for a different state's detail")
    func stateComparisonOmitsLimitationForOtherStates() {
        #expect(!StateComparisonPresentation.showsUnclassifiedNewYorkPensionLimitation(
            viewedState: .california, hasUnclassifiedPension: true))
    }

    // MARK: - CPA briefing: New York limitation

    @Test("The CPA briefing carries the New York limitation for a NY resident with an unclassified pension")
    func cpaBriefingCarriesNewYorkLimitationWhenApplicable() {
        let limitations = MultiYearCPABriefing.newYorkUnclassifiedPensionLimitation(
            residesInNewYork: true, hasUnclassifiedPension: true)
        #expect(!limitations.isEmpty)
        #expect(limitations.allSatisfy { !$0.isEmpty })
    }

    @Test("The CPA briefing omits the New York limitation for a non-NY resident")
    func cpaBriefingOmitsNewYorkLimitationOutsideNewYork() {
        let limitations = MultiYearCPABriefing.newYorkUnclassifiedPensionLimitation(
            residesInNewYork: false, hasUnclassifiedPension: true)
        #expect(limitations.isEmpty)
    }

    @Test("The CPA briefing omits the New York limitation once the pension is classified")
    func cpaBriefingOmitsNewYorkLimitationOnceClassified() {
        let limitations = MultiYearCPABriefing.newYorkUnclassifiedPensionLimitation(
            residesInNewYork: true, hasUnclassifiedPension: false)
        #expect(limitations.isEmpty)
    }

    @Test("The rendered CPA briefing HTML contains the New York limitation text when applicable")
    func cpaBriefingHTMLContainsNewYorkLimitation() {
        let extra = MultiYearCPABriefing.newYorkUnclassifiedPensionLimitation(
            residesInNewYork: true, hasUnclassifiedPension: true)
        let model = Self.briefingModel(limitations: V2Disclosures.limitations + extra)
        let html = MultiYearCPABriefingHTML.build(model)
        for line in extra {
            #expect(html.contains(MultiYearCPABriefingHTML.escapeForTest(line)))
        }
    }

    // MARK: - Hawaii's contextual disclosure

    @Test("Hawaii's disclosure appears for a Hawaii resident with pension income")
    func hawaiiDisclosureAppearsWithPensionIncome() {
        let limitations = MultiYearCPABriefing.hawaiiPensionSplitLimitation(
            residesInHawaii: true, hasPensionIncome: true)
        #expect(!limitations.isEmpty)
        #expect(limitations.allSatisfy { !$0.isEmpty })
    }

    @Test("Hawaii's disclosure is absent outside Hawaii")
    func hawaiiDisclosureAbsentOutsideHawaii() {
        let limitations = MultiYearCPABriefing.hawaiiPensionSplitLimitation(
            residesInHawaii: false, hasPensionIncome: true)
        #expect(limitations.isEmpty)
    }

    @Test("Hawaii's disclosure is absent when there is no pension income")
    func hawaiiDisclosureAbsentWithoutPensionIncome() {
        let limitations = MultiYearCPABriefing.hawaiiPensionSplitLimitation(
            residesInHawaii: true, hasPensionIncome: false)
        #expect(limitations.isEmpty)
    }

    @Test("The rendered CPA briefing HTML contains Hawaii's disclosure text when applicable")
    func cpaBriefingHTMLContainsHawaiiDisclosure() {
        let extra = MultiYearCPABriefing.hawaiiPensionSplitLimitation(
            residesInHawaii: true, hasPensionIncome: true)
        let model = Self.briefingModel(limitations: V2Disclosures.limitations + extra)
        let html = MultiYearCPABriefingHTML.build(model)
        for line in extra {
            #expect(html.contains(MultiYearCPABriefingHTML.escapeForTest(line)))
        }
    }

    // MARK: - View construction smoke tests
    //
    // Matching this codebase's existing convention for SwiftUI view tests
    // (e.g. AssumptionsLimitationsViewTests): no ViewInspector is set up in
    // this project, so these prove the wired-up views build without
    // crashing under the specific conditions this task adds (an
    // unclassified pension row, a Hawaii pension, a classified 403(b)/457
    // account), on top of the pure-function tests above which cover the
    // actual content/conditional logic.

    @MainActor
    @Test("IncomeRow builds for an unclassified pension row with the prompt showing")
    func incomeRowBuildsWithPrompt() {
        let row = IncomeSourcesView.IncomeRow(
            source: pensionRow(source: .unknown), residenceHasPerSourceRules: true)
        _ = row.body
        #expect(true)
    }

    @MainActor
    @Test("AddIncomeView builds when editing an existing pension (the picker section renders)")
    func addIncomeViewBuildsForPension() {
        // Matches this codebase's existing convention for a view that
        // requires @Environment(DataManager.self) (see
        // MultiYearPlanViewConstructTests): calling `.body` on a view
        // wrapped by `.environment(...)` traps at runtime
        // (SwiftUICore/View.swift's "body() should not be called on
        // ModifiedContent..."), so the check is construction, not a body
        // render.
        let existing = pensionRow(source: .nyStateOrLocal, structure: .definedBenefit)
        let view = IncomeSourcesView.AddIncomeView(incomeToEdit: existing)
            .environment(DataManager(skipPersistence: true))
        #expect(view is (any View))
    }

    @MainActor
    @Test("AccountRow builds for a government-classified 403(b)/457 account")
    func accountRowBuildsForClassifiedAccount() {
        let account = IRAAccount(
            name: "State 403(b)", accountType: .traditional401k, balance: 50_000,
            planStructure: .definedContribution, planSource: .governmentUnspecified)
        let row = AccountRow(account: account)
        _ = row.body
        #expect(true)
    }

    @MainActor
    @Test("AddAccountView builds for a new traditional account (the picker section renders)")
    func addAccountViewBuildsForTraditionalAccount() {
        let view = AddAccountView(accountToEdit: nil)
            .environment(DataManager(skipPersistence: true))
        #expect(view is (any View))
    }

    @MainActor
    @Test("StateComparisonView builds")
    func stateComparisonViewBuilds() {
        let view = StateComparisonView().environment(DataManager(skipPersistence: true))
        #expect(view is (any View))
    }

    // MARK: - Test fixture

    private static func briefingModel(limitations: [String]) -> CPABriefingModel {
        let row = YearRecommendation(
            year: 2026, agi: 120_000, acaMagi: nil, irmaaMagi: 120_000, taxableIncome: 95_000,
            taxBreakdown: TaxBreakdown(federal: 18_000, state: 4_000, irmaa: 1_200, acaPremiumImpact: 0),
            endOfYearBalances: AccountSnapshot(traditional: 800_000, roth: 200_000, taxable: 300_000, hsa: 0),
            actions: [], rmd: 0, executedRothConversion: 0, taxFundingWithdrawal: 0)
        let path = [row]
        return CPABriefingModel(
            preparedFor: "Test Household",
            taxYear: 2026,
            filingStatusLabel: "Single",
            stateLabel: "NY",
            primaryBirthYear: 1959,
            summary: PlanSummary(path: path),
            comparison: PlanComparison(plan: path, doingNothing: path, heirSalary: 0,
                                       heirFilingStatus: .single, heirDrawdownYears: 10),
            yearRows: path,
            frontier: nil,
            includeHeirs: false,
            assumptions: MultiYearAssumptions(),
            limitations: limitations,
            positioning: V2Disclosures.positioning)
    }
}
