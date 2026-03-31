//
//  ContentView.swift
//  RetireSmartIRA
//
//  Main navigation view — sidebar on macOS, tab bar on iOS/iPadOS
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedTab = 0

    var body: some View {
        #if os(macOS)
        macBody
        #else
        tabBody
        #endif
    }

    // MARK: - macOS Sidebar

    #if os(macOS)
    private var macBody: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section("Setup") {
                    Label("Get Started", systemImage: "sparkles")
                        .tag(0)
                    Label("My Profile", systemImage: "person.crop.circle.fill")
                        .tag(1)
                    Label("Social Security", systemImage: "person.text.rectangle.fill")
                        .tag(9)
                    Label("Income & Deductions", systemImage: "banknote.fill")
                        .tag(2)
                    Label("Accounts", systemImage: "building.columns.fill")
                        .tag(3)
                }

                Section("Analysis") {
                    Label("RMD Calculator", systemImage: "calendar.badge.clock")
                        .tag(4)
                    Label("Scenarios", systemImage: "slider.horizontal.3")
                        .tag(5)
                    Label("Tax Summary", systemImage: "chart.bar.fill")
                        .tag(6)
                }

                Section("More") {
                    Label("Quarterly Tax", systemImage: "dollarsign.circle.fill")
                        .tag(7)
                    Label("State Comparison", systemImage: "map.fill")
                        .tag(8)
                }
            }
            .navigationTitle("RetireSmart IRA")
            .listStyle(.sidebar)
            .frame(minWidth: 200)
        } detail: {
            switch selectedTab {
            case 0: GuideView(selectedTab: $selectedTab)
            case 1: SettingsView()
            case 2: IncomeSourcesView()
            case 3: AccountsView()
            case 4: RMDCalculatorView()
            case 5: TaxPlanningView()
            case 6: DashboardView()
            case 7: QuarterlyTaxView()
            case 8: StateComparisonView()
            case 9: SocialSecurityPlannerView()
            default: DashboardView()
            }
        }
    }
    #endif

    // MARK: - iOS/iPadOS Tab Bar

    private var tabBody: some View {
        TabView(selection: $selectedTab) {
            GuideView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Get Started", systemImage: "sparkles")
                }
                .tag(0)

            SettingsView()
                .tabItem {
                    Label("My Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(1)

            SocialSecurityPlannerView()
                .tabItem {
                    Label("Social Security", systemImage: "person.text.rectangle.fill")
                }
                .tag(9)

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

            StateComparisonView()
                .tabItem {
                    Label("State Comparison", systemImage: "map.fill")
                }
                .tag(8)

        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataManager())
}
