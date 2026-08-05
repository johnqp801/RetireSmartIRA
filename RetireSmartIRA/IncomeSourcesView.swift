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
    /// The three Phase 5b rows carry PROPOSED working copy that John has not
    /// approved. They are deliberately plain rather than clever so renaming
    /// them is a one-line change with no behavioral consequence: nothing
    /// keys on a label, and what a row PERSISTS is the
    /// `RetirementPlanClassification` its `classification` returns, not any
    /// text and not the case's `rawValue`.
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
    static func choice(for classification: RetirementPlanClassification) -> PlanClassificationChoice {
        let priorityOrder: [PlanClassificationChoice] = [
            .nyGovernmentPension, .ownStateGovernmentPension, .federalCivilianPension,
            .uniformedServicesPension, .railroadRetirementPension,
            .otherStateGovernmentPension,
            .privateEmployerPension, .governmentSalaryReduction, .employer401k,
            .privateSalaryReduction, .ira, .notSure
        ]
        return priorityOrder.first(where: { $0.classification == classification }) ?? .notSure
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
    /// source", not "does it name ITS OWN". Nothing triggers the difference
    /// today, since `nyStateOrLocal` is the only such case and only New
    /// York's config names it, but the name is now true rather than
    /// accidentally true.
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
}

struct IncomeSourcesView: View {
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

                            if dataManager.selectedState == .hawaii {
                                Label("Hawaii excludes the employer-funded portion of a pension from state tax. This app does not model the split between employer-funded and employee-contributed amounts, so your Hawaii state tax may be overstated.",
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

            if let existing = incomeToEdit,
               let index = dataManager.incomeSources.firstIndex(where: { $0.id == existing.id }) {
                dataManager.incomeSources[index] = IncomeSource(
                    id: existing.id, name: name, type: incomeType,
                    annualAmount: amount, federalWithholding: fedWH, stateWithholding: stateWH, owner: owner,
                    ssWithholdingRate: ssRate, federalWithholdingMode: whMode, federalWithholdingPercent: whPercent,
                    stateWithholdingMode: stMode, stateWithholdingPercent: statePercent,
                    planStructure: explicitStructure, planSource: explicitSource
                )
            } else {
                dataManager.incomeSources.append(IncomeSource(
                    name: name, type: incomeType,
                    annualAmount: amount, federalWithholding: fedWH, stateWithholding: stateWH, owner: owner,
                    ssWithholdingRate: ssRate, federalWithholdingMode: whMode, federalWithholdingPercent: whPercent,
                    stateWithholdingMode: stMode, stateWithholdingPercent: statePercent,
                    planStructure: explicitStructure, planSource: explicitSource
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
