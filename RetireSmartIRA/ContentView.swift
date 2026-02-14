//
//  ContentView.swift
//  RetireSmartIRA
//
//  Main navigation view for iPad
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(0)

            TaxPlanningView()
                .tabItem {
                    Label("Tax Planning", systemImage: "slider.horizontal.3")
                }
                .tag(1)

            RMDCalculatorView()
                .tabItem {
                    Label("RMD Calculator", systemImage: "calendar.badge.clock")
                }
                .tag(2)

            QuarterlyTaxView()
                .tabItem {
                    Label("Quarterly Tax", systemImage: "dollarsign.circle.fill")
                }
                .tag(3)

            AccountsView()
                .tabItem {
                    Label("Accounts", systemImage: "building.columns.fill")
                }
                .tag(4)

            IncomeSourcesView()
                .tabItem {
                    Label("Income & Deductions", systemImage: "banknote.fill")
                }
                .tag(5)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(6)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataManager())
}
