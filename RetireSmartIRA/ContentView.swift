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
            GuideView()
                .tabItem {
                    Label("Get Started", systemImage: "sparkles")
                }
                .tag(0)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(1)

            IncomeSourcesView()
                .tabItem {
                    Label("Income & Deductions", systemImage: "banknote.fill")
                }
                .tag(2)

            AccountsView()
                .tabItem {
                    Label("Accounts", systemImage: "building.columns.fill")
                }
                .tag(3)

            RMDCalculatorView()
                .tabItem {
                    Label("RMD Calculator", systemImage: "calendar.badge.clock")
                }
                .tag(4)

            TaxPlanningView()
                .tabItem {
                    Label("Scenarios", systemImage: "slider.horizontal.3")
                }
                .tag(5)

            DashboardView()
                .tabItem {
                    Label("Tax Summary", systemImage: "chart.bar.fill")
                }
                .tag(6)

            QuarterlyTaxView()
                .tabItem {
                    Label("Quarterly Tax", systemImage: "dollarsign.circle.fill")
                }
                .tag(7)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataManager())
}
