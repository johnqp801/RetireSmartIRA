//
//  SSDataEntryView.swift
//  RetireSmartIRA
//
//  Entry sheet for Social Security benefit data — Quick Entry (3 SSA numbers)
//  or Import Earnings History (paste from SSA statement for AIME/PIA calculation).
//

import SwiftUI
import UniformTypeIdentifiers

struct SSDataEntryView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedOwner: Owner = .primary
    @State private var entryMode: EntryMode
    @State private var showXMLImporter: Bool = false
    @FocusState private var focusedBenefitField: BenefitFieldID?

    enum EntryMode: String, CaseIterable {
        case quickEntry = "Quick Entry"
        case earningsHistory = "Earnings History"
    }

    /// Identifies each monthly-benefit TextField so the entire row (including the
    /// "$" prefix and "/mo" suffix) can act as a tap target for focusing the field.
    enum BenefitFieldID: Hashable {
        case at62, atFRA, at70, currentBenefit
    }

    /// When true, the primary "Already Receiving" toggle is pre-set on first load (before any existing data overrides it).
    private let presetAlreadyClaiming: Bool

    init(initialMode: EntryMode = .quickEntry, presetAlreadyClaiming: Bool = false) {
        _entryMode = State(initialValue: initialMode)
        self.presetAlreadyClaiming = presetAlreadyClaiming
    }

    // Already-claiming state
    @State private var primaryAlreadyClaiming: Bool = false
    @State private var primaryCurrentBenefit: String = ""
    @State private var spouseAlreadyClaiming: Bool = false
    @State private var spouseCurrentBenefit: String = ""

    // Local editing state for primary
    @State private var primaryAt62: String = ""
    @State private var primaryAtFRA: String = ""
    @State private var primaryAt70: String = ""
    @State private var primaryClaimingAge: Int = 67

    // Local editing state for spouse
    @State private var spouseAt62: String = ""
    @State private var spouseAtFRA: String = ""
    @State private var spouseAt70: String = ""
    @State private var spouseClaimingAge: Int = 67

    // Earnings paste state
    @State private var pasteText: String = ""
    @State private var parsedRecords: [SSEarningsRecord] = []
    @State private var parseSkipped: [String] = []
    @State private var parseError: String?
    @State private var hasParsed: Bool = false
    @State private var futureEarnings: String = ""
    @State private var futureYears: String = ""
    @State private var piaResult: SSPIAResult?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Entry mode picker
                    Picker("Entry Mode", selection: $entryMode) {
                        ForEach(EntryMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if entryMode == .quickEntry {
                        quickEntryContent
                    } else {
                        earningsHistoryContent
                    }
                }
                .padding()
            }
            .background(Color(PlatformColor.systemGroupedBackground))
            .navigationTitle("Social Security Benefits")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveData()
                        dismiss()
                    }
                }
            }
            .onAppear { loadExistingData() }
            #if os(iOS)
            .fileImporter(
                isPresented: $showXMLImporter,
                allowedContentTypes: [UTType.xml],
                allowsMultipleSelection: false
            ) { result in
                handleXMLImport(result)
            }
            #endif
        }
        #if os(macOS)
        .onChange(of: showXMLImporter) { _, show in
            if show {
                showXMLImporter = false
                openXMLWithNSOpenPanel()
            }
        }
        #endif
    }

    // MARK: - Quick Entry Content

    private var quickEntryContent: some View {
        let isP = selectedOwner == .primary
        let alreadyClaiming = isP ? primaryAlreadyClaiming : spouseAlreadyClaiming

        return VStack(spacing: 20) {
            instructionCard

            if dataManager.enableSpouse {
                Picker("Person", selection: $selectedOwner) {
                    Text(dataManager.userName.isEmpty ? "You" : dataManager.userName).tag(Owner.primary)
                    Text(dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName).tag(Owner.spouse)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }

            // Already Claiming toggle
            alreadyClaimingToggle

            if alreadyClaiming {
                // Entry for people already receiving SS
                alreadyClaimingCard

                // SSA estimates — needed for couples strategy & spousal top-up
                if dataManager.enableSpouse {
                    alreadyClaimingEstimatesCard
                }
            } else {
                // Standard planning entry
                if selectedOwner == .primary {
                    benefitEntryCard(
                        title: dataManager.userName.isEmpty ? "Your Benefits" : "\(dataManager.userName)'s Benefits",
                        fra: dataManager.primaryFRA,
                        at62: $primaryAt62,
                        atFRA: $primaryAtFRA,
                        at70: $primaryAt70,
                        claimingAge: $primaryClaimingAge,
                        birthYear: dataManager.birthYear
                    )
                } else {
                    benefitEntryCard(
                        title: dataManager.spouseName.isEmpty ? "Spouse's Benefits" : "\(dataManager.spouseName)'s Benefits",
                        fra: dataManager.spouseFRA,
                        at62: $spouseAt62,
                        atFRA: $spouseAtFRA,
                        at70: $spouseAt70,
                        claimingAge: $spouseClaimingAge,
                        birthYear: dataManager.spouseBirthYear
                    )
                }

                benefitPreviewCard
            }
        }
    }

    // MARK: - Already Claiming Toggle

    private var alreadyClaimingToggle: some View {
        let binding = selectedOwner == .primary
            ? $primaryAlreadyClaiming
            : $spouseAlreadyClaiming

        return Toggle(isOn: binding) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Already Receiving Benefits")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Turn on if you're already collecting Social Security")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Already Claiming Card

    private var alreadyClaimingCard: some View {
        let isP = selectedOwner == .primary
        let name = isP
            ? (dataManager.userName.isEmpty ? "Your" : "\(dataManager.userName)'s")
            : (dataManager.spouseName.isEmpty ? "Spouse's" : "\(dataManager.spouseName)'s")
        let currentBenefitBinding = isP ? $primaryCurrentBenefit : $spouseCurrentBenefit
        let claimingAgeBinding = isP ? $primaryClaimingAge : $spouseClaimingAge

        return VStack(alignment: .leading, spacing: 16) {
            Text("\(name) Current Benefit")
                .font(.headline)

            Text("Enter the total monthly Social Security payment currently being received (before Medicare premiums are deducted).")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Image(systemName: "lightbulb")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("Enter the total amount from your SSA statement or bank deposit. If you receive a spousal top-up, SSA already includes it in your payment \u{2014} do not add it separately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color.orange.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Text("Monthly benefit")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 2) {
                    Text("$")
                        .foregroundStyle(.secondary)
                    TextField("0", text: currentBenefitBinding)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .focused($focusedBenefitField, equals: .currentBenefit)
                    Text("/mo")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                focusedBenefitField = .currentBenefit
            }

            Divider()

            // Age when benefits started
            VStack(alignment: .leading, spacing: 8) {
                Text("Age When Benefits Started")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    Text("Age \(claimingAgeBinding.wrappedValue)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .frame(width: 70, alignment: .leading)

                    Slider(value: Binding(
                        get: { Double(claimingAgeBinding.wrappedValue) },
                        set: { claimingAgeBinding.wrappedValue = Int($0) }
                    ), in: 62...70, step: 1)
                    .tint(.blue)
                }

                let birthYear = isP ? dataManager.birthYear : dataManager.spouseBirthYear
                let fra = SSCalculationEngine.fullRetirementAge(birthYear: birthYear)
                let adj = SSCalculationEngine.adjustmentPercentage(
                    claimingAge: claimingAgeBinding.wrappedValue,
                    fraYears: fra.years, fraMonths: fra.months
                )
                if adj != 0 {
                    Text(adj > 0
                         ? "Started \(String(format: "%.1f", adj))% above FRA benefit (delayed credits)"
                         : "Started \(String(format: "%.1f", abs(adj)))% below FRA benefit (early claiming)")
                        .font(.caption)
                        .foregroundStyle(adj > 0 ? .green : .orange)
                }

                Text("This helps calculate couples strategy and survivor benefits accurately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            let monthly = Double(currentBenefitBinding.wrappedValue) ?? 0
            if monthly > 0 {
                Divider()
                HStack {
                    Text("Annual benefit")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(SSCalculationEngine.formatCurrency(monthly * 12) + "/yr")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                }

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("This amount will be synced to your tax plan as Social Security income.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Already Claiming Estimates Card (for couples analysis)

    @State private var showEstimatesForClaiming = false

    private var alreadyClaimingEstimatesCard: some View {
        let isP = selectedOwner == .primary
        let name = isP
            ? (dataManager.userName.isEmpty ? "Your" : "\(dataManager.userName)'s")
            : (dataManager.spouseName.isEmpty ? "Spouse's" : "\(dataManager.spouseName)'s")
        let at62 = isP ? $primaryAt62 : $spouseAt62
        let atFRA = isP ? $primaryAtFRA : $spouseAtFRA
        let at70 = isP ? $primaryAt70 : $spouseAt70
        let birthYear = isP ? dataManager.birthYear : dataManager.spouseBirthYear
        let fra = SSCalculationEngine.fullRetirementAge(birthYear: birthYear)
        let hasEstimates = (Double(at62.wrappedValue) ?? 0) > 0 || (Double(atFRA.wrappedValue) ?? 0) > 0

        return VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation { showEstimatesForClaiming.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(name) SSA Benefit Estimates")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(hasEstimates ? "Used for couples strategy & spousal top-up" : "Needed for couples strategy & spousal top-up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if hasEstimates {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    Image(systemName: showEstimatesForClaiming ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }

            if showEstimatesForClaiming {
                Text("These estimates from your SSA statement help calculate how much spousal top-up each spouse may receive and optimize the couples claiming strategy.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Full Retirement Age: \(SSCalculationEngine.fraDescription(birthYear: birthYear))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    benefitField(label: "Monthly benefit at 62", text: at62, field: .at62)
                    benefitField(label: "Monthly benefit at FRA (\(fra.years))", text: atFRA, field: .atFRA)
                    benefitField(label: "Monthly benefit at 70", text: at70, field: .at70)
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Instruction Card

    private var instructionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                Text("Where to Find These Numbers")
                    .font(.headline)
            }

            Text("Log into **my Social Security** at ssa.gov/myaccount to find your estimated benefits at ages 62, Full Retirement Age, and 70.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("All calculations run on your device. Your data never leaves this app.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Benefit Entry Card

    private func benefitEntryCard(title: String, fra: (years: Int, months: Int),
                                  at62: Binding<String>, atFRA: Binding<String>, at70: Binding<String>,
                                  claimingAge: Binding<Int>, birthYear: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)

            Text("Full Retirement Age: \(SSCalculationEngine.fraDescription(birthYear: birthYear))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                benefitField(label: "Monthly benefit at 62", text: at62, field: .at62)
                benefitField(label: "Monthly benefit at FRA (\(fra.years))", text: atFRA, field: .atFRA)
                benefitField(label: "Monthly benefit at 70", text: at70, field: .at70)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Planned Claiming Age")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    Text("Age \(claimingAge.wrappedValue)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .frame(width: 70, alignment: .leading)

                    Slider(value: Binding(
                        get: { Double(claimingAge.wrappedValue) },
                        set: { claimingAge.wrappedValue = Int($0) }
                    ), in: 62...70, step: 1)
                    .tint(.blue)
                }

                let adj = SSCalculationEngine.adjustmentPercentage(
                    claimingAge: claimingAge.wrappedValue,
                    fraYears: fra.years, fraMonths: fra.months
                )
                if adj != 0 {
                    Text(adj > 0
                         ? "+\(String(format: "%.1f", adj))% delayed retirement credits"
                         : "\(String(format: "%.1f", adj))% early claiming reduction")
                        .font(.caption)
                        .foregroundStyle(adj > 0 ? .green : .orange)
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func benefitField(label: String, text: Binding<String>, field: BenefitFieldID) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 2) {
                Text("$")
                    .foregroundStyle(.secondary)
                TextField("0", text: text)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .focused($focusedBenefitField, equals: field)
                Text("/mo")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            focusedBenefitField = field
        }
    }

    // MARK: - Benefit Preview

    private var benefitPreviewCard: some View {
        let isP = selectedOwner == .primary
        let fraAmt = Double(isP ? primaryAtFRA : spouseAtFRA) ?? 0
        let age = isP ? primaryClaimingAge : spouseClaimingAge
        let birthYr = isP ? dataManager.birthYear : dataManager.spouseBirthYear
        let fra = SSCalculationEngine.fullRetirementAge(birthYear: birthYr)

        let monthly = fraAmt > 0
            ? SSCalculationEngine.benefitAtAge(claimingAge: age, pia: fraAmt,
                                               fraYears: fra.years, fraMonths: fra.months)
            : 0

        return Group {
            if monthly > 0 {
                VStack(spacing: 8) {
                    Text("At age \(age), your estimated monthly benefit is")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(SSCalculationEngine.formatCurrency(monthly))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                    Text("\(SSCalculationEngine.formatCurrency(monthly * 12))/year")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(PlatformColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            }
        }
    }

    // MARK: - Earnings History Content

    private var earningsHistoryContent: some View {
        VStack(spacing: 20) {
            earningsInstructionCard

            if dataManager.enableSpouse {
                Picker("Person", selection: $selectedOwner) {
                    Text(dataManager.userName.isEmpty ? "You" : dataManager.userName).tag(Owner.primary)
                    Text(dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName).tag(Owner.spouse)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }

            pasteCard

            if hasParsed {
                if !parsedRecords.isEmpty {
                    parsedResultsCard
                    futureEarningsCard
                    if let pia = piaResult {
                        piaResultCard(pia)
                    }
                }
                if let error = parseError {
                    parseErrorCard(error)
                }
            }
        }
    }

    // MARK: - Earnings Instruction Card

    private var earningsInstructionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .foregroundStyle(.blue)
                Text("Import Your Earnings Record")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 6) {
                instructionStep(number: "1", text: "Log into **ssa.gov/myaccount**")
                instructionStep(number: "2", text: "Go to **Eligibility & Earnings** or view your SS Statement")
                instructionStep(number: "3", text: "Download the **XML file**, or copy the earnings table")
            }

            // Import XML button — primary action
            Button {
                showXMLImporter = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.badge.arrow.up")
                        .font(.body)
                    Text("Import SSA XML File")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Text("Or paste earnings data in the box below.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("The app calculates your AIME and PIA — the same formula SSA uses to determine your benefit. This can be more accurate than the SSA statement estimates if your future earnings will differ from SSA's projections.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func instructionStep(number: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Color.blue)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Paste Card

    private var pasteCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste Earnings Data")
                .font(.headline)

            TextEditor(text: $pasteText)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 150, maxHeight: 250)
                .padding(8)
                .background(Color(PlatformColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3))
                )

            if pasteText.isEmpty {
                Text("Example format:\n2020  137,700\n2021  142,800\n2022  147,000")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }

            Button {
                parseEarnings()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.body)
                    Text("Parse Earnings")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.1))
                .foregroundStyle(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(pasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Parsed Results Card

    private var parsedResultsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Parsed Earnings")
                    .font(.headline)
                Spacer()
                Text("\(parsedRecords.count) years")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !parseSkipped.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("\(parseSkipped.count) line(s) skipped — couldn't parse year/amount")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            // Scrollable earnings table
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Year")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(width: 60, alignment: .leading)
                    Spacer()
                    Text("Earnings")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(width: 100, alignment: .trailing)
                    Text("Cap")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(width: 30, alignment: .center)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.secondary.opacity(0.1))

                ForEach(parsedRecords) { record in
                    let atCap = SSCalculationEngine.taxableMaxTable[record.year].map { record.earnings >= $0 } ?? false
                    HStack {
                        Text(verbatim: "\(record.year)")
                            .font(.caption)
                            .frame(width: 60, alignment: .leading)
                        Spacer()
                        Text(SSCalculationEngine.formatCurrency(record.earnings))
                            .font(.caption)
                            .frame(width: 100, alignment: .trailing)
                        Text(atCap ? "MAX" : "")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                            .frame(width: 30, alignment: .center)
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(record.earnings == 0 ? Color.red.opacity(0.05) : Color.clear)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2))
            )
            .frame(maxHeight: 300)
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Future Earnings Card

    private var futureEarningsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Future Earnings Projection")
                .font(.headline)

            Text("If you plan to keep working, enter your expected annual earnings and years remaining. This adjusts the PIA calculation.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("Annual earnings")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 2) {
                    Text("$")
                        .foregroundStyle(.secondary)
                    TextField("0", text: $futureEarnings)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            }

            HStack {
                Text("Years remaining")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("0", text: $futureYears)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .frame(width: 50)
            }

            Button {
                recalculatePIA()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.body)
                    Text("Recalculate PIA")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.1))
                .foregroundStyle(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - PIA Result Card

    private func piaResultCard(_ pia: SSPIAResult) -> some View {
        let birthYr = selectedOwner == .primary ? dataManager.birthYear : dataManager.spouseBirthYear

        return VStack(alignment: .leading, spacing: 12) {
            Text("Calculated Benefit (from earnings)")
                .font(.headline)

            // AIME and PIA summary
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AIME")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(SSCalculationEngine.formatCurrency(Double(pia.aime)))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("PIA (benefit at FRA)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(SSCalculationEngine.formatCurrency(pia.pia))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                }
            }

            Divider()

            // Estimated benefits at key ages
            HStack(spacing: 0) {
                piaColumn(label: "Age 62", amount: pia.benefitAt62(birthYear: birthYr), color: .red)
                Spacer()
                piaColumn(label: "FRA", amount: pia.pia, color: .blue)
                Spacer()
                piaColumn(label: "Age 70", amount: pia.benefitAt70(birthYear: birthYr), color: .green)
            }

            Divider()

            // Calculation details
            VStack(alignment: .leading, spacing: 4) {
                detailRow(label: "Years of earnings", value: "\(pia.yearsOfEarnings)")
                if pia.zeroPaddedYears > 0 {
                    detailRow(label: "Zero-padded years", value: "\(pia.zeroPaddedYears)")
                }
                detailRow(label: "Bend points", value: "\(SSCalculationEngine.formatCurrency(pia.bendPoint1)) / \(SSCalculationEngine.formatCurrency(pia.bendPoint2))")
            }

            // Compare with SSA statement if available
            let ssaBenefit = selectedOwner == .primary ? dataManager.primarySSBenefit : dataManager.spouseSSBenefit
            if let ssa = ssaBenefit, ssa.benefitAtFRA > 0 {
                Divider()
                comparisonRow(ssaAmount: ssa.benefitAtFRA, calculatedAmount: pia.pia)
            }

            // Apply to Quick Entry button
            Button {
                applyPIAToQuickEntry(pia, birthYear: birthYr)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle")
                        .font(.body)
                    Text("Apply to Quick Entry")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.1))
                .foregroundStyle(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func piaColumn(label: String, amount: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(SSCalculationEngine.formatCurrency(amount))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text("/mo")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    private func comparisonRow(ssaAmount: Double, calculatedAmount: Double) -> some View {
        let diff = calculatedAmount - ssaAmount
        let pct = ssaAmount > 0 ? (diff / ssaAmount) * 100 : 0

        return VStack(alignment: .leading, spacing: 6) {
            Text("Comparison with SSA Statement")
                .font(.caption)
                .fontWeight(.medium)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SSA estimate (FRA)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(SSCalculationEngine.formatCurrency(ssaAmount))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Calculated (FRA)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(SSCalculationEngine.formatCurrency(calculatedAmount))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            if abs(pct) > 1 {
                HStack(spacing: 4) {
                    Image(systemName: abs(pct) > 10 ? "exclamationmark.triangle" : "info.circle")
                        .font(.caption)
                        .foregroundStyle(abs(pct) > 10 ? .orange : .blue)
                    Text(abs(pct) > 10
                         ? "Significant difference (\(String(format: "%+.1f%%", pct))). The SSA estimate may assume different future earnings."
                         : "Small difference (\(String(format: "%+.1f%%", pct))). Normal due to rounding and future earnings assumptions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("Calculated PIA closely matches your SSA statement.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Parse Error Card

    private func parseErrorCard(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                Text("Parse Error")
                    .font(.headline)
            }
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Try copying just the Year and Earnings columns from your SSA statement. Each line should have a 4-digit year and a dollar amount.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - XML Import

    #if os(macOS)
    private func openXMLWithNSOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.xml]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select your Social Security Statement XML file"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                DispatchQueue.main.async {
                    handleXMLFile(url)
                }
            }
        }
    }
    #endif

    private func handleXMLFile(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            let parseResult = SSCalculationEngine.parseEarningsXML(data)

            hasParsed = true
            parseError = nil
            parsedRecords = []
            parseSkipped = []
            piaResult = nil

            switch parseResult {
            case .success(let xmlResult):
                parsedRecords = xmlResult.earnings.records
                parseSkipped = xmlResult.earnings.skippedLines
                if parsedRecords.isEmpty {
                    parseError = "XML file was read but no earnings records were found."
                } else {
                    recalculatePIA()
                    // Auto-apply PIA to Quick Entry fields
                    if let pia = piaResult {
                        let birthYr = selectedOwner == .primary ? dataManager.birthYear : dataManager.spouseBirthYear
                        applyPIAToQuickEntry(pia, birthYear: birthYr)
                        // Stay on earnings history tab to show results
                        entryMode = .earningsHistory
                    }
                }

            case .failure(let error):
                switch error {
                case .noValidRows:
                    parseError = "No earnings records found in the XML file. Make sure you downloaded the Social Security Statement XML from ssa.gov."
                case .partialParse(let valid, let skipped):
                    parsedRecords = valid
                    parseSkipped = skipped
                    recalculatePIA()
                }
            }
        } catch {
            parseError = "Could not read the file: \(error.localizedDescription)"
            hasParsed = true
        }
    }

    private func handleXMLImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            handleXMLFile(url)
        case .failure(let error):
            parseError = "File selection failed: \(error.localizedDescription)"
            hasParsed = true
        }
    }

    // MARK: - Parse Logic

    private func parseEarnings() {
        hasParsed = true
        parseError = nil
        parsedRecords = []
        parseSkipped = []
        piaResult = nil

        let result = SSCalculationEngine.parseEarningsHistory(pasteText)

        switch result {
        case .success(let parsed):
            parsedRecords = parsed.records
            parseSkipped = parsed.skippedLines
            recalculatePIA()

        case .failure(let error):
            switch error {
            case .noValidRows:
                parseError = "No valid earnings rows found. Make sure your paste includes lines with a 4-digit year and a dollar amount."
            case .partialParse(let valid, let skipped):
                parsedRecords = valid
                parseSkipped = skipped
                recalculatePIA()
            }
        }
    }

    private func recalculatePIA() {
        guard !parsedRecords.isEmpty else { return }
        let birthYr = selectedOwner == .primary ? dataManager.birthYear : dataManager.spouseBirthYear
        let futureAmt = Double(futureEarnings.replacingOccurrences(of: ",", with: "")) ?? 0
        let futureYrs = Int(futureYears) ?? 0

        piaResult = SSCalculationEngine.calculatePIA(
            records: parsedRecords,
            birthYear: birthYr,
            futureEarningsPerYear: futureAmt,
            futureWorkYears: futureYrs
        )
    }

    private func applyPIAToQuickEntry(_ pia: SSPIAResult, birthYear: Int) {
        let at62 = String(Int(pia.benefitAt62(birthYear: birthYear)))
        let atFRA = String(Int(pia.pia))
        let at70 = String(Int(pia.benefitAt70(birthYear: birthYear)))

        if selectedOwner == .primary {
            primaryAt62 = at62
            primaryAtFRA = atFRA
            primaryAt70 = at70
        } else {
            spouseAt62 = at62
            spouseAtFRA = atFRA
            spouseAt70 = at70
        }

        entryMode = .quickEntry
    }

    // MARK: - Data Loading / Saving

    private func loadExistingData() {
        if let p = dataManager.primarySSBenefit {
            primaryAlreadyClaiming = p.isAlreadyClaiming
            primaryCurrentBenefit = p.currentBenefit > 0 ? String(Int(p.currentBenefit)) : ""
            primaryAt62 = p.benefitAt62 > 0 ? String(Int(p.benefitAt62)) : ""
            primaryAtFRA = p.benefitAtFRA > 0 ? String(Int(p.benefitAtFRA)) : ""
            primaryAt70 = p.benefitAt70 > 0 ? String(Int(p.benefitAt70)) : ""
            primaryClaimingAge = p.plannedClaimingAge
        } else if presetAlreadyClaiming {
            // No existing data — apply the preset from the empty-state button
            primaryAlreadyClaiming = true
        }
        if let s = dataManager.spouseSSBenefit {
            spouseAlreadyClaiming = s.isAlreadyClaiming
            spouseCurrentBenefit = s.currentBenefit > 0 ? String(Int(s.currentBenefit)) : ""
            spouseAt62 = s.benefitAt62 > 0 ? String(Int(s.benefitAt62)) : ""
            spouseAtFRA = s.benefitAtFRA > 0 ? String(Int(s.benefitAtFRA)) : ""
            spouseAt70 = s.benefitAt70 > 0 ? String(Int(s.benefitAt70)) : ""
            spouseClaimingAge = s.plannedClaimingAge
        }
        // Load existing earnings history
        if let h = dataManager.primaryEarningsHistory, !h.records.isEmpty {
            // Pre-populate future earnings fields
            if h.futureEarningsPerYear > 0 {
                futureEarnings = String(Int(h.futureEarningsPerYear))
            }
            if h.futureWorkYears > 0 {
                futureYears = String(h.futureWorkYears)
            }
        }
    }

    private func saveData() {
        dataManager.primarySSBenefit = SSBenefitEstimate(
            owner: .primary,
            benefitAt62: Double(primaryAt62) ?? 0,
            benefitAtFRA: Double(primaryAtFRA) ?? 0,
            benefitAt70: Double(primaryAt70) ?? 0,
            plannedClaimingAge: primaryClaimingAge,
            isAlreadyClaiming: primaryAlreadyClaiming,
            currentBenefit: Double(primaryCurrentBenefit) ?? 0
        )

        if dataManager.enableSpouse {
            dataManager.spouseSSBenefit = SSBenefitEstimate(
                owner: .spouse,
                benefitAt62: Double(spouseAt62) ?? 0,
                benefitAtFRA: Double(spouseAtFRA) ?? 0,
                benefitAt70: Double(spouseAt70) ?? 0,
                plannedClaimingAge: spouseClaimingAge,
                isAlreadyClaiming: spouseAlreadyClaiming,
                currentBenefit: Double(spouseCurrentBenefit) ?? 0
            )
        }

        // Save earnings history if parsed
        if !parsedRecords.isEmpty {
            let futureAmt = Double(futureEarnings.replacingOccurrences(of: ",", with: "")) ?? 0
            let futureYrs = Int(futureYears) ?? 0
            let history = SSEarningsHistory(
                owner: selectedOwner,
                records: parsedRecords,
                futureEarningsPerYear: futureAmt,
                futureWorkYears: futureYrs
            )
            if selectedOwner == .primary {
                dataManager.primaryEarningsHistory = history
            } else {
                dataManager.spouseEarningsHistory = history
            }
        }

        dataManager.syncSSToIncomeSources()
        dataManager.saveAllData()
    }
}
