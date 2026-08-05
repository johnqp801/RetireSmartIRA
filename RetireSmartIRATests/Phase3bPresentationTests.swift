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

    /// Phase 5b Task 3 grew this list from nine rows to twelve. The three
    /// additions are INSERTED, not appended, so the relative order of the
    /// nine original rows is unchanged and no existing row's `rawValue` or
    /// `classification` moved. That "additive" property is what this test
    /// and `pickerAdditionIsPurelyAdditive` below assert separately: this
    /// one pins the full list, that one pins the nine originals in
    /// isolation, so a future edit that quietly re-tuples an existing row
    /// while updating this literal still fails.
    @Test("The picker is exactly the twelve rows of spec 3.2 as extended by Phase 5b, in order")
    func pickerRowsExactlyMatchSpec() {
        let expected: [PlanClassificationChoice] = [
            .nyGovernmentPension, .ownStateGovernmentPension, .federalCivilianPension,
            .uniformedServicesPension, .railroadRetirementPension,
            .otherStateGovernmentPension,
            .privateEmployerPension, .governmentSalaryReduction, .privateSalaryReduction,
            .employer401k, .ira, .notSure
        ]
        #expect(PlanClassificationChoice.allCases == expected)
        #expect(PlanClassificationChoice.allCases.count == 12)
    }

    /// The nine original rows keep their relative display order after the
    /// Phase 5b insertion. Filtering `allCases` down to them and comparing
    /// against spec 3.2's order proves the insertion reordered nothing,
    /// independently of wherever the three new rows were placed.
    @Test("Phase 5b's three new rows are additive: the nine spec-3.2 rows keep their relative order")
    func pickerAdditionIsPurelyAdditive() {
        let original: [PlanClassificationChoice] = [
            .nyGovernmentPension, .federalCivilianPension, .otherStateGovernmentPension,
            .privateEmployerPension, .governmentSalaryReduction, .privateSalaryReduction,
            .employer401k, .ira, .notSure
        ]
        let stillPresentInOrder = PlanClassificationChoice.allCases.filter { original.contains($0) }
        #expect(stillPresentInOrder == original)
    }

    /// CORRECTED after review: these raw values are NOT a persistence
    /// surface, and an earlier version of this comment wrongly said a rename
    /// would "orphan every row a user already saved". It would not.
    /// `PlanClassificationChoice` is a presentation type held only in
    /// `@State` (`AccountsView.swift`, `IncomeSourcesView.swift`) and is
    /// never encoded; what persists on `IncomeSource` and `IRAAccount` is
    /// the `RetirementPlanClassification` that `classification` returns, and
    /// `pickerClassificationsMatchSpec` above is what protects it.
    ///
    /// The test is kept for the smaller, true reason: `rawValue` is the
    /// case's `Identifiable` `id` and therefore its `ForEach`/`Picker` view
    /// identity, so pinning the nine names makes a rename during a future
    /// refactor a deliberate, reviewed edit rather than a silent one, and
    /// forecloses the day someone DOES decide to persist the picker's
    /// literal choice (which `accountDisplayName`'s doc comment already
    /// contemplates as the way to disambiguate the 401(k) / 403(b) pair).
    @Test("The nine original rows keep their raw values, which are their view identity")
    func originalRawValuesAreUnchanged() {
        #expect(PlanClassificationChoice.nyGovernmentPension.rawValue == "nyGovernmentPension")
        #expect(PlanClassificationChoice.federalCivilianPension.rawValue == "federalCivilianPension")
        #expect(PlanClassificationChoice.otherStateGovernmentPension.rawValue == "otherStateGovernmentPension")
        #expect(PlanClassificationChoice.privateEmployerPension.rawValue == "privateEmployerPension")
        #expect(PlanClassificationChoice.governmentSalaryReduction.rawValue == "governmentSalaryReduction")
        #expect(PlanClassificationChoice.privateSalaryReduction.rawValue == "privateSalaryReduction")
        #expect(PlanClassificationChoice.employer401k.rawValue == "employer401k")
        #expect(PlanClassificationChoice.ira.rawValue == "ira")
        #expect(PlanClassificationChoice.notSure.rawValue == "notSure")
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

    /// PROPOSED working copy, Phase 5b Task 3. Unlike the nine rows above,
    /// these three labels were NOT approved by John, and the Task 3 report
    /// lists them for renaming. This test exists so a rename is a deliberate
    /// two-file edit rather than a silent drift, and so that every row has a
    /// non-empty label whatever the eventual wording.
    @Test("Phase 5b's three new rows carry their PROPOSED working labels")
    func newPickerLabelsAreTheProposedWorkingCopy() {
        #expect(PlanClassificationChoice.ownStateGovernmentPension.label == "Government pension, my own state or locality")
        #expect(PlanClassificationChoice.uniformedServicesPension.label == "Military retired pay")
        #expect(PlanClassificationChoice.railroadRetirementPension.label == "Railroad Retirement benefits")
        for choice in PlanClassificationChoice.allCases {
            #expect(!choice.label.isEmpty, "\(choice) has no label")
        }
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

    /// The point of the addendum: a Kansas KPERS holder must be able to
    /// SELECT `ownStateOrLocal`. Before Task 3 the only government-pension
    /// option was `otherStateOrLocal`, the one source a correct Kansas rule
    /// must reject, so every Kansas golden case could have gone green while
    /// a real KPERS holder still received no exclusion.
    @Test("Phase 5b's three new rows write the three PlanSource cases Task 1 added")
    func newPickerRowsWriteTheNewPlanSources() {
        #expect(PlanClassificationChoice.ownStateGovernmentPension.classification
                == RetirementPlanClassification(structure: .definedBenefit, source: .ownStateOrLocal))
        #expect(PlanClassificationChoice.uniformedServicesPension.classification
                == RetirementPlanClassification(structure: .definedBenefit, source: .uniformedServices))
        #expect(PlanClassificationChoice.railroadRetirementPension.classification
                == RetirementPlanClassification(structure: .definedBenefit, source: .railroadRetirement))
    }

    /// The matched pair, from the picker's side rather than the rule's. The
    /// own-state row and the other-state row must write DIFFERENT sources,
    /// because Kansas's rule exempts the first and taxes the second and the
    /// user's selection is the only thing that tells them apart.
    @Test("The own-state row and the other-state row write different, non-interchangeable sources")
    func ownStateAndOtherStateRowsAreDistinct() {
        let own = PlanClassificationChoice.ownStateGovernmentPension.classification.source
        let other = PlanClassificationChoice.otherStateGovernmentPension.classification.source
        #expect(own == .ownStateOrLocal)
        #expect(other == .otherStateOrLocal)
        #expect(own != other)
    }

    /// Every picker row writes a DISTINCT classification, except the one
    /// documented `.employer401k` / `.privateSalaryReduction` collision that
    /// `choice(for:)` resolves deliberately. A second, undocumented
    /// collision would make `choice(for:)` silently unable to round-trip one
    /// of the colliding rows, which is the failure mode the priority array
    /// exists to manage.
    @Test("No two picker rows write the same classification, except the one documented pair")
    func pickerRowsWriteDistinctClassifications() {
        let rows = PlanClassificationChoice.allCases.filter { $0 != .privateSalaryReduction }
        for (i, a) in rows.enumerated() {
            for b in rows.dropFirst(i + 1) {
                #expect(a.classification != b.classification,
                        "\(a) and \(b) write the same classification")
            }
        }
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

    // MARK: - Whole-branch review Fix 4: two more surfaces show the classified label

    @MainActor
    @Test("The PDF export's account table shows a classified 403(b)/457 as itself, not Traditional 401(k)")
    func pdfAccountsSectionShowsClassifiedAccountLabel() {
        let dm = DataManager(skipPersistence: true)
        dm.iraAccounts = [
            IRAAccount(name: "State 403(b)", accountType: .traditional401k, balance: 50_000,
                       planStructure: .definedContribution, planSource: .governmentUnspecified)
        ]
        let data = PDFExportData(from: dm)
        let html = PDFExportService.sectionAccounts(data)
        #expect(html.contains("403(b) or 457 (Government Employer)"))
        #expect(!html.contains(">Traditional 401(k)<"))
    }

    @MainActor
    @Test("The PDF export's account table still shows Traditional 401(k) for an unclassified account")
    func pdfAccountsSectionUnclassifiedAccountUnchanged() {
        let dm = DataManager(skipPersistence: true)
        dm.iraAccounts = [
            IRAAccount(name: "401(k)", accountType: .traditional401k, balance: 50_000)
        ]
        let data = PDFExportData(from: dm)
        let html = PDFExportService.sectionAccounts(data)
        #expect(html.contains(">Traditional 401(k)<"))
    }

    @Test("The RMD calculator's account list shows a classified 403(b)/457 as itself, not Traditional 401(k)")
    func rmdCalculatorShowsClassifiedAccountLabel() {
        let account = IRAAccount(name: "State 403(b)", accountType: .traditional401k, balance: 50_000,
                                  planStructure: .definedContribution, planSource: .governmentUnspecified)
        let label = RMDCalculatorView.accountTypeLabel(for: account)
        #expect(label == "403(b) or 457 (Government Employer)")
        #expect(label != AccountType.traditional401k.rawValue)
    }

    @Test("The RMD calculator's account list still shows Traditional 401(k) for an unclassified account")
    func rmdCalculatorUnclassifiedAccountUnchanged() {
        let account = IRAAccount(name: "401(k)", accountType: .traditional401k, balance: 50_000)
        let label = RMDCalculatorView.accountTypeLabel(for: account)
        #expect(label == AccountType.traditional401k.rawValue)
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

    // MARK: - Phase 5b Task 3: the own-state row is suppressed where it is a trap

    /// Controller-authorized mitigation for the review's findings 1 and 3.
    ///
    /// New York's shipped rule names `nyStateOrLocal`, not `ownStateOrLocal`.
    /// A NYSLRS retiree offered both rows who picks the newer, more natural
    /// "my own state or locality" drops a $60,000 pension from a full
    /// exclusion to New York's ordinary capped $20,000 one: $40,000 taxed
    /// that should be $0, two taps away, on the ONE jurisdiction that has
    /// been prompting users to classify at all. The row is therefore not
    /// offered to New York residents.
    @Test("A resident of a state that names its own jurisdiction is not offered the generic own-state row")
    func ownStateRowIsSuppressedWhereTheStateNamesItsOwnJurisdiction() {
        #expect(PlanClassificationChoice.residenceNamesItsOwnJurisdiction(.newYork))
        let options = PlanClassificationChoice.options(for: .newYork, selected: nil)
        #expect(!options.contains(.ownStateGovernmentPension))
        #expect(options.contains(.nyGovernmentPension),
                "the jurisdiction-named row is the one that DOES select New York's exclusion")
        #expect(options.count == PlanClassificationChoice.allCases.count - 1,
                "suppression must remove exactly one row, not filter anything else out")
    }

    /// The other side, and the reason this is config-driven rather than a
    /// `state == .newYork` check: Kansas names no jurisdiction-named source
    /// (its rule uses the generic `ownStateOrLocal`), so a Kansas resident
    /// must still be able to select KPERS. Suppressing it there would
    /// reintroduce the exact defect the whole addendum exists to fix.
    @Test("A Kansas resident is still offered the own-state row, which is how KPERS is selected at all")
    func ownStateRowIsOfferedWhereTheStateUsesTheGenericSource() {
        #expect(!PlanClassificationChoice.residenceNamesItsOwnJurisdiction(.kansas))
        #expect(PlanClassificationChoice.options(for: .kansas, selected: nil).contains(.ownStateGovernmentPension))
        #expect(PlanClassificationChoice.options(for: .kansas, selected: nil) == PlanClassificationChoice.allCases)
    }

    /// A state with no per-source rules at all is unaffected: nothing is
    /// suppressed anywhere except where a jurisdiction-named rule exists.
    @Test("A state with no per-source rules offers the full list")
    func noPerSourceRulesMeansNoSuppression() {
        #expect(!PlanClassificationChoice.residenceNamesItsOwnJurisdiction(.california))
        #expect(PlanClassificationChoice.options(for: .california, selected: nil) == PlanClassificationChoice.allCases)
    }

    /// Suppression governs what a user can newly CHOOSE, never what they
    /// already chose. A row that somehow carries `ownStateOrLocal` in New
    /// York (imported data, a residence change after classifying, a future
    /// build) must still find its own selection in the list. Without this,
    /// the Picker's selection matches no tag, SwiftUI renders it blank, and
    /// the next save silently rewrites the row's classification.
    @Test("A selection that would be suppressed is still offered, so the picker never renders blank")
    func anExistingOwnStateSelectionSurvivesSuppression() {
        let options = PlanClassificationChoice.options(
            for: .newYork, selected: .ownStateGovernmentPension)
        #expect(options.contains(.ownStateGovernmentPension))
        #expect(options == PlanClassificationChoice.allCases)

        // And selecting anything else does NOT resurrect it.
        #expect(!PlanClassificationChoice.options(for: .newYork, selected: .privateEmployerPension)
            .contains(.ownStateGovernmentPension))
    }

    /// The suppression list is data, not a hardcoded state. This pins that
    /// it names the one legacy jurisdiction-named case and nothing else, so
    /// retiring `nyStateOrLocal` (the structural fix) is a one-line deletion
    /// that this test reports rather than a silent behavior change.
    /// It is a MAP, not a set: each jurisdiction-named source is keyed to
    /// the state it names, so `residenceNamesItsOwnJurisdiction` can ask
    /// whether a config names ITS OWN jurisdiction rather than merely
    /// whether it names some jurisdiction. As a `Set` the association was
    /// dropped and the predicate checked less than its name asserted.
    @Test("The jurisdiction-named source map is exactly the one legacy case, keyed to its own state")
    func jurisdictionNamedSourcesIsExactlyTheLegacyCase() {
        #expect(PlanClassificationChoice.jurisdictionNamedSources == [.nyStateOrLocal: .newYork])
        // Every other source is generic, naming no jurisdiction on its own.
        for source in PlanSource.allCases where source != .nyStateOrLocal {
            #expect(PlanClassificationChoice.jurisdictionNamedSources[source] == nil,
                    "\(source) must not be treated as naming a jurisdiction")
        }
    }

    /// The `== state` half of the predicate, which is what makes its name
    /// true. New York names `nyStateOrLocal` and that source maps to New
    /// York, so New York suppresses. No OTHER state suppresses on account of
    /// New York's case, which is the association a `Set` could not express.
    @Test("Only the state a jurisdiction-named source actually names suppresses on account of it")
    func suppressionIsKeyedToTheNamedStateNotMerePresence() {
        #expect(PlanClassificationChoice.residenceNamesItsOwnJurisdiction(.newYork))
        for state in USState.allCases where state != .newYork {
            #expect(!PlanClassificationChoice.residenceNamesItsOwnJurisdiction(state),
                    "\(state.abbreviation) suppresses the own-state row, but only New York ships a rule naming its own jurisdiction. Either a new jurisdiction-named source shipped without being added to jurisdictionNamedSources, or the predicate regressed to checking mere presence.")
        }
    }

    /// The addendum's "confirm it, do not modify it" item.
    /// `residenceHasPerSourceRules` reads the live config, so shipping
    /// Kansas's `perSourceExemptions` in Phase 5b Task 3 turns the
    /// classification prompt on for Kansas residents with no code change at
    /// all. This is the test that proves the claim rather than asserting it
    /// in a comment.
    @Test("Shipping Kansas's per-source rule turns the classification prompt on for Kansas, with no code change")
    func kansasNowCarriesAPerSourceRule() {
        #expect(PlanClassificationChoice.residenceHasPerSourceRules(.kansas))

        let unclassifiedPension = IncomeSource(
            name: "KPERS", type: .pension, annualAmount: 40_000)
        #expect(PlanClassificationChoice.shouldPromptForClassification(
            source: unclassifiedPension,
            residenceHasPerSourceRules: PlanClassificationChoice.residenceHasPerSourceRules(.kansas)))
    }

    // MARK: - Whole-branch review Fix 2: two pension rows for one owner

    @Test("A classified pension still prompts when its owner's other pension rows genuinely disagree")
    func mixedPensionClassificationStillPrompts() {
        let row = pensionRow(source: .nyStateOrLocal, structure: .definedBenefit)
        #expect(PlanClassificationChoice.shouldPromptForClassification(
            source: row, residenceHasPerSourceRules: true, hasMixedPensionClassification: true))
    }

    @Test("A classified pension does not prompt when hasMixedPensionClassification is left at its default")
    func unmixedPensionClassificationDoesNotPromptByDefault() {
        let row = pensionRow(source: .nyStateOrLocal, structure: .definedBenefit)
        #expect(!PlanClassificationChoice.shouldPromptForClassification(source: row, residenceHasPerSourceRules: true))
    }

    @Test("Two pension rows for the same owner that AGREE are not a mix")
    func agreeingPensionRowsAreNotAMix() {
        let sources = [
            pensionRow(source: .nyStateOrLocal, structure: .definedBenefit),
            pensionRow(source: .nyStateOrLocal, structure: .definedBenefit),
        ]
        #expect(!PlanClassificationChoice.hasMixedPensionClassification(in: sources, owner: .primary))
    }

    @Test("Two pension rows for the same owner that DISAGREE are a genuine mix")
    func disagreeingPensionRowsAreAMix() {
        let sources = [
            pensionRow(source: .nyStateOrLocal, structure: .definedBenefit),
            pensionRow(source: .privateEmployer, structure: .definedBenefit),
        ]
        #expect(PlanClassificationChoice.hasMixedPensionClassification(in: sources, owner: .primary))
    }

    @Test("A single pension row, or zero pension rows, is never a mix")
    func fewerThanTwoPensionRowsIsNeverAMix() {
        #expect(!PlanClassificationChoice.hasMixedPensionClassification(
            in: [pensionRow(source: .nyStateOrLocal, structure: .definedBenefit)], owner: .primary))
        #expect(!PlanClassificationChoice.hasMixedPensionClassification(in: [], owner: .primary))
    }

    @Test("hasAnyMixedPensionClassification finds a mix regardless of which owner carries it")
    func hasAnyMixedPensionClassificationChecksEveryOwner() {
        let mixedForSpouse = [
            IncomeSource(name: "Spouse Gov Pension", type: .pension, annualAmount: 30_000, owner: .spouse,
                         planStructure: .definedBenefit, planSource: .nyStateOrLocal),
            IncomeSource(name: "Spouse Private Pension", type: .pension, annualAmount: 20_000, owner: .spouse,
                         planStructure: .definedBenefit, planSource: .privateEmployer),
        ]
        #expect(PlanClassificationChoice.hasAnyMixedPensionClassification(in: mixedForSpouse))

        let agreeingForBoth = [
            pensionRow(source: .nyStateOrLocal, structure: .definedBenefit),
            IncomeSource(name: "Spouse Pension", type: .pension, annualAmount: 20_000, owner: .spouse,
                         planStructure: .definedBenefit, planSource: .privateEmployer),
        ]
        #expect(!PlanClassificationChoice.hasAnyMixedPensionClassification(in: agreeingForBoth))
    }

    // MARK: - Whole-branch review Fix 3: hoisted save-time classification decision

    @Test("A pension row's save carries the picker's chosen classification")
    func pensionSaveCarriesChosenClassification() {
        let choice = PlanClassificationChoice.nyGovernmentPension
        #expect(PlanClassificationChoice.classificationToSave(incomeType: .pension, choice: choice) == choice.classification)
    }

    @Test("A non-pension row's save passes nil, regardless of the picker's leftover selection")
    func nonPensionSavePassesNil() {
        let choice = PlanClassificationChoice.nyGovernmentPension
        #expect(PlanClassificationChoice.classificationToSave(incomeType: .consulting, choice: choice) == nil)
        #expect(PlanClassificationChoice.classificationToSave(incomeType: .rmd, choice: choice) == nil)
        #expect(PlanClassificationChoice.classificationToSave(incomeType: .socialSecurity, choice: choice) == nil)
    }

    @Test("An account whose type shows the picker saves the picker's chosen classification")
    func accountSaveCarriesChosenClassificationWhenPickerShown() {
        let choice = PlanClassificationChoice.employer401k
        #expect(PlanClassificationChoice.classificationToSave(accountType: .traditional401k, choice: choice) == choice.classification)
        #expect(PlanClassificationChoice.classificationToSave(accountType: .traditionalIRA, choice: choice) == choice.classification)
    }

    @Test("A Roth or inherited account's save passes nil, regardless of the picker's leftover selection")
    func rothAndInheritedAccountSavePassesNil() {
        let choice = PlanClassificationChoice.employer401k
        for type in AccountType.allCases where type.isRothType || type.isInherited {
            #expect(PlanClassificationChoice.classificationToSave(accountType: type, choice: choice) == nil,
                     "AccountType.\(type) must not save a classification")
        }
    }

    // MARK: - 3.7 The unclassified-pension limitation wherever that state's tax is computed
    //
    // Phase 5b Task 3b renamed both functions and moved their copy into each
    // jurisdiction's own config. These New York cases are kept verbatim in
    // substance: New York is still the jurisdiction whose behaviour must not
    // change. What they could never catch, and what
    // `Phase5bUnclassifiedPensionDisclosureTests` adds, is that a SECOND
    // jurisdiction shipping a per-source rule also gets warned, and that New
    // York's copy is byte-identical after the move.

    @Test("StateComparisonView shows the limitation when viewing New York with an unclassified pension")
    func stateComparisonShowsLimitationForUnclassifiedNewYorkPension() {
        #expect(StateComparisonPresentation.showsUnclassifiedPensionLimitation(
            viewedState: .newYork, hasUnclassifiedPension: true))
    }

    @Test("StateComparisonView omits the limitation once the pension is classified")
    func stateComparisonOmitsLimitationOnceClassified() {
        #expect(!StateComparisonPresentation.showsUnclassifiedPensionLimitation(
            viewedState: .newYork, hasUnclassifiedPension: false))
    }

    @Test("StateComparisonView omits the limitation for a state with no per-source rules")
    func stateComparisonOmitsLimitationForOtherStates() {
        #expect(!StateComparisonPresentation.showsUnclassifiedPensionLimitation(
            viewedState: .california, hasUnclassifiedPension: true))
    }

    // MARK: - CPA briefing: the unclassified-pension limitation

    @Test("The CPA briefing carries the limitation for a NY resident with an unclassified pension")
    func cpaBriefingCarriesNewYorkLimitationWhenApplicable() {
        let limitations = MultiYearCPABriefing.unclassifiedPensionLimitation(
            residenceState: .newYork, hasUnclassifiedPension: true)
        #expect(!limitations.isEmpty)
        #expect(limitations.allSatisfy { !$0.isEmpty })
    }

    @Test("The CPA briefing omits the New York limitation for a resident of a state with no rules")
    func cpaBriefingOmitsNewYorkLimitationOutsideNewYork() {
        let limitations = MultiYearCPABriefing.unclassifiedPensionLimitation(
            residenceState: .california, hasUnclassifiedPension: true)
        #expect(limitations.isEmpty)
    }

    @Test("The CPA briefing omits the limitation once the pension is classified")
    func cpaBriefingOmitsNewYorkLimitationOnceClassified() {
        let limitations = MultiYearCPABriefing.unclassifiedPensionLimitation(
            residenceState: .newYork, hasUnclassifiedPension: false)
        #expect(limitations.isEmpty)
    }

    @Test("The rendered CPA briefing HTML contains the New York limitation text when applicable")
    func cpaBriefingHTMLContainsNewYorkLimitation() {
        let extra = MultiYearCPABriefing.unclassifiedPensionLimitation(
            residenceState: .newYork, hasUnclassifiedPension: true)
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
            source: pensionRow(source: .unknown), residenceHasPerSourceRules: true,
            hasMixedPensionClassification: false)
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

    /// Not `private`: `Phase5bUnclassifiedPensionDisclosureTests` renders the
    /// Kansas disclosure through the same briefing model, and a second copy
    /// of this fixture would be free to drift from this one.
    static func briefingModel(limitations: [String]) -> CPABriefingModel {
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
