//
//  SettingsView.swift
//  RetireSmartIRA
//
//  App settings and user preferences
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        Form {
            Section("Personal Information") {
                HStack {
                    Text("Birth Year")
                    Spacer()
                    Picker("Birth Year", selection: $dataManager.birthYear) {
                        ForEach(1920...2010, id: \.self) { year in
                            Text("\(year)").tag(year)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                
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
                                
                                Picker("Spouse Birth Year", selection: $dataManager.spouseBirthYear) {
                                    ForEach(1930...2010, id: \.self) { year in
                                        Text(String(year)).tag(year)
                                    }
                                }
                                
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
        .onChange(of: dataManager.birthYear) { dataManager.saveAllData() }
        .onChange(of: dataManager.filingStatus) { dataManager.saveAllData() }
        .onChange(of: dataManager.enableSpouse) { dataManager.saveAllData() }
        .onChange(of: dataManager.spouseName) { dataManager.saveAllData() }
        .onChange(of: dataManager.spouseBirthYear) { dataManager.saveAllData() }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(DataManager())
    }
}
