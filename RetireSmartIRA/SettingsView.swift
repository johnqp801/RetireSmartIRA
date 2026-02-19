//
//  SettingsView.swift
//  RetireSmartIRA
//
//  My Profile: personal info, filing status, and spouse configuration
//

import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var stateSearchText = ""

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
                        .foregroundStyle(dataManager.isQCDEligible ? .green : .secondary)
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
                            .foregroundStyle(dataManager.spouseIsQCDEligible ? .green : .secondary)
                    }
                }
            }

            Section("Subscription") {
                LabeledContent("Status") {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("Premium")
                            .foregroundStyle(.green)
                    }
                }

                LabeledContent("Plan") {
                    Text("\(subscriptionManager.formattedPrice) / year")
                        .foregroundStyle(.secondary)
                }

                Button("Manage Subscription") {
                    Task {
                        #if canImport(UIKit)
                        if let windowScene = UIApplication.shared.connectedScenes
                            .compactMap({ $0 as? UIWindowScene })
                            .first {
                            try? await AppStore.showManageSubscriptions(in: windowScene)
                        }
                        #elseif os(macOS)
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            NSWorkspace.shared.open(url)
                        }
                        #endif
                    }
                }
            }

            Section("About") {
                LabeledContent("Version") {
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }

                Link(destination: URL(string: "https://www.irs.gov/retirement-plans/plan-participant-employee/retirement-topics-required-minimum-distributions-rmds")!) {
                    LabeledContent("IRS RMD Information") {
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.blue)
                    }
                }
            }

            Section("Disclaimer") {
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
        }
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
                                .foregroundStyle(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .searchable(text: $stateSearchText, prompt: "Search states")
        .navigationTitle("State of Residence")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
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
            .environmentObject(SubscriptionManager())
    }
}
