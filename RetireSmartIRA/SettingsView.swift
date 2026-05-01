//
//  SettingsView.swift
//  RetireSmartIRA
//
//  My Profile: personal info, filing status, and spouse configuration
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var stateSearchText = ""
    @State private var showTermsOfUse = false
    @State private var showPrivacyPolicy = false
    @State private var showSources = false

    /// Date range for the birth date picker (1920 to today)
    private var birthDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let earliest = calendar.date(from: DateComponents(year: 1920, month: 1, day: 1))!
        return earliest...Date()
    }

    var body: some View {
        NavigationStack {
        Form {
            Section("Personal Information") {
                LabeledContent("Your Name") {
                    TextField("Name", text: $dataManager.userName)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.primary)
                }

                DatePicker("Date of Birth",
                           selection: $dataManager.birthDate,
                           in: birthDateRange,
                           displayedComponents: .date)

                LabeledContent("Current Age") {
                    Text("\(dataManager.currentAge)")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("RMD Age") {
                    Text("\(dataManager.rmdAge)")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("QCD Eligible") {
                    Text(dataManager.isQCDEligible ? "Yes" : "Not yet")
                        .foregroundStyle(dataManager.isQCDEligible ? Color.UI.textPrimary : .secondary)
                }
            }

            Section("Tax Filing") {
                Picker("Filing Status", selection: $dataManager.filingStatus) {
                    Text("Single").tag(FilingStatus.single)
                    Text("Married Filing Jointly").tag(FilingStatus.marriedFilingJointly)
                }
                .pickerStyle(.segmented)

                NavigationLink {
                    statePickerView
                } label: {
                    LabeledContent("State of Residence") {
                        Text(dataManager.selectedState.rawValue)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Spouse Configuration") {
                Toggle("Enable Spouse", isOn: $dataManager.enableSpouse)

                if dataManager.enableSpouse {
                    LabeledContent("Spouse Name") {
                        TextField("Name", text: $dataManager.spouseName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.primary)
                    }

                    DatePicker("Spouse Date of Birth",
                               selection: $dataManager.spouseBirthDate,
                               in: birthDateRange,
                               displayedComponents: .date)

                    LabeledContent("Spouse Current Age") {
                        Text("\(dataManager.spouseCurrentAge)")
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Spouse RMD Age") {
                        Text("\(dataManager.spouseRmdAge)")
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Spouse QCD Eligible") {
                        Text(dataManager.spouseIsQCDEligible ? "Yes" : "Not yet")
                            .foregroundStyle(dataManager.spouseIsQCDEligible ? Color.UI.textPrimary : .secondary)
                    }
                }
            }

            Section("Legacy Planning") {
                Toggle("Consider Legacy Planning", isOn: $dataManager.enableLegacyPlanning)

                Text("Legacy planning shows the long-term tax impact of your decisions on heirs. Without it, Roth conversions may appear costly without showing the future tax-free growth benefit. You can turn this off if you only want current-year analysis.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if dataManager.enableLegacyPlanning {
                    Picker("Primary Heir", selection: $dataManager.legacyHeirType) {
                        Text("Spouse").tag("spouse")
                        Text("Adult Child").tag("adultChild")
                        Text("Spouse then Child").tag("spouseThenChild")
                        Text("Other").tag("other")
                    }

                    Text("Who would inherit your IRAs. \"Spouse then Child\" models the common path where your spouse inherits first and your child (or other non-spouse heir) inherits after your spouse's death.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if dataManager.legacyHeirType == "spouseThenChild" {
                        Stepper("Spouse survives: \(dataManager.legacySpouseSurvivorYears) years",
                                value: $dataManager.legacySpouseSurvivorYears,
                                in: 1...30)
                        Text("How many years your spouse lives after your death before your child inherits.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // For pure "spouse" heir, the spouse's income, filing status, and age
                    // are already captured elsewhere in the app (household inputs + spouse
                    // birth date). Only ask for heir-specific details when the ultimate
                    // inheritor is someone other than the spouse.
                    if dataManager.legacyHeirType == "spouse" {
                        InlineHint("Your spouse's income, filing status, and age come from your household inputs — no additional heir details needed.")
                    } else {
                        // Labels say "Primary Heir's" (not "Heir's") to make the
                        // single-heir model unambiguous — Ron Park feedback: users
                        // wondered whether they should aggregate multiple children.
                        Picker("Primary Heir's Filing Status", selection: $dataManager.legacyHeirFilingStatus) {
                            Text("Single").tag(FilingStatus.single)
                            Text("Married Filing Jointly").tag(FilingStatus.marriedFilingJointly)
                        }
                        .pickerStyle(.segmented)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Primary Heir's Salary (today's dollars)")
                                Spacer()
                                Text(dataManager.legacyHeirEstimatedSalary, format: .currency(code: "USD").precision(.fractionLength(0)))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $dataManager.legacyHeirEstimatedSalary, in: 0...500_000, step: 5_000)
                        }

                        Text("Use today's salary — the legacy projection runs in today's dollars throughout. The app calculates your heir's tax using progressive federal brackets based on their salary plus inherited IRA distributions.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Primary Heir's Birth Year (optional)")
                                Spacer()
                                TextField("—", text: Binding(
                                    get: { dataManager.legacyHeirBirthYear.map(String.init) ?? "" },
                                    set: { raw in
                                        let trimmed = raw.trimmingCharacters(in: .whitespaces)
                                        if trimmed.isEmpty {
                                            dataManager.legacyHeirBirthYear = nil
                                        } else if let year = Int(trimmed), year >= 1900, year <= 2100 {
                                            dataManager.legacyHeirBirthYear = year
                                        }
                                    }
                                ))
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 80)
                                .foregroundStyle(.secondary)
                            }
                            Text("Used only to flag Kiddie Tax concerns if your heir is under 24 at the projected inheritance year.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "person.2")
                                .foregroundStyle(Color.UI.brandTeal)
                                .font(.caption)
                            Text("Modeling one primary heir. If you have multiple heirs (e.g. several children), enter the one with the highest expected salary — that gives the conservative case where Roth conversions save the most tax.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: {
                            switch dataManager.legacyHeirType {
                            case "spouse": return "person.2.fill"
                            case "spouseThenChild": return "person.3.fill"
                            default: return "clock.fill"
                            }
                        }())
                            .foregroundStyle(Color.UI.brandTeal)
                            .font(.caption)
                        Text(dataManager.legacyHeirTypeDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("About") {
                LabeledContent("Version") {
                    Text(bundleVersionString)
                        .foregroundStyle(.secondary)
                }

                Button {
                    showSources = true
                } label: {
                    LabeledContent {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("Sources & References", systemImage: "doc.text.magnifyingglass")
                    }
                }
                .foregroundStyle(.primary)

                Link(destination: URL(string: "https://www.irs.gov/retirement-plans/plan-participant-employee/retirement-topics-required-minimum-distributions-rmds")!) {
                    LabeledContent("IRS RMD Information") {
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(Color.UI.brandTeal)
                    }
                }
            }

            Section("Legal") {
                Button {
                    showTermsOfUse = true
                } label: {
                    LabeledContent("Terms of Use") {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)

                Button {
                    showPrivacyPolicy = true
                } label: {
                    LabeledContent("Privacy Policy") {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)

                Text("This app provides estimates for planning purposes only. Consult with a qualified tax professional or financial advisor for personalized advice. Tax laws and regulations may change.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("My Profile")
        .onChange(of: dataManager.birthDate) { dataManager.saveAllData() }
        .onChange(of: dataManager.filingStatus) { dataManager.saveAllData() }
        .onChange(of: dataManager.selectedState) { dataManager.saveAllData() }
        .onChange(of: dataManager.enableSpouse) { dataManager.saveAllData() }
        .onChange(of: dataManager.spouseName) { dataManager.saveAllData() }
        .onChange(of: dataManager.spouseBirthDate) { dataManager.saveAllData() }
        .onChange(of: dataManager.userName) { dataManager.saveAllData() }
        .onChange(of: dataManager.enableLegacyPlanning) { dataManager.saveAllData() }
        .onChange(of: dataManager.legacyHeirType) { dataManager.saveAllData() }
        .onChange(of: dataManager.legacyHeirEstimatedSalary) { dataManager.saveAllData() }
        .onChange(of: dataManager.legacyHeirFilingStatus) { dataManager.saveAllData() }
        .onChange(of: dataManager.legacyHeirBirthYear) { dataManager.saveAllData() }
        .onChange(of: dataManager.legacySpouseSurvivorYears) { dataManager.saveAllData() }
        .sheet(isPresented: $showSources) {
            NavigationStack {
                SourcesReferencesView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showSources = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showTermsOfUse) {
            NavigationStack {
                ScrollView {
                    Text(TermsOfUseText.fullText)
                        .font(.footnote)
                        .padding()
                }
                .navigationTitle("Terms of Use")
                #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showTermsOfUse = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            NavigationStack {
                ScrollView {
                    Text(TermsOfUseText.privacyPolicy)
                        .font(.footnote)
                        .padding()
                }
                .navigationTitle("Privacy Policy")
                #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showPrivacyPolicy = false }
                    }
                }
            }
        }
        }
    }

    private var bundleVersionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    // MARK: - State Picker

    /// Searchable list of all 50 states + DC for state of residence selection.
    private var statePickerView: some View {
        let filteredStates = USState.allCases.filter {
            stateSearchText.isEmpty || $0.rawValue.localizedCaseInsensitiveContains(stateSearchText)
        }

        return List {
            ForEach(filteredStates) { state in
                Button {
                    dataManager.selectedState = state
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(state.rawValue)
                                .foregroundStyle(.primary)
                            Text(stateTaxSummary(for: state))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if state == dataManager.selectedState {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.UI.brandTeal)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .searchable(text: $stateSearchText, prompt: "Search states")
        .navigationTitle("State of Residence")
        #if os(iOS)
        #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        #endif
    }

    /// Short summary of a state's tax system for the picker list.
    private func stateTaxSummary(for state: USState) -> String {
        let config = StateTaxData.config(for: state)
        switch config.taxSystem {
        case .noIncomeTax:
            return "No income tax"
        case .specialLimited:
            return "No general income tax"
        case .flat(let rate):
            return String(format: "Flat %.2f%%", rate * 100)
        case .progressive(let single, _):
            if let topRate = single.last?.rate {
                return String(format: "Progressive, up to %.1f%%", topRate * 100)
            }
            return "Progressive brackets"
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(DataManager())
    }
}
