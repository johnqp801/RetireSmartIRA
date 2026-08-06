//
//  IncomeSourcesView.swift
//  RetireSmartIRA
//
//  Manage income sources and itemized deductions for tax calculations
//

import SwiftUI

/// Phase 3b Task 6 (design doc section 3.2): the one flat list of
/// plan-classification choices shown on `.pension` income rows and on
/// traditional (non-Roth, non-inherited) accounts. Exact rows, order and
/// two-dimension mappings per spec section 3.2 -- do not add, remove, or
/// reorder without updating the spec. This is the ONLY place in the app a
/// user sets `RetirementPlanClassification`.
///
/// Phase 5b Task 3 (controller addendum) added three rows:
/// `ownStateGovernmentPension`, `uniformedServicesPension` and
/// `railroadRetirementPension`. Task 1 added the three `PlanSource` cases
/// they write, but nothing in this picker could write any of them, so a
/// Kansas KPERS holder had exactly one government-pension option, "another
/// state or locality", which writes `otherStateOrLocal` -- the one case a
/// correct Kansas rule must NOT match. Every Kansas golden case would have
/// gone green while a real KPERS holder still received no exclusion. All
/// three rows land together, not just the one Kansas needs, so the later
/// Phase 5b jurisdictions (Vermont, Arizona, Idaho, Massachusetts) inherit a
/// picker that can express their rules.
///
/// The addition is ADDITIVE: no existing case's `classification` changed, so
/// no row a user already saved means anything different than it did before.
/// `RetirementPlanClassification` is what persists, on `IncomeSource` and
/// `IRAAccount`; this enum is a presentation type held in `@State` and is
/// never encoded. The three new rows are INSERTED rather than appended,
/// which changes display POSITION but preserves the relative order of all
/// nine original rows.
///
/// THE OVERLAP, and what is done about it: for a New York resident,
/// `nyGovernmentPension` and `ownStateGovernmentPension` describe the same
/// pension, and only the FIRST selects New York's Line 26 exclusion, because
/// New York's shipped rule names `nyStateOrLocal`. Picking the newer and
/// arguably more natural row would drop a $60,000 NYSLRS pension to New
/// York's ordinary capped $20,000 exclusion: $40,000 taxed that should be
/// $0, two taps away, on the one jurisdiction that has been prompting users
/// to classify at all. `options(for:selected:)` below suppresses the
/// own-state row for exactly those residents, driven by live config.
///
/// That is a MITIGATION, not the fix. The structural fix is to collapse
/// `nyStateOrLocal` into `ownStateOrLocal` and retire the jurisdiction-named
/// case, which touches New York's shipped config, New York's fixtures and
/// existing user saves, and is deliberately deferred. See the Task 3 report.
enum PlanClassificationChoice: String, CaseIterable, Identifiable {
    case nyGovernmentPension
    case ownStateGovernmentPension
    case federalCivilianPension
    case uniformedServicesPension
    case railroadRetirementPension
    case otherStateGovernmentPension
    case privateEmployerPension
    case governmentSalaryReduction
    case privateSalaryReduction
    case employer401k
    case ira
    case notSure

    var id: String { rawValue }

    /// Plain-English row label, spec section 3.2 column 1, verbatim for the
    /// nine original rows.
    ///
    /// The three Phase 5b rows were introduced by Task 3 as working copy and
    /// were APPROVED AS IS by John on 2026-08-05, so all twelve rows are now
    /// approved user-facing copy. They remain deliberately plain rather than
    /// clever, and a rename would still be a one-line change with no
    /// behavioral consequence: nothing keys on a label, and what a row
    /// PERSISTS is the `RetirementPlanClassification` its `classification`
    /// returns, not any text and not the case's `rawValue`. Their exact
    /// strings are pinned by
    /// `Phase3bPresentationTests.newPickerLabelsAreApprovedAndPinned`.
    var label: String {
        switch self {
        case .nyGovernmentPension: return "Government pension, New York State or local"
        case .ownStateGovernmentPension: return "Government pension, my own state or locality"
        case .federalCivilianPension: return "Government pension, federal civilian"
        case .uniformedServicesPension: return "Military retired pay"
        case .railroadRetirementPension: return "Railroad Retirement benefits"
        case .otherStateGovernmentPension: return "Government pension, another state or locality"
        case .privateEmployerPension: return "Private employer pension"
        case .governmentSalaryReduction: return "403(b) or 457, government employer"
        case .privateSalaryReduction: return "403(b) or 457, private or nonprofit employer"
        case .employer401k: return "Employer 401(k)"
        case .ira: return "IRA"
        case .notSure: return "Not sure"
        }
    }

    /// The two-dimension classification this row writes, spec section 3.2
    /// columns 2 and 3.
    var classification: RetirementPlanClassification {
        switch self {
        case .nyGovernmentPension:
            return RetirementPlanClassification(structure: .definedBenefit, source: .nyStateOrLocal)
        case .ownStateGovernmentPension:
            // Phase 5b Task 3. The taxpayer's OWN state system: KPERS to a
            // Kansas resident. The matched pair of `.otherStateGovernmentPension`
            // below, and the reason Kansas's rule can exempt one without
            // exempting the other.
            return RetirementPlanClassification(structure: .definedBenefit, source: .ownStateOrLocal)
        case .federalCivilianPension:
            return RetirementPlanClassification(structure: .definedBenefit, source: .federalCivilian)
        case .uniformedServicesPension:
            // Phase 5b Task 3. Military retired pay, distinct from CSRS/FERS:
            // Vermont, Arizona, Idaho, Massachusetts and Kansas each treat
            // the two differently, and Kansas is the first to ship a rule.
            return RetirementPlanClassification(structure: .definedBenefit, source: .uniformedServices)
        case .railroadRetirementPension:
            // Phase 5b Task 3. Railroad Retirement Board benefits, which
            // Kansas's Schedule S Line A14 exempts by name, neither a state
            // system nor an ordinary federal civilian pension.
            return RetirementPlanClassification(structure: .definedBenefit, source: .railroadRetirement)
        case .otherStateGovernmentPension:
            // The row that exists specifically to stop an out-of-state
            // public pension from selecting New York's exclusion (spec
            // section 3.2). Line 26 covers NYS, NY localities, named NY
            // authorities and the US government only.
            return RetirementPlanClassification(structure: .definedBenefit, source: .otherStateOrLocal)
        case .privateEmployerPension:
            return RetirementPlanClassification(structure: .definedBenefit, source: .privateEmployer)
        case .governmentSalaryReduction:
            return RetirementPlanClassification(structure: .definedContribution, source: .governmentUnspecified)
        case .privateSalaryReduction, .employer401k:
            // Deliberately identical (spec section 3.2): neither row
            // affects any rule shipping in this phase, since New York
            // excludes both by structure (definedContribution never
            // matches Line 26). See `choice(for:)` below for the
            // reverse-lookup consequence of this collision.
            return RetirementPlanClassification(structure: .definedContribution, source: .privateEmployer)
        case .ira:
            return RetirementPlanClassification(structure: .ira, source: .individual)
        case .notSure:
            return RetirementPlanClassification(structure: .unknown, source: .unknown)
        }
    }

    /// Reverse lookup, for pre-selecting the picker against an existing
    /// classification when editing a row or account. `.employer401k` and
    /// `.privateSalaryReduction` write the identical classification (see
    /// above), so this is inherently ambiguous for that one pair. Resolved
    /// in favor of `.employer401k`, the far more common case, via an
    /// explicit priority list rather than `allCases`' declaration/display
    /// order (which follows spec section 3.2 and lists the 403(b) row
    /// first).
    ///
    /// THIS ARRAY IS HAND-MAINTAINED AND DOES NOT USE `allCases`. A case
    /// omitted from it does not fail to compile: it silently falls through
    /// to `.notSure`, so an already-correctly-classified row would display
    /// as unclassified the moment a user opened it to edit. The three
    /// Phase 5b Task 3 rows are listed here for that reason.
    /// `Phase3bPresentationTests.reverseLookupRoundTrips` sweeps `allCases`
    /// and is the test that catches an omission.
    ///
    /// MATCHED ON STRUCTURE AND SOURCE ONLY, which is a whole-branch review
    /// fix and is load-bearing rather than cosmetic. Task 9 gave
    /// `RetirementPlanClassification` a THIRD stored property,
    /// `isSurvivorBenefit`, so its synthesized `==` now compares that too,
    /// while every entry in the list below carries `nil` for it. A whole-value
    /// `==` therefore falls through to `.notSure` for any survivor-flagged
    /// classification: an already-correctly-classified DC survivor annuity
    /// would open in the editor displaying as unclassified, and saving would
    /// rewrite it. That is exactly the silent fallthrough this doc comment
    /// warns about two paragraphs up, arriving through a route the warning did
    /// not anticipate, and `reverseLookupRoundTrips` cannot catch it because
    /// every case it sweeps carries `nil`.
    ///
    /// It is unreachable TODAY only by luck of the two call sites: both
    /// construct the classification from `planStructure` and `planSource`
    /// alone, and `IRAAccount` has no survivor field at all. This function is
    /// the wrong place to depend on that. The survivor fact is not something
    /// the twelve-row picker expresses in the first place -- it is a separate
    /// toggle beside it -- so the reverse lookup should never have been
    /// consulting it.
    static func choice(for classification: RetirementPlanClassification) -> PlanClassificationChoice {
        let priorityOrder: [PlanClassificationChoice] = [
            .nyGovernmentPension, .ownStateGovernmentPension, .federalCivilianPension,
            .uniformedServicesPension, .railroadRetirementPension,
            .otherStateGovernmentPension,
            .privateEmployerPension, .governmentSalaryReduction, .employer401k,
            .privateSalaryReduction, .ira, .notSure
        ]
        return priorityOrder.first(where: {
            $0.classification.structure == classification.structure
                && $0.classification.source == classification.source
        }) ?? .notSure
    }

    /// Whether the picker should be offered at all for `accountType`. Roth
    /// and inherited accounts get none, since no audited rule turns on
    /// their plan kind (task 6 brief, step 1).
    static func showsPickerFor(accountType: AccountType) -> Bool {
        !accountType.isRothType && !accountType.isInherited
    }

    /// `PlanSource` cases that name ONE specific jurisdiction outright,
    /// rather than describing a jurisdiction relative to where the taxpayer
    /// lives. `nyStateOrLocal` is the only one, and it predates
    /// `ownStateOrLocal`: it is the jurisdiction-named form of what Phase 5b
    /// made expressible generically. Data rather than a `state == .newYork`
    /// check, so retiring the case (the structural fix this file's enum doc
    /// comment describes) is a one-line deletion here and nowhere else.
    /// keyed to THE STATE IT NAMES, so the association survives the lookup.
    ///
    /// This was a `Set<PlanSource>` on review, which dropped the
    /// source-to-state association and made
    /// `residenceNamesItsOwnJurisdiction` check less than its name asserted:
    /// it answered "does this state's config name ANY jurisdiction-named
    /// source", not "does it name ITS OWN".
    ///
    /// THAT DIFFERENCE IS NOW LIVE, and Arizona is what exercises it. An
    /// earlier version of this comment said nothing triggered it, on the
    /// grounds that only New York's config named `nyStateOrLocal`. Phase 5b
    /// Task 6 changed that: Arizona's Line 29a DENIAL rule names
    /// `nyStateOrLocal`, because an Arizona resident can select the New York
    /// picker row and a New York pension is not Line 29a income. Under the
    /// old `Set` version, `residenceNamesItsOwnJurisdiction(.arizona)` would
    /// answer true and `options(for: .arizona)` would suppress the generic
    /// own-state row for every Arizona resident, making Arizona's own $2,500
    /// allowance UNREACHABLE for an Arizona State Retirement System retiree.
    /// The `== state` comparison is what keeps it false. Reverting this to a
    /// `Set` now breaks Arizona;
    /// `Phase5bArizonaPerSourceTests.arizonaDoesNotSuppressTheOwnStateRow`
    /// is the test that catches it.
    static let jurisdictionNamedSources: [PlanSource: USState] = [.nyStateOrLocal: .newYork]

    /// Whether `state`'s OWN configuration already names its own
    /// jurisdiction in a per-source rule, which makes the generic own-state
    /// row a trap for that state's residents rather than a convenience:
    /// their own state's exclusion is reachable only through the
    /// jurisdiction-named row, so offering both invites them to pick the one
    /// that silently costs them the exclusion.
    ///
    /// Reads the live config, in the same spirit as
    /// `residenceHasPerSourceRules` below, so it needs no edit when a
    /// jurisdiction ships or retires such a rule. The `== state` comparison
    /// is what makes this "its own" rather than "any": a config naming some
    /// OTHER state's jurisdiction-named source would not suppress here, and
    /// should not, because the generic own-state row is still the only way
    /// that state's residents could describe their own pension.
    static func residenceNamesItsOwnJurisdiction(_ state: USState) -> Bool {
        StateTaxData.config(for: state).retirementExemptions.perSourceExemptions.contains { rule in
            rule.matchSources.contains { jurisdictionNamedSources[$0] == state }
        }
    }

    /// The rows to offer a resident of `state`. `allCases` for everyone
    /// except a resident whose own config names its own jurisdiction, who
    /// does not see the generic own-state row at all.
    ///
    /// `selected` is the picker's CURRENT selection and is never filtered
    /// out even when it would otherwise be suppressed. Without that, a row
    /// already carrying `ownStateOrLocal` would open with a selection that
    /// matches no tag in the list, which SwiftUI renders as a blank picker
    /// and which would silently rewrite the row's classification on the next
    /// save. Suppression is about what a user can newly CHOOSE, never about
    /// hiding what they already chose.
    ///
    /// `selected` has NO DEFAULT VALUE, deliberately. It carried `= nil` on
    /// review, which made the one form with a data-loss failure mode the
    /// DEFAULT form: a call site added later could omit it with no compile
    /// error, and no test would catch it, because the tests exercise the nil
    /// form on purpose and therefore cannot also assert that production
    /// never uses it. Requiring the argument moves that from "covered by
    /// vigilance" to "foreclosed by the compiler". Pass `nil` explicitly
    /// when there genuinely is no current selection.
    static func options(for state: USState,
                        selected: PlanClassificationChoice?) -> [PlanClassificationChoice] {
        guard residenceNamesItsOwnJurisdiction(state) else { return allCases }
        return allCases.filter { $0 != .ownStateGovernmentPension || $0 == selected }
    }

    /// The label an account row or detail view should show in place of
    /// `accountType.rawValue`, spec section 3.7 ("a classified 403(b) or
    /// 457 displays as itself"). Only `(definedContribution,
    /// governmentUnspecified)` is unambiguous: it is the one tuple no
    /// `AccountType`'s default inference ever produces
    /// (`RetirementPlanClassification.infer(accountType:)` never returns
    /// `.governmentUnspecified`), so seeing it always means a user
    /// explicitly picked "403(b) or 457, government employer." Every other
    /// definedContribution/privateEmployer combination is what a plain,
    /// never-classified 401(k) already infers to by default AND what
    /// "Employer 401(k)" and "403(b) or 457, private or nonprofit employer"
    /// both write (spec section 3.2), so it is indistinguishable without
    /// persisting the literal picker choice, which is out of this task's
    /// scope (the Account schema is frozen from Tasks 1 through 5). Those
    /// cases fall back to `accountType.rawValue`, unchanged from today.
    static func accountDisplayName(accountType: AccountType, planStructure: PlanStructure, planSource: PlanSource) -> String {
        if planStructure == .definedContribution && planSource == .governmentUnspecified {
            return "403(b) or 457 (Government Employer)"
        }
        return accountType.rawValue
    }

    /// Whether a `.pension` income row should show the prominent "is this a
    /// government pension" prompt, spec section 3.7. Gated on the income
    /// type (never `.rmd` or anything else), on the taxpayer's residence
    /// actually carrying a per-source rule that could change the answer
    /// (prompting a resident of a state with no per-source rules would be
    /// noise with no possible effect on their tax), and on EITHER the row
    /// itself still being unclassified OR its owner's pension rows
    /// genuinely disagreeing with each other (`hasMixedPensionClassification`,
    /// default `false` for callers that have not computed it -- whole-branch
    /// review Fix 2). A genuine mix has no `.unknown` row to trip the first
    /// half of this check, so it needs its own gate: `nil` classification
    /// with no `.unknown` row previously warned nobody.
    static func shouldPromptForClassification(
        source: IncomeSource, residenceHasPerSourceRules: Bool, hasMixedPensionClassification: Bool = false
    ) -> Bool {
        guard source.type == .pension, residenceHasPerSourceRules else { return false }
        return source.planSource == .unknown || hasMixedPensionClassification
    }

    /// Whether `owner`'s `.pension` rows in `sources` disagree on
    /// classification -- e.g. one New York government pension and one
    /// private pension for the same person. Every row here IS classified
    /// (no row has `.unknown` `planSource`), so the ordinary "unclassified
    /// pension" checks above never catch it on their own. This is the
    /// genuine-mix case `MultiYearInputAdapter.pensionClassification` falls
    /// back to `nil` for (design doc section 3.4b); the disclosure surfaces
    /// need this as a second, independent gate. Whole-branch review Fix 2.
    static func hasMixedPensionClassification(in sources: [IncomeSource], owner: Owner) -> Bool {
        let rows = sources.filter { $0.type == .pension && $0.owner == owner }
        guard let first = rows.first else { return false }
        return rows.dropFirst().contains {
            $0.planStructure != first.planStructure || $0.planSource != first.planSource
        }
    }

    /// Same as `hasMixedPensionClassification(in:owner:)`, across every
    /// owner who has `.pension` income in `sources`. Used by disclosure
    /// surfaces (State Comparison, the Multi-Year CPA briefing) that do not
    /// distinguish primary from spouse. Whole-branch review Fix 2.
    static func hasAnyMixedPensionClassification(in sources: [IncomeSource]) -> Bool {
        let pensionOwners = Set(sources.filter { $0.type == .pension }.map(\.owner))
        return pensionOwners.contains { hasMixedPensionClassification(in: sources, owner: $0) }
    }

    /// The classification to persist for a `.pension` income row's save,
    /// hoisted out of `AddIncomeView.saveIncome()` (a private method on a
    /// private view struct, per whole-branch review Fix 3) so a test can
    /// pin both branches directly. Only `.pension` rows are ever classified
    /// through this picker; every other `IncomeType` passes `nil` so
    /// `IncomeSource.init`'s own inference stays in charge, exactly as
    /// before this fix, and switching a row's type away from `.pension`
    /// cannot leave a stray pension classification on unrelated income.
    static func classificationToSave(incomeType: IncomeType, choice: PlanClassificationChoice) -> RetirementPlanClassification? {
        incomeType == .pension ? choice.classification : nil
    }

    /// The classification to persist for an account's save, hoisted out of
    /// `AddAccountView.saveAccount()` the same way (whole-branch review Fix
    /// 3). `nil` whenever the picker would not have been shown for
    /// `accountType` (Roth and inherited types), so `IRAAccount.init`'s own
    /// inference stays in charge for those even if a future refactor stops
    /// resetting the picker's selection on an account-type change.
    static func classificationToSave(accountType: AccountType, choice: PlanClassificationChoice) -> RetirementPlanClassification? {
        showsPickerFor(accountType: accountType) ? choice.classification : nil
    }

    /// Whether `state`'s configuration carries any per-source exemption
    /// rule at all. Reads the live config rather than hardcoding "New York"
    /// so this stays correct the day a second jurisdiction ships one (spec
    /// section 3.3).
    ///
    /// That day arrived in Phase 5b Task 3: Kansas now ships
    /// `perSourceExemptions` too, so this function returns `true` for Kansas
    /// with NO change to its body, and the classification prompt turns on
    /// for Kansas residents automatically. Verified, not assumed, by
    /// `Phase3bPresentationTests`.
    static func residenceHasPerSourceRules(_ state: USState) -> Bool {
        !StateTaxData.config(for: state).retirementExemptions.perSourceExemptions.isEmpty
    }

    /// Phase 5b Task 9: whether `state` ships a per-source rule that consults
    /// the SURVIVOR dimension, and therefore whether the pension editor should
    /// ask the question at all.
    ///
    /// DERIVED FROM LIVE CONFIG, never a hardcoded `state == .districtOfColumbia`.
    /// Task 3 established that precedent and the reason is the same one: a rule
    /// no real user can select is a green suite and an undelivered fix, and a
    /// hardcoded jurisdiction check goes stale the moment a second jurisdiction
    /// ships a survivor rule. Today exactly one does, which
    /// `Phase5bDCSurvivorTests.onlyTheDistrictAsksTheSurvivorQuestion` asserts
    /// by sweeping `USState.allCases` rather than by naming DC.
    ///
    /// WHY THIS GATE EXISTS AT ALL: `isSurvivorBenefit` is a THIRD question on
    /// top of the twelve-row plan-type picker, and for 50 of 51 jurisdictions
    /// the answer cannot change a single dollar. Asking everyone would be the
    /// noise `shouldPromptForClassification` already declines to make.
    static func residenceUsesSurvivorDimension(_ state: USState) -> Bool {
        StateTaxData.config(for: state).retirementExemptions.perSourceExemptions
            .contains { $0.matchIsSurvivorBenefit != nil }
    }
}

struct IncomeSourcesView: View {

    /// Phase 5b Task 7. North Carolina's Bailey disclosure.
    ///
    /// **APPROVED BY JOHN ON 2026-08-05**, as written, together with Idaho's
    /// caption below. Every caption in this section is now approved copy (Hawaii
    /// pre-dates Phase 5b; Massachusetts's was approved the same day). It ships
    /// because North Carolina was the first jurisdiction this phase touched
    /// carrying zero disclosure on any surface: a Bailey-vested retiree is
    /// over-taxed by $1,486.27 a year at the NC-1 fixture's shape with nothing on
    /// screen telling them. Rewording it is a one-line change here plus the
    /// assertions in
    /// `Phase5bNorthCarolinaDecisionTests.northCarolinaCaptionNamesTheRightDirection`.
    ///
    /// HOISTED to a static rather than written inline like the Hawaii and
    /// Massachusetts captions, so it has a test seam. Task 5 recorded the
    /// absence of one for those two as a gap to close in Phase 6; there is no
    /// reason to add a third untestable literal in the meantime.
    ///
    /// It cannot be an `unclassifiedPensionDisclosure` sentence: that string is
    /// in bidirectional lockstep with `perSourceExemptions`, which North
    /// Carolina deliberately does not ship, and it would be false anyway,
    /// because a North Carolina pension can be perfectly classified and still be
    /// taxed wrongly. The durable record is the NC entry in
    /// `GoldenScenarioDefectCatalogueTests.knownButUnpinned`; this is the only
    /// surface that reaches the affected user. Delete both together if a Bailey
    /// vesting axis is ever added.
    static let northCarolinaBaileyCaption =
        "North Carolina exempts a state, local or federal government pension under the "
        + "Bailey settlement if you had five or more years of creditable service by "
        + "August 12, 1989. This app does not model that vesting date, so if you qualify "
        + "your North Carolina state tax may be overstated."

    /// Phase 5b Task 8. Idaho's Retirement Benefits Deduction disclosure.
    ///
    /// **APPROVED BY JOHN ON 2026-08-05**, as written, together with the North
    /// Carolina caption above, whose situation Idaho's repeats: Idaho ships no rule,
    /// so `shouldPromptForClassification` never fires for an Idaho resident (it
    /// gates on `residenceHasPerSourceRules`) and
    /// `UnclassifiedPensionDisclosure.text(for: .idaho)` is nil (it gates on the
    /// config sentence, which is in bidirectional lockstep with the rules). That
    /// leaves an Idaho resident with ZERO disclosure on every surface while
    /// Idaho grants no Retirement Benefits Deduction at all, over-taxing a
    /// qualifying retiree by up to $840.05 a year at the ID-2 fixture's shape.
    ///
    /// Two other wordings were drafted and are recorded in the Task 8 report; this
    /// one was recommended because it names the three qualifying groups and BOTH
    /// age gates, so a reader can tell whether it applies to them, rather than
    /// warning vaguely that something may be wrong. Rewording is a one-line change
    /// here plus the assertions in
    /// `Phase5bIdahoDecisionTests.idahoCaptionNamesTheRightDirection`.
    ///
    /// DIRECTION: overstated. Idaho applies no part of the deduction today, so
    /// every error runs toward over-taxation, exactly like North Carolina and
    /// Hawaii and unlike Massachusetts. Harmonising this with the Massachusetts
    /// caption would invert it.
    ///
    /// It cannot be an `unclassifiedPensionDisclosure` sentence, for the same two
    /// reasons North Carolina's could not: that string is in bidirectional
    /// lockstep with `perSourceExemptions`, which Idaho deliberately does not
    /// ship, and it would be false anyway, because an Idaho pension can be
    /// perfectly classified through the picker and still be taxed wrongly. The
    /// facts Idaho's Form 39R Part Two needs, pre-1984 CSRS eligibility and
    /// police-or-firefighter service within PERSI, are not on the classification
    /// at all. The durable record is the ID entry in
    /// `GoldenScenarioDefectCatalogueTests.knownButUnpinned`; this is the only
    /// surface that reaches the affected user. Delete both together if those axes
    /// are ever added.
    static let idahoRetirementBenefitsDeductionCaption =
        "Idaho deducts certain retirement benefits from state tax, including Civil "
        + "Service (CSRS) annuities, some Idaho police and firefighter pensions, and "
        + "military retired pay, generally from age 65 or from age 62 for retired "
        + "service members. This app does not apply that deduction, so if you qualify "
        + "your Idaho state tax may be overstated."

    /// Phase 5b Task 9. Vermont's two retirement exclusions.
    ///
    /// **APPROVED BY JOHN ON 2026-08-05**, as written, together with the District
    /// of Columbia's survivor toggle and caption below and DC's
    /// `unclassifiedPensionDisclosure` sentence in `statetax-2026-DC.json`. Every
    /// caption in this section is now approved copy. Two alternatives are recorded
    /// in the Task 9 report as the record of what was considered and rejected.
    /// This one was recommended because it names both exclusions
    /// and both income limits, so a reader can tell whether either applies to
    /// them, and because Vermont's two are very differently sized: $10,000
    /// capped for CSRS against an UNCAPPED exclusion for military retired pay.
    /// A sentence that named only one would leave the larger gap invisible.
    ///
    /// WHY VERMONT SHIPS A CAPTION AND NO RULE, which is the same position
    /// North Carolina and Idaho are in. Vermont's six pinned defects include the
    /// single largest dollar gap measured in this phase, $5,211.50 a year at the
    /// VT-6 fixture's shape, and a Vermont resident sees NOTHING about it today:
    /// `shouldPromptForClassification` gates on `residenceHasPerSourceRules` and
    /// Vermont ships none, and `UnclassifiedPensionDisclosure.text(for:
    /// .vermont)` is nil because that string is in bidirectional lockstep with
    /// the rules. This caption is the only surface that reaches the affected
    /// user.
    ///
    /// It cannot be an `unclassifiedPensionDisclosure` sentence for the same two
    /// reasons North Carolina's and Idaho's could not: the lockstep sweep would
    /// fail it without a rule, and it would be false anyway, because a Vermont
    /// pension can be perfectly classified through the picker and still be taxed
    /// wrongly. Neither of the facts Vermont's Schedule IN-112 turns on is on
    /// the classification: whether the CSRS-side earnings were covered by Social
    /// Security, and the AGI phase-out band the exclusion sits in.
    ///
    /// DIRECTION: overstated. Vermont applies neither exclusion today, so every
    /// error runs toward over-taxation, exactly like North Carolina, Idaho and
    /// Hawaii and unlike Massachusetts. Harmonising this with the Massachusetts
    /// caption would invert it.
    ///
    /// The durable record is Vermont's six `knownDefect` blocks in
    /// `statetax-2026-VT.golden.json` and `Phase5bVermontDecisionTests`. Delete
    /// all three together if Vermont's exclusions are ever modelled.
    static let vermontRetirementExclusionCaption =
        "Vermont exempts up to $10,000 of Civil Service Retirement System income for "
        + "filers under $55,000 of income ($70,000 if married filing jointly), and under "
        + "2025's Act 71 exempts military retired pay in full under $125,000 of income. "
        + "This app applies neither exemption, so if you qualify your Vermont state tax "
        + "may be overstated."

    /// Phase 5b Task 9. The District of Columbia's survivor-annuity caption, the
    /// explanation sitting under the "I receive this as a survivor or beneficiary"
    /// toggle.
    ///
    /// **APPROVED BY JOHN ON 2026-08-05**, as written, together with the toggle
    /// label itself and DC's `unclassifiedPensionDisclosure` sentence in
    /// `statetax-2026-DC.json`.
    ///
    /// HOISTED from an inline view-body literal by the per-state accuracy
    /// disclosure work, which changed the text not at all. It had no test seam
    /// before that; two Phase 5b reviews recorded the absence of one for this
    /// caption and for Hawaii's and Massachusetts's below. The byte-identity gate
    /// that proves the later move to `StateVerification.knownLimitations` is
    /// lossless cannot be written against a literal buried in a `body`.
    ///
    /// The second sentence is the load-bearing one and is not decoration: DC
    /// excludes a survivor annuity but taxes an annuitant's OWN pension in full,
    /// so a reader who turns the toggle on for their own pension gets a wrong
    /// number in the confident direction. Rewording is a one-line change here plus
    /// the assertions in `Phase5bDCSurvivorTests` and
    /// `StateAccuracyContentTests`.
    static let districtOfColumbiaSurvivorToggleCaption =
        "The District of Columbia excludes a DC or federal government survivor annuity "
        + "from tax once the survivor is 62 or older, but taxes an annuitant's own "
        + "pension in full. Turn this on only for a pension paid to you as someone "
        + "else's survivor or beneficiary."

    /// Hawaii's employer-funded-split caption, shown to any Hawaii resident in the
    /// pension editor.
    ///
    /// HOISTED from an inline view-body literal by the per-state accuracy
    /// disclosure work, which changed the text not at all.
    ///
    /// DIRECTION: overstated. Hawaii excludes the employer-funded portion and this
    /// app models no split, so it taxes the whole pension and every error runs
    /// toward over-taxation, exactly like North Carolina, Idaho and Vermont and
    /// unlike Massachusetts below. Harmonising this with the Massachusetts caption
    /// would invert one of them.
    ///
    /// NOT the same string as
    /// `MultiYearCPABriefing.hawaiiPensionSplitLimitation`, which discloses the
    /// same gap on the CPA-briefing surface and says "This plan does not model"
    /// where this one says "This app does not model". The two are pinned by
    /// different tests (`Phase5bHawaiiDecisionTests` covers the briefing string,
    /// `StateAccuracyContentTests` covers this one) and must be reconciled
    /// deliberately, not by assuming a copy-paste slip, if the captions are ever
    /// consolidated into one config field.
    static let hawaiiEmployerFundedCaption =
        "Hawaii excludes the employer-funded portion of a pension from state tax. This "
        + "app does not model the split between employer-funded and employee-contributed "
        + "amounts, so your Hawaii state tax may be overstated."

    /// Phase 5b Task 4. Massachusetts's contributory-against-noncontributory
    /// caption.
    ///
    /// **APPROVED BY JOHN ON 2026-08-05.** Deliberately modelled on the Hawaii
    /// caption above rather than invented: both disclose the SAME missing axis,
    /// employee-contributory against employer-funded, which
    /// `RetirementPlanClassification` does not carry.
    ///
    /// HOISTED from an inline view-body literal by the per-state accuracy
    /// disclosure work, which changed the text not at all.
    ///
    /// DIRECTION: understated, and it is the ONLY caption in this group that runs
    /// that way. Hawaii's runs toward over-taxation and Massachusetts's toward
    /// UNDER-taxation, which is the more serious direction and is why it shipped
    /// when it did: the Task 4 rule excludes an own-state defined-benefit pension
    /// outright, and a noncontributory Massachusetts municipal pension is
    /// indistinguishable from a contributory one on every field the picker writes.
    /// A copy edit that harmonised this with any caption around it would invert
    /// it.
    ///
    /// The durable record is
    /// `GoldenScenarioDefectCatalogueTests.knownButUnpinned`; this is the only
    /// surface that reaches the affected user. Delete both together if a
    /// contributory axis is added.
    static let massachusettsContributoryCaption =
        "Massachusetts excludes a contributory state or local pension but taxes a "
        + "noncontributory one. This app does not model that distinction, so if your "
        + "pension is noncontributory your Massachusetts state tax may be understated."
    @Environment(DataManager.self) var dataManager
    @State private var showingAddIncome = false
    @State private var selectedIncomeSource: IncomeSource?
    @State private var showingAddDeduction = false
    @State private var selectedDeduction: DeductionItem?

    var body: some View {
        @Bindable var dataManager = dataManager
        ScrollView {
            VStack(spacing: 24) {
                // Total Income Card — uses canonical MetricCard
                MetricCard(
                    label: "Total income from sources",
                    value: dataManager.incomeBreakdown.allSources.formatted(.currency(code: "USD")),
                    category: .informational
                )
                IncomeBreakdownView(breakdown: dataManager.incomeBreakdown)

                // Income Sources List
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Income Sources")
                            .font(.headline)
                        TabPurposeChip(purpose: .inputs)

                        Spacer()

                        Button(action: { showingAddIncome = true }) {
                            Label("Add Income", systemImage: "plus.circle.fill")
                                .font(.callout)
                        }
                    }

                    if dataManager.incomeSources.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "dollarsign.circle")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)

                            Text("No income sources yet")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            Text("Add your income sources to calculate taxes")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            Button(action: { showingAddIncome = true }) {
                                Text("Add Income Source")
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .padding()
                                    .background(Color.UI.brandTeal)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                    } else {
                        if !dataManager.taxableAccounts.isEmpty
                            && dataManager.incomeSources.contains(where: { [.dividends, .qualifiedDividends, .interest, .capitalGainsShort, .capitalGainsLong, .taxExemptInterest].contains($0.type) }) {
                            Label("For the Multi-Year plan, investment income is derived from your taxable accounts. These entries are still used by the single-year Tax Summary, Scenarios, and Quarterly views.",
                                  systemImage: "info.circle")
                                .font(.caption).foregroundStyle(.secondary)
                                .padding(.bottom, 4)
                        }
                        ForEach(dataManager.incomeSources) { source in
                            IncomeRow(
                                source: source,
                                residenceHasPerSourceRules: PlanClassificationChoice.residenceHasPerSourceRules(dataManager.selectedState),
                                hasMixedPensionClassification: PlanClassificationChoice.hasMixedPensionClassification(
                                    in: dataManager.incomeSources, owner: source.owner)
                            )
                                .onTapGesture {
                                    selectedIncomeSource = source
                                    showingAddIncome = true
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        if let index = dataManager.incomeSources.firstIndex(where: { $0.id == source.id }) {
                                            dataManager.incomeSources.remove(at: index)
                                            dataManager.saveAllData()
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                .padding()
                .background(Color(PlatformColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)

                // MARK: - Deductions Section

                // U6: Forward-pointer to Scenarios for pre-tax contributions (Ron feedback)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.body)
                        .foregroundStyle(Color.accentColor)
                    Text("**Tip:** Pre-tax contributions (401(k), Traditional IRA, HSA) are modeled in the **Scenarios** tab where you can see their effect on Total Taxable in real time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.accentColor.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Standard vs Itemized Comparison Card
                deductionComparisonCard

                // Itemized Deductions List
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Itemized Deductions")
                            .font(.headline)

                        Spacer()

                        Button(action: { showingAddDeduction = true }) {
                            Label("Add Deduction", systemImage: "plus.circle.fill")
                                .font(.callout)
                        }
                    }

                    if dataManager.deductionItems.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)

                            Text("No itemized deductions")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("Add mortgage interest, property tax, and other deductions to compare against the standard deduction")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                    } else {
                        ForEach(dataManager.deductionItems) { item in
                            DeductionRow(item: item)
                                .onTapGesture {
                                    selectedDeduction = item
                                    showingAddDeduction = true
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        if let index = dataManager.deductionItems.firstIndex(where: { $0.id == item.id }) {
                                            dataManager.deductionItems.remove(at: index)
                                            dataManager.saveAllData()
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }

                    // Medical deduction threshold note
                    if dataManager.totalMedicalExpenses > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "cross.case.fill")
                                    .foregroundStyle(Color.UI.brandTeal)
                                Text("Medical Deduction")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Total Medical Expenses")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(dataManager.totalMedicalExpenses, format: .currency(code: "USD"))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                HStack {
                                    Text("7.5% of AGI Floor (\(dataManager.estimatedAGI.formatted(.currency(code: "USD"))))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("−\(dataManager.medicalAGIFloor.formatted(.currency(code: "USD")))")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.UI.textPrimary)
                                }
                                Divider()
                                HStack {
                                    Text("Deductible Amount")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(dataManager.deductibleMedicalExpenses, format: .currency(code: "USD"))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(dataManager.deductibleMedicalExpenses > 0 ? Color.UI.textPrimary : Color.UI.textSecondary)
                                }
                            }

                            Text("Only medical expenses exceeding 7.5% of your adjusted gross income (AGI) are deductible. AGI is estimated from your entered income sources and Scenario decisions. If you have above-the-line deductions (HSA, IRA contributions), your actual AGI may be slightly lower.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color.UI.surfaceInset)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Prior Year State Tax Balance
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(Color.UI.brandTeal)
                            Text("\(dataManager.priorPlanYear, format: .number.grouping(.never)) State Tax Balance")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Text("Balance Due Paid (or Refund)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            TextField("0", value: $dataManager.priorYearStateBalance, format: .currency(code: "USD"))
                                .font(.caption)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                                #if os(iOS)
                                .keyboardType(.numbersAndPunctuation)
                                #endif
                                .onChange(of: dataManager.priorYearStateBalance) {
                                    dataManager.saveAllData()
                                }
                        }

                        if dataManager.priorYearStateBalance > 0 {
                            Text("The balance due you paid with your \(dataManager.priorPlanYear, format: .number.grouping(.never)) state return is included in your SALT deduction.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else if dataManager.priorYearStateBalance < 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.Semantic.amber)
                                    .font(.caption2)
                                Text("A state tax refund may be taxable on your federal return if you itemized in \(dataManager.priorPlanYear, format: .number.grouping(.never)). Consider adding a \u{201C}State Tax Refund\u{201D} income source for \(abs(dataManager.priorYearStateBalance).formatted(.currency(code: "USD"))).")
                                    .font(.caption2)
                                    .foregroundStyle(Color.Semantic.amber)
                            }
                        }

                        Text("Enter the amount you paid with your \(dataManager.priorPlanYear, format: .number.grouping(.never)) state tax return (positive for balance due paid, negative for refund received).")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color.UI.surfaceInset)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // SALT plain-English intro (Item #13 — Ron Park feedback)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("State And Local Tax (SALT) deduction")
                            .font(.subheadline.weight(.semibold))
                        Text("Property tax + state income tax + local taxes are capped at \(dataManager.saltCap.formatted(.currency(code: "USD").precision(.fractionLength(0)))) in \(String(dataManager.currentYear)) under the OBBBA. If your total exceeds the cap, you lose the overage.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 8)

                    // SALT cap note
                    if dataManager.totalSALTBeforeCap > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "building.columns.fill")
                                    .foregroundStyle(Color.UI.brandTeal)
                                Text("SALT Deduction Cap")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }

                            // Component breakdown
                            VStack(alignment: .leading, spacing: 4) {
                                if dataManager.propertyTaxAmount > 0 {
                                    HStack {
                                        Text("Property Tax")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(dataManager.propertyTaxAmount, format: .currency(code: "USD"))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                }
                                if dataManager.totalStateWithholding > 0 {
                                    HStack {
                                        HStack(spacing: 4) {
                                            Text("State Withholding")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text("(from income sources)")
                                                .font(.caption2)
                                                .foregroundStyle(Color.UI.textSecondary)
                                        }
                                        Spacer()
                                        Text(dataManager.totalStateWithholding, format: .currency(code: "USD"))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                }
                                if dataManager.priorYearSALTDeductible > 0 {
                                    HStack {
                                        Text("\(dataManager.priorPlanYear, format: .number.grouping(.never)) Balance Due")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(dataManager.priorYearSALTDeductible, format: .currency(code: "USD"))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                }
                                if dataManager.additionalSALTAmount > 0 {
                                    HStack {
                                        Text("Additional SALT")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(dataManager.additionalSALTAmount, format: .currency(code: "USD"))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                }
                                if dataManager.autoEstimatedStatePayments > 0 {
                                    HStack {
                                        HStack(spacing: 4) {
                                            Text("Est. State Tax Payments")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text("(auto-calculated for \(dataManager.planYear, format: .number.grouping(.never)))")
                                                .font(.caption2)
                                                .foregroundStyle(Color.UI.textSecondary)
                                        }
                                        Spacer()
                                        Text(dataManager.autoEstimatedStatePayments, format: .currency(code: "USD"))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                }

                                Divider()

                                HStack {
                                    Text("Total SALT Before Cap")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(dataManager.totalSALTBeforeCap, format: .currency(code: "USD"))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                HStack {
                                    Text("Federal Cap")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(dataManager.saltCap, format: .currency(code: "USD"))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(dataManager.totalSALTBeforeCap > dataManager.saltCap ? Color.UI.textPrimary : Color.UI.textSecondary)
                                }
                                Divider()
                                HStack {
                                    Text("Deductible Amount")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(dataManager.saltAfterCap, format: .currency(code: "USD"))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(dataManager.totalSALTBeforeCap > dataManager.saltCap ? Color.Semantic.amber : Color.UI.textPrimary)
                                }
                            }

                            // Double-count warning
                            if dataManager.additionalSALTAmount > 0 && dataManager.totalStateWithholding > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(Color.Semantic.amber)
                                        .font(.caption2)
                                    Text("State withholding is now auto-included. If your \u{201C}State & Local Tax\u{201D} entries include withholding amounts, remove them to avoid double-counting.")
                                        .font(.caption2)
                                        .foregroundStyle(Color.Semantic.amber)
                                }
                            }

                            Text("SALT deductions \u{2014} property tax, state withholding, prior year balance due, and local taxes \u{2014} are capped at \(dataManager.saltCap.formatted(.currency(code: "USD").precision(.fractionLength(0)))) for \(String(dataManager.currentYear)) under the OBBBA. State withholding from your income sources and prior year balance due are included automatically. If you received a state tax refund and itemized last year, enter it as a \u{201C}State Tax Refund\u{201D} income source \u{2014} it\u{2019}s taxable on your federal return.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            if dataManager.stateHasIncomeTax {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "gearshape.2.fill")
                                            .foregroundStyle(Color.UI.brandTeal)
                                            .font(.caption2)
                                        Text("Smart SALT: Estimated State Payments")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.UI.brandTeal)
                                    }
                                    Text("The estimated state income tax you\u{2019}ll pay during \(String(dataManager.currentYear)) is deductible as SALT on your federal return. RetireSmart IRA automatically calculates this amount based on your income, accounts, and scenario decisions \u{2014} and includes it in your SALT total above. As you complete each tab (Social Security, Income, Accounts, Scenarios), this number updates automatically. No manual entry needed.")
                                        .font(.caption2)
                                        .foregroundStyle(Color.UI.brandTeal.opacity(0.8))
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.UI.surfaceInset)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Note about charitable deductions
                    if dataManager.scenarioTotalCharitable > 0 {
                        InlineHint("Charitable contributions of \(dataManager.scenarioTotalCharitable.formatted(.currency(code: "USD"))) from Scenarios are included in your itemized total.")
                            .padding(12)
                            .background(Color.UI.surfaceInset)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
                .background(Color(PlatformColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            }
            .padding()
        }
        .background(Color(PlatformColor.systemGroupedBackground))
        .sheet(isPresented: $showingAddIncome, onDismiss: {
            selectedIncomeSource = nil
        }) {
            AddIncomeView(incomeToEdit: selectedIncomeSource)
        }
        .sheet(isPresented: $showingAddDeduction, onDismiss: {
            selectedDeduction = nil
        }) {
            AddDeductionView(deductionToEdit: selectedDeduction)
        }
    }

    // MARK: - Deduction Comparison Card

    private var deductionComparisonCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Deduction Comparison")
                .font(.headline)

            HStack(spacing: 16) {
                // Standard
                VStack(spacing: 8) {
                    Text("Standard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(dataManager.standardDeductionAmount, format: .currency(code: "USD"))
                        .font(.title3)
                        .fontWeight(.bold)
                    if !dataManager.scenarioEffectiveItemize {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.UI.brandTeal)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background((!dataManager.scenarioEffectiveItemize ? Color.UI.brandTeal.opacity(0.10) : Color(PlatformColor.secondarySystemBackground)))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Itemized
                VStack(spacing: 8) {
                    Text("Itemized")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(dataManager.totalItemizedDeductions, format: .currency(code: "USD"))
                        .font(.title3)
                        .fontWeight(.bold)
                    if dataManager.scenarioEffectiveItemize {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.UI.brandTeal)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background((dataManager.scenarioEffectiveItemize ? Color.UI.brandTeal.opacity(0.10) : Color(PlatformColor.secondarySystemBackground)))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Override control
            HStack {
                Text("Deduction Method")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: Binding(
                    get: {
                        if let override = dataManager.deductionOverride {
                            return override == .standard ? 0 : 2
                        }
                        return 1 // auto
                    },
                    set: { newValue in
                        switch newValue {
                        case 0: dataManager.deductionOverride = .standard
                        case 2: dataManager.deductionOverride = .itemized
                        default: dataManager.deductionOverride = nil // auto
                        }
                        dataManager.saveAllData()
                    }
                )) {
                    Text("Standard").tag(0)
                    Text("Auto").tag(1)
                    Text("Itemized").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
            }

            if dataManager.deductionOverride == nil {
                Text("Auto compares your itemized total against the standard deduction and selects whichever saves you more — currently \(dataManager.recommendedDeductionType == .itemized ? "itemized" : "standard") (\(dataManager.effectiveDeductionAmount.formatted(.currency(code: "USD"))))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                Text("Tip: Auto compares your itemized total against the standard deduction and selects whichever saves you more.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Supporting Views

    struct IncomeRow: View {
        let source: IncomeSource
        /// Phase 3b Task 6: whether the taxpayer's residence carries a
        /// per-source retirement exemption rule at all. Computed by the
        /// caller (`PlanClassificationChoice.residenceHasPerSourceRules`)
        /// so this row stays a pure view over its inputs.
        let residenceHasPerSourceRules: Bool
        /// Whole-branch review Fix 2: whether `source`'s owner has other
        /// `.pension` rows that genuinely disagree with this one's
        /// classification. Computed by the caller
        /// (`PlanClassificationChoice.hasMixedPensionClassification`) so
        /// this row stays a pure view over its inputs.
        let hasMixedPensionClassification: Bool

        private var isManagedBySSPlanner: Bool {
            source.type == .socialSecurity && source.name.hasSuffix("(SS Planner)")
        }

        /// Spec section 3.7: a `.pension` row whose source is still
        /// unknown, in a state where classifying it could change the
        /// answer, shows a prominent prompt rather than a subtle optional
        /// field. Also shown (Fix 2) when the row IS classified but its
        /// owner's other pension rows disagree, since the adapter silently
        /// falls back to unclassified treatment in that case too.
        private var showsClassificationPrompt: Bool {
            PlanClassificationChoice.shouldPromptForClassification(
                source: source, residenceHasPerSourceRules: residenceHasPerSourceRules,
                hasMixedPensionClassification: hasMixedPensionClassification)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(source.name)
                                .font(.callout)
                                .fontWeight(.semibold)

                            Text(source.owner.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ownerColor.opacity(0.2))
                                .foregroundStyle(ownerColor)
                                .clipShape(Capsule())
                        }

                        HStack(spacing: 6) {
                            Text(source.type.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if isManagedBySSPlanner {
                                HStack(spacing: 3) {
                                    Image(systemName: "link")
                                        .font(.caption2)
                                    Text("Managed by SS Planner")
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.UI.brandTeal.opacity(0.10))
                                .foregroundStyle(Color.UI.brandTeal)
                                .clipShape(Capsule())
                            }
                        }
                    }

                    Spacer()

                    Text(source.annualAmount, format: .currency(code: "USD"))
                        .font(.title3)
                        .fontWeight(.bold)
                }

                if source.effectiveFederalWithholding > 0 || source.effectiveStateWithholding > 0 {
                    HStack(spacing: 8) {
                        Text("Withholding:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if source.effectiveFederalWithholding > 0 {
                            Text("Fed \(source.effectiveFederalWithholding, format: .currency(code: "USD"))")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        if source.effectiveStateWithholding > 0 {
                            Text("State \(source.effectiveStateWithholding, format: .currency(code: "USD"))")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }

                if showsClassificationPrompt {
                    HStack(spacing: 6) {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundStyle(Color.Semantic.amber)
                        Text("Is this a government pension? Tap to answer. It could change your state tax.")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.Semantic.amber)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.Semantic.amber.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
            .background(Color(PlatformColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        var ownerColor: Color {
            switch source.owner {
            case .primary: return Color.UI.brandTeal
            case .spouse: return Color.Chart.callout
            case .joint: return Color.Chart.gray2
            }
        }
    }

    struct DeductionRow: View {
        let item: DeductionItem

        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.callout)
                        .fontWeight(.semibold)
                    Text(item.type.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(item.annualAmount, format: .currency(code: "USD"))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.UI.textPrimary)
            }
            .padding()
            .background(Color(PlatformColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Add/Edit Income

    struct AddIncomeView: View {
        @Environment(DataManager.self) var dataManager
        @Environment(\.dismiss) var dismiss
        var incomeToEdit: IncomeSource?

        @State private var name: String
        @State private var incomeType: IncomeType
        @State private var annualAmount: String
        @State private var federalWithholding: String
        @State private var federalWithholdingPercent: String
        @State private var stateWithholding: String
        @State private var owner: Owner
        @State private var showDeleteConfirmation = false
        /// Social Security federal withholding is a rate (IRS Form W-4V), not
        /// a free-form dollar entry. Only read/written when incomeType == .socialSecurity.
        @State private var ssWithholdingRate: SSWithholdingRate
        /// $/% mode for federal withholding on non-SS sources (Alan feedback #5b).
        /// Only read/written when incomeType != .socialSecurity.
        @State private var federalWithholdingMode: FederalWithholdingMode
        /// $/% mode for STATE withholding (Alan 2nd-round feedback). Applies to every
        /// source type (no state W-4V), so it is read/written regardless of incomeType.
        @State private var stateWithholdingMode: FederalWithholdingMode
        @State private var stateWithholdingPercent: String
        /// Phase 3b Task 6: the picker's current selection. Only consulted
        /// when `incomeType == .pension` (see `saveIncome()`), so editing a
        /// non-pension row is byte-for-byte unaffected by this field.
        @State private var planChoice: PlanClassificationChoice
        /// Phase 5b Task 9: the survivor-benefit answer, shown only where a
        /// jurisdiction's rules actually consult it
        /// (`PlanClassificationChoice.residenceUsesSurvivorDimension`).
        ///
        /// `Bool` here, `Bool?` on `IncomeSource`, and `saveIncome()` is where
        /// the two meet. A SwiftUI `Toggle` has no third position, so an
        /// unanswered question cannot be represented in the control; what
        /// represents it is the question NOT BEING SHOWN. See `saveIncome()`
        /// for the mapping, which never turns "never asked" into "no".
        @State private var isSurvivorBenefit: Bool

        init(incomeToEdit: IncomeSource? = nil) {
            self.incomeToEdit = incomeToEdit
            _name = State(initialValue: incomeToEdit?.name ?? "")
            _incomeType = State(initialValue: incomeToEdit?.type ?? .socialSecurity)
            _annualAmount = State(initialValue: incomeToEdit?.annualAmount.formatted() ?? "")
            _federalWithholding = State(initialValue: incomeToEdit?.federalWithholding.formatted() ?? "")
            _federalWithholdingPercent = State(initialValue: incomeToEdit.map { $0.federalWithholdingPercent == 0 ? "" : $0.federalWithholdingPercent.formatted() } ?? "")
            _stateWithholding = State(initialValue: incomeToEdit?.stateWithholding.formatted() ?? "")
            _stateWithholdingPercent = State(initialValue: incomeToEdit.map { $0.stateWithholdingPercent == 0 ? "" : $0.stateWithholdingPercent.formatted() } ?? "")
            // State withholding defaults to $ (W-2 Box 17 is a dollar figure); percent is opt-in.
            // Legacy/new sources open in .dollars so nothing is silently reinterpreted.
            _stateWithholdingMode = State(initialValue: incomeToEdit?.stateWithholdingMode ?? .dollars)
            _owner = State(initialValue: incomeToEdit?.owner ?? .primary)

            // Migration + initial rate selection for the SS withholding picker.
            // - Modern SS source (rate already set): use it as-is.
            // - Legacy SS source (rate nil, dollar withholding stored): suggest
            //   the nearest legal rate as a starting point — never applied
            //   silently, only pre-selected for the user to confirm/change.
            // - New source or non-SS source being edited: default to .none.
            if let editing = incomeToEdit, editing.type == .socialSecurity {
                if let rate = editing.ssWithholdingRate {
                    _ssWithholdingRate = State(initialValue: rate)
                } else {
                    let legacyFraction = editing.annualAmount > 0 ? editing.federalWithholding / editing.annualAmount : 0
                    _ssWithholdingRate = State(initialValue: SSWithholdingRate.nearest(toFraction: legacyFraction))
                }
            } else {
                _ssWithholdingRate = State(initialValue: .none)
            }

            // $/% mode for non-SS sources (Alan feedback #5b).
            // - Modern non-SS source (mode already set): use it as-is.
            // - Legacy non-SS source (mode nil, dollar withholding possibly
            //   stored): open in .dollars so nothing changes until the user
            //   toggles — never silently reinterpreted as a percent.
            // - Brand-new source: default to .percent per the plan.
            if let editing = incomeToEdit, editing.type != .socialSecurity {
                _federalWithholdingMode = State(initialValue: editing.federalWithholdingMode ?? .dollars)
            } else {
                _federalWithholdingMode = State(initialValue: .percent)
            }

            // Phase 3b Task 6: pre-select the picker against the row's
            // existing classification (unknown/unknown, i.e. "Not sure",
            // for both a brand-new row and any pre-3b row that has never
            // been classified).
            let existingClassification = RetirementPlanClassification(
                structure: incomeToEdit?.planStructure ?? .unknown,
                source: incomeToEdit?.planSource ?? .unknown)
            _planChoice = State(initialValue: PlanClassificationChoice.choice(for: existingClassification))
            // Phase 5b Task 9. A row that has never been asked (nil) opens with
            // the toggle OFF, which is the only thing a two-position control
            // can show. It is NOT saved as `false` unless the question was
            // actually on screen; see `saveIncome()`.
            _isSurvivorBenefit = State(initialValue: incomeToEdit?.isSurvivorBenefit ?? false)
        }

        /// True when editing an existing Social Security source that has a
        /// legacy dollar withholding but no rate saved yet. Drives the
        /// one-time migration caption in the picker section.
        private var isUnmigratedLegacySSSource: Bool {
            guard let editing = incomeToEdit else { return false }
            return editing.type == .socialSecurity && editing.ssWithholdingRate == nil && editing.federalWithholding > 0
        }

        /// Dynamic state-treatment hint for Military Retirement, based on the user's
        /// state of residence and the owner's current age. Returns a small Text view
        /// indicating whether the selected state fully exempts, partially exempts, or
        /// taxes military retirement pay.
        @ViewBuilder
        private var stateTreatmentHint: some View {
            let stateCode = dataManager.selectedState.abbreviation
            let ownerAge = (owner == .spouse) ? dataManager.spouseDisplayAge : dataManager.displayAge
            let exemption = MilitaryRetirementExemption.exemption(for: stateCode, age: ownerAge)
            let stateName = dataManager.selectedState.rawValue

            switch exemption {
            case .fullyExempt:
                Label("Fully exempt from \(stateName) state tax", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
            case .noStateIncomeTax:
                Label("\(stateName) has no state income tax", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
            case .partiallyExempt(let percentTaxable, _):
                let percentExempt = Int((1.0 - percentTaxable) * 100)
                Label("Partially exempt: ~\(percentExempt)% excluded from \(stateName) state tax", systemImage: "checkmark.seal")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            case .fullyTaxable:
                Label("Subject to \(stateName) state tax (no military exemption)", systemImage: "info.circle")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }

        var body: some View {
            NavigationStack {
                Form {
                    Section("Income Details") {
                        TextField("Description", text: $name)

                        Picker("Income Type", selection: $incomeType) {
                            ForEach(IncomeType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }

                        TextField("Annual Amount", text: $annualAmount)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif

                        if incomeType == .socialSecurity {
                            Picker("Federal Withholding", selection: $ssWithholdingRate) {
                                ForEach(SSWithholdingRate.allCases, id: \.self) { rate in
                                    Text(rate.label).tag(rate)
                                }
                            }

                            Text(isUnmigratedLegacySSSource
                                 ? "Social Security federal withholding is now a percentage (IRS Form W-4V: 7, 10, 12, or 22%). We picked the closest match to your prior amount. Review and save to confirm."
                                 : "Social Security federal withholding is a percentage (IRS Form W-4V: 7, 10, 12, or 22%).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Federal Withholding Entry", selection: $federalWithholdingMode) {
                                Text("$").tag(FederalWithholdingMode.dollars)
                                Text("%").tag(FederalWithholdingMode.percent)
                            }
                            .pickerStyle(.segmented)

                            if federalWithholdingMode == .percent {
                                TextField("Federal Withholding %", text: $federalWithholdingPercent)
                                    #if os(iOS)
                                    .keyboardType(.decimalPad)
                                    #endif
                            } else {
                                TextField("Annual Federal Withholding (W-2 Box 2, optional)", text: $federalWithholding)
                                    #if os(iOS)
                                    .keyboardType(.decimalPad)
                                    #endif
                            }
                        }

                        Picker("State Withholding Entry", selection: $stateWithholdingMode) {
                            Text("$").tag(FederalWithholdingMode.dollars)
                            Text("%").tag(FederalWithholdingMode.percent)
                        }
                        .pickerStyle(.segmented)

                        if stateWithholdingMode == .percent {
                            TextField("State Withholding %", text: $stateWithholdingPercent)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                        } else {
                            TextField("Annual State Withholding (W-2 Box 17, optional)", text: $stateWithholding)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                        }

                        Picker("Owner", selection: $owner) {
                            ForEach(Owner.allCases, id: \.self) { owner in
                                Text(owner.rawValue).tag(owner)
                            }
                        }
                    }

                    // IRA/401(k) pointer — Item #14 (Ron feedback)
                    Section {
                        DisclosureGroup("Looking for IRA / 401(k) discretionary withdrawals?") {
                            Text("Use the **Scenarios** tab (Tax Planning) to model discretionary withdrawals. The Income page handles required income — RMDs are auto-calculated based on age.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                        }
                        .font(.caption)
                    }

                    if incomeType == .consulting {
                        Section("About Employment / W-2 Income") {
                            Text("Enter **W-2 Box 1** — Wages, tips, other compensation. This is the amount *after* any pre-tax 401(k), HSA, or FSA contributions.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Do not use Box 3 (Social Security wages), which is typically larger because it excludes only the 401(k) portion. Box 1 is what flows to line 1a of your Form 1040.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Self-employment / 1099 income goes here too — use your net profit after business expenses.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if incomeType == .interest {
                        Section("About Taxable Interest") {
                            Text("Enter taxable interest from bank accounts, CDs, Treasuries, corporate bonds, and money-market funds — Form 1099-INT Box 1. This is what the IRS taxes at ordinary income rates.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Don't use this for municipal bond interest — select 'Tax-Exempt Interest' instead. Don't use this for mortgage interest you paid (that's an itemized deduction, not income).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if incomeType == .dividends {
                        Section("About Ordinary Dividends") {
                            Text("Enter ordinary (non-qualified) dividends from Form 1099-DIV. These are taxed at your ordinary income rate.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("The value to enter is **Box 1a minus Box 1b** (total ordinary dividends minus the qualified portion). If your 1099-DIV shows a non-zero Box 1b, create a separate entry using the 'Qualified Dividends' type for that amount — qualified dividends are taxed at capital-gains rates.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if incomeType == .qualifiedDividends {
                        Section("About Qualified Dividends") {
                            Text("Enter the qualified-dividend portion from Form 1099-DIV **Box 1b**. Qualified dividends are taxed at the preferential capital-gains rates (0% / 15% / 20%) instead of ordinary income rates.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("If you also have non-qualified dividends (Box 1a minus Box 1b), add a separate entry with type 'Ordinary Dividends'.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if incomeType == .pension {
                        Section("What kind of pension is this?") {
                            Picker("Plan type", selection: $planChoice) {
                                ForEach(PlanClassificationChoice.options(
                                    for: dataManager.selectedState, selected: planChoice)) { choice in
                                    Text(choice.label).tag(choice)
                                }
                            }
                            Text("Some states, including New York and Kansas, tax government and private pensions differently. Answering helps this app compute your state tax correctly.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            // Phase 5b Task 9. Toggle label and caption
                            // APPROVED by John on 2026-08-05, as written. The
                            // caption text now lives in IncomeSourcesView
                            // .districtOfColumbiaSurvivorToggleCaption; reword
                            // it there, plus the assertions in
                            // Phase5bDCSurvivorTests and
                            // StateAccuracyContentTests. The toggle LABEL is
                            // still a literal below and is approved copy too.
                            //
                            // Shown only where a jurisdiction's shipped rules
                            // consult the survivor dimension, which today is
                            // the District of Columbia alone. Without this
                            // control DC's rule would be UNREACHABLE: no
                            // combination of the twelve picker rows can write
                            // `isSurvivorBenefit`, so every DC golden case
                            // would go green while a real survivor annuitant
                            // received nothing. That is exactly the failure
                            // Task 3 found for Kansas and the precedent it set
                            // for adding an affordance here.
                            if PlanClassificationChoice.residenceUsesSurvivorDimension(dataManager.selectedState) {
                                Toggle("I receive this as a survivor or beneficiary",
                                       isOn: $isSurvivorBenefit)
                                Text(IncomeSourcesView.districtOfColumbiaSurvivorToggleCaption)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if dataManager.selectedState == .hawaii {
                                Label(IncomeSourcesView.hawaiiEmployerFundedCaption,
                                      systemImage: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            // Phase 5b Task 4. Copy APPROVED by John on
                            // 2026-08-05; see IncomeSourcesView
                            // .massachusettsContributoryCaption for why it is
                            // modelled on the Hawaii caption above and why its
                            // direction is the opposite one. Massachusetts runs
                            // toward UNDER-taxation, the only caption in this
                            // group that does.
                            if dataManager.selectedState == .massachusetts {
                                Label(IncomeSourcesView.massachusettsContributoryCaption,
                                      systemImage: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            // Phase 5b Task 7. Copy APPROVED by John on
                            // 2026-08-05; see IncomeSourcesView
                            // .northCarolinaBaileyCaption for why North Carolina
                            // ships a caption and no rule, and what this text
                            // must not be turned into. (That cross-reference
                            // used to read "why it ships unapproved", written
                            // before John's approval landed three lines above
                            // and left uncorrected when it did.)
                            // Direction is the opposite of Massachusetts's
                            // directly above: North Carolina applies no Bailey
                            // exclusion at all, so its error runs toward
                            // OVER-taxation.
                            if dataManager.selectedState == .northCarolina {
                                Label(IncomeSourcesView.northCarolinaBaileyCaption,
                                      systemImage: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            // Phase 5b Task 8. Copy APPROVED by John on
                            // 2026-08-05; see IncomeSourcesView
                            // .idahoRetirementBenefitsDeductionCaption for why
                            // Idaho ships a caption and no rule. Same direction
                            // as North Carolina directly above, OVER-taxation:
                            // Idaho applies no Retirement Benefits Deduction at
                            // all today.
                            if dataManager.selectedState == .idaho {
                                Label(IncomeSourcesView.idahoRetirementBenefitsDeductionCaption,
                                      systemImage: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            // Phase 5b Task 9. Copy APPROVED by John on
                            // 2026-08-05, as written; see IncomeSourcesView
                            // .vermontRetirementExclusionCaption for why
                            // Vermont ships a caption and no rule, and for the
                            // two shapes that were measured and declined. Same
                            // direction as North Carolina and Idaho above,
                            // OVER-taxation: Vermont applies neither exclusion
                            // today, and its gap is the largest in this phase.
                            if dataManager.selectedState == .vermont {
                                Label(IncomeSourcesView.vermontRetirementExclusionCaption,
                                      systemImage: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if incomeType == .stateTaxRefund {
                        Section("About State Tax Refunds") {
                            Text("If you itemized deductions last year and received a state tax refund, that refund is taxable as income on your federal return (tax benefit rule). If you took the standard deduction last year, the refund is not taxable and does not need to be entered here.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if incomeType == .taxExemptInterest {
                        Section("About Tax-Exempt Interest") {
                            Text("Enter interest from municipal bond funds, tax-free money market funds, and individual muni bonds. This income is not subject to federal income tax, but the IRS includes it in the MAGI used to calculate IRMAA Medicare premium surcharges and Social Security taxation.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("State tax note: National muni funds may hold bonds from other states. The out-of-state portion is generally taxable by your state. Your fund company provides a year-end state breakdown. This app treats all tax-exempt interest as state-exempt for simplicity.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if incomeType == .militaryRetirement {
                        Section("About Military Retirement Pay") {
                            Text("Enter the **gross distribution** from DFAS Form 1099-R Box 1 (taxable amount in Box 2a). Military retirement pay is federally taxable as ordinary income — it behaves like a pension at the federal level.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("State tax: approximately 30 states fully or partially exempt military retirement from state income tax. The app uses your state of residence to apply the correct treatment.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            stateTreatmentHint
                            Text("Do not include VA disability compensation here — that is federally tax-exempt and modeled separately.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if incomeType == .vaDisability {
                        Section("About VA Disability Compensation") {
                            Text("VA Disability compensation is **fully excluded from gross income** under IRC §104(a)(4). It is never subject to federal income tax, state income tax, or the Social Security provisional income test — regardless of your rating or the amount received.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Enter your annual benefit here for budgeting purposes. This app correctly treats it as tax-exempt: it will not appear in your federal AGI, state taxable income, MAGI for ACA or IRMAA, or any other tax calculation.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Delete button — only visible when editing an existing income source
                    if incomeToEdit != nil {
                        Section {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Label("Delete Income Source", systemImage: "trash")
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .navigationTitle(incomeToEdit == nil ? "Add Income" : "Edit Income")
                #if os(iOS)
                #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveIncome() }
                            .disabled(name.isEmpty || annualAmount.isEmpty)
                    }
                }
                .dismissableKeyboard()
                .alert("Delete Income Source", isPresented: $showDeleteConfirmation) {
                    Button("Delete", role: .destructive) {
                        if let source = incomeToEdit,
                           let index = dataManager.incomeSources.firstIndex(where: { $0.id == source.id }) {
                            dataManager.incomeSources.remove(at: index)
                            dataManager.saveAllData()
                            dismiss()
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Are you sure you want to delete this income source? This cannot be undone.")
                }
            }
        }

        private func saveIncome() {
            let cleanAmount = annualAmount.replacingOccurrences(of: ",", with: "")
            let cleanFederal = federalWithholding.replacingOccurrences(of: ",", with: "")
            let cleanFederalPercent = federalWithholdingPercent.replacingOccurrences(of: ",", with: "")
            let cleanState = stateWithholding.replacingOccurrences(of: ",", with: "")
            let cleanStatePercent = stateWithholdingPercent.replacingOccurrences(of: ",", with: "")
            guard let amount = Double(cleanAmount) else { return }

            // State withholding $/% (Alan 2nd-round). Applies to every type (no state W-4V).
            // In .percent mode the entered percent is the source of truth and mirrors its
            // resolved dollars into stateWithholding for any as-yet-unrouted reader; in
            // .dollars mode behavior is byte-identical to before this feature.
            let stMode: FederalWithholdingMode? = stateWithholdingMode
            let stateWH: Double
            let statePercent: Double
            if stateWithholdingMode == .percent {
                let p = Double(cleanStatePercent) ?? 0
                statePercent = p
                stateWH = (p / 100) * max(0, amount)
            } else {
                statePercent = 0
                stateWH = Double(cleanState) ?? 0
            }

            // Social Security federal withholding is a rate (Form W-4V), not a
            // free-form dollar entry. Saving an SS source sets ssWithholdingRate
            // as the source of truth going forward, and mirrors the resolved
            // dollar amount into federalWithholding so any as-yet-unrouted
            // reader still sees an accurate figure. Non-SS sources use the
            // $/% toggle (Alan feedback #5b): in .percent mode the entered
            // percent is the source of truth and mirrors its resolved dollar
            // amount into federalWithholding the same way; in .dollars mode
            // behavior is byte-identical to before this feature shipped.
            let fedWH: Double
            let ssRate: SSWithholdingRate?
            let whMode: FederalWithholdingMode?
            let whPercent: Double
            if incomeType == .socialSecurity {
                ssRate = ssWithholdingRate
                fedWH = ssWithholdingRate.fraction * amount
                whMode = nil
                whPercent = 0
            } else {
                ssRate = nil
                whMode = federalWithholdingMode
                if federalWithholdingMode == .percent {
                    let percentValue = Double(cleanFederalPercent) ?? 0
                    whPercent = percentValue
                    fedWH = (percentValue / 100) * max(0, amount)
                } else {
                    whPercent = 0
                    fedWH = Double(cleanFederal) ?? 0
                }
            }

            // Phase 3b Task 6, hoisted to a testable static for whole-branch
            // review Fix 3: only a `.pension` row is classified through
            // this picker. Passing `nil` for every other type leaves
            // `IncomeSource.init`'s own inference in charge (ira/individual
            // for `.rmd`, unknown/unknown otherwise), exactly as before this
            // task, so switching a row's type away from `.pension` cannot
            // leave a stray pension classification on unrelated income. See
            // `PlanClassificationChoice.classificationToSave(incomeType:choice:)`.
            let classificationToSave = PlanClassificationChoice.classificationToSave(incomeType: incomeType, choice: planChoice)
            let explicitStructure = classificationToSave?.structure
            let explicitSource = classificationToSave?.source

            // Phase 5b Task 9: `Bool` control -> `Bool?` model, and the whole
            // point is the third value.
            //
            //   question shown        -> save the toggle, true OR false. The
            //                            user saw it and answered.
            //   question NOT shown    -> keep whatever the row already carried,
            //                            which is `nil` for every row that has
            //                            never been asked.
            //
            // The second branch is what stops a Kansas resident's pension from
            // being silently stamped "not a survivor benefit" by an editor that
            // never asked, and what stops a DC resident who moves to Kansas from
            // losing an answer they already gave. Also gated on `.pension`, the
            // same way `classificationToSave` is: switching a row's type away
            // from pension must not leave a stray survivor fact behind.
            let survivorToSave: Bool?
            if incomeType == .pension,
               PlanClassificationChoice.residenceUsesSurvivorDimension(dataManager.selectedState) {
                survivorToSave = isSurvivorBenefit
            } else {
                survivorToSave = incomeType == .pension ? incomeToEdit?.isSurvivorBenefit : nil
            }

            if let existing = incomeToEdit,
               let index = dataManager.incomeSources.firstIndex(where: { $0.id == existing.id }) {
                dataManager.incomeSources[index] = IncomeSource(
                    id: existing.id, name: name, type: incomeType,
                    annualAmount: amount, federalWithholding: fedWH, stateWithholding: stateWH, owner: owner,
                    ssWithholdingRate: ssRate, federalWithholdingMode: whMode, federalWithholdingPercent: whPercent,
                    stateWithholdingMode: stMode, stateWithholdingPercent: statePercent,
                    planStructure: explicitStructure, planSource: explicitSource,
                    isSurvivorBenefit: survivorToSave
                )
            } else {
                dataManager.incomeSources.append(IncomeSource(
                    name: name, type: incomeType,
                    annualAmount: amount, federalWithholding: fedWH, stateWithholding: stateWH, owner: owner,
                    ssWithholdingRate: ssRate, federalWithholdingMode: whMode, federalWithholdingPercent: whPercent,
                    stateWithholdingMode: stMode, stateWithholdingPercent: statePercent,
                    planStructure: explicitStructure, planSource: explicitSource,
                    isSurvivorBenefit: survivorToSave
                ))
            }
            dataManager.saveAllData()
            dismiss()
        }
    }

    // MARK: - Add/Edit Deduction

    struct AddDeductionView: View {
        @Environment(DataManager.self) var dataManager
        @Environment(\.dismiss) var dismiss
        var deductionToEdit: DeductionItem?

        @State private var name: String
        @State private var deductionType: DeductionType
        @State private var annualAmount: String
        @State private var owner: Owner
        @State private var showDeleteConfirmation = false

        init(deductionToEdit: DeductionItem? = nil) {
            self.deductionToEdit = deductionToEdit
            _name = State(initialValue: deductionToEdit?.name ?? "")
            _deductionType = State(initialValue: deductionToEdit?.type ?? .mortgageInterest)
            _annualAmount = State(initialValue: deductionToEdit?.annualAmount.formatted() ?? "")
            _owner = State(initialValue: deductionToEdit?.owner ?? .primary)
        }

        var body: some View {
            NavigationStack {
                Form {
                    Section("Deduction Details") {
                        TextField("Description", text: $name)

                        Picker("Type", selection: $deductionType) {
                            ForEach(DeductionType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }

                        TextField("Annual Amount", text: $annualAmount)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif

                        Picker("Owner", selection: $owner) {
                            ForEach(Owner.allCases, id: \.self) { owner in
                                Text(owner.rawValue).tag(owner)
                            }
                        }
                    }

                    if deductionType == .medicalExpenses {
                        Section("About Medical Deductions") {
                            Text("Enter your total unreimbursed medical expenses (insurance premiums, copays, prescriptions, dental, vision, long-term care, etc.). Only the amount exceeding 7.5% of your adjusted gross income (AGI) is deductible \u{2014} the app calculates this automatically. For most retirees, AGI is essentially your total taxable income before itemized/standard deductions.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if deductionType == .saltTax {
                        Section("About SALT Deductions") {
                            Text("State withholding from your income sources and any prior year state tax balance due are now automatically included in your SALT deduction. Use this field only for additional local or city income taxes not already captured. Combined with property taxes, SALT is capped at \(dataManager.saltCap.formatted(.currency(code: "USD").precision(.fractionLength(0)))) for \(String(dataManager.currentYear)) under the OBBBA (2025\u{2013}2029: $40,000 base with 1% inflation; phases out for MAGI over $500K; reverts to $10,000 in 2030).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if deductionType == .propertyTax {
                        Section("About Property Tax Deductions") {
                            Text("Enter your annual property tax amount. Property taxes are combined with state and local income taxes for the SALT deduction, which is capped at \(dataManager.saltCap.formatted(.currency(code: "USD").precision(.fractionLength(0)))) for \(String(dataManager.currentYear)) under the OBBBA (2025\u{2013}2029: $40,000 base with 1% inflation; phases out for MAGI over $500K; reverts to $10,000 in 2030).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Delete button — only visible when editing an existing deduction
                    if deductionToEdit != nil {
                        Section {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Label("Delete Deduction", systemImage: "trash")
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .navigationTitle(deductionToEdit == nil ? "Add Deduction" : "Edit Deduction")
                #if os(iOS)
                #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveDeduction() }
                            .disabled(name.isEmpty || annualAmount.isEmpty)
                    }
                }
                .dismissableKeyboard()
                .alert("Delete Deduction", isPresented: $showDeleteConfirmation) {
                    Button("Delete", role: .destructive) {
                        if let item = deductionToEdit,
                           let index = dataManager.deductionItems.firstIndex(where: { $0.id == item.id }) {
                            dataManager.deductionItems.remove(at: index)
                            dataManager.saveAllData()
                            dismiss()
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Are you sure you want to delete this deduction? This cannot be undone.")
                }
            }
        }

        private func saveDeduction() {
            let cleanAmount = annualAmount.replacingOccurrences(of: ",", with: "")
            guard let amount = Double(cleanAmount) else { return }

            if let existing = deductionToEdit,
               let index = dataManager.deductionItems.firstIndex(where: { $0.id == existing.id }) {
                dataManager.deductionItems[index] = DeductionItem(
                    id: existing.id, name: name, type: deductionType,
                    annualAmount: amount, owner: owner
                )
            } else {
                dataManager.deductionItems.append(DeductionItem(
                    name: name, type: deductionType,
                    annualAmount: amount, owner: owner
                ))
            }
            dataManager.saveAllData()
            dismiss()
        }
    }
}
