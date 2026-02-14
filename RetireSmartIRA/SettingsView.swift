//
//  SettingsView.swift
//  RetireSmartIRA
//
//  App settings and user preferences
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager

    /// Date range for the birth date picker (1920 to today)
    private var birthDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let earliest = calendar.date(from: DateComponents(year: 1920, month: 1, day: 1))!
        return earliest...Date()
    }

    var body: some View {
        Form {
            Section("Personal Information") {
                DatePicker("Date of Birth",
                           selection: $dataManager.birthDate,
                           in: birthDateRange,
                           displayedComponents: .date)

                HStack {
                    Text("Current Age")
                    Spacer()
                    Text("\(dataManager.currentAge)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("RMD Age")
                    Spacer()
                    Text("\(dataManager.rmdAge)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("QCD Eligible")
                    Spacer()
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
            }

            Section("Spouse Configuration") {
                Toggle("Enable Spouse", isOn: $dataManager.enableSpouse)

                if dataManager.enableSpouse {
                    HStack {
                        Text("Spouse Name")
                        Spacer()
                        TextField("Name", text: $dataManager.spouseName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.primary)
                    }

                    DatePicker("Spouse Date of Birth",
                               selection: $dataManager.spouseBirthDate,
                               in: birthDateRange,
                               displayedComponents: .date)

                    HStack {
                        Text("Spouse Current Age")
                        Spacer()
                        Text("\(dataManager.spouseCurrentAge)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Spouse RMD Age")
                        Spacer()
                        Text("\(dataManager.spouseRmdAge)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Spouse QCD Eligible")
                        Spacer()
                        Text(dataManager.spouseIsQCDEligible ? "Yes" : "Not yet")
                            .foregroundStyle(dataManager.spouseIsQCDEligible ? .green : .secondary)
                    }
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }

                Link(destination: URL(string: "https://www.irs.gov/retirement-plans/plan-participant-employee/retirement-topics-required-minimum-distributions-rmds")!) {
                    HStack {
                        Text("IRS RMD Information")
                        Spacer()
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
        .navigationTitle("Settings")
        .onChange(of: dataManager.birthDate) { dataManager.saveAllData() }
        .onChange(of: dataManager.filingStatus) { dataManager.saveAllData() }
        .onChange(of: dataManager.enableSpouse) { dataManager.saveAllData() }
        .onChange(of: dataManager.spouseName) { dataManager.saveAllData() }
        .onChange(of: dataManager.spouseBirthDate) { dataManager.saveAllData() }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(DataManager())
    }
}
