//
//  ContentView.swift
//  RetireSmartIRA
//
//  Main navigation view — sidebar on macOS, tab bar on iOS/iPadOS
//

import SwiftUI

// MARK: - Available Width Environment Key

private struct AvailableWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = .infinity
}

extension EnvironmentValues {
    var availableWidth: CGFloat {
        get { self[AvailableWidthKey.self] }
        set { self[AvailableWidthKey.self] = newValue }
    }
}

/// Wraps content in a GeometryReader that injects available width into the environment.
/// Child views can read `@Environment(\.availableWidth)` to make layout decisions.
struct WidthAwareContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geo in
            content
                .environment(\.availableWidth, geo.size.width)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedTab = 0
    @State private var sidebarSelection: Int? = 0
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        #if os(macOS)
        sidebarBody
        #else
        if horizontalSizeClass == .regular {
            ipadSidebarBody
        } else {
            tabBody
        }
        #endif
    }

    // MARK: - macOS Sidebar

    #if os(macOS)
    private var sidebarBody: some View {
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
            macDetailView
        }
    }

    @ViewBuilder
    private var macDetailView: some View {
        switch selectedTab {
        case 0: GuideView(selectedTab: $selectedTab)
        case 1: SettingsView()
        case 2: IncomeSourcesView()
        case 3: AccountsView()
        case 4: RMDCalculatorView()
        case 5: ScenarioBuilderView()
        case 6: DashboardView()
        case 7: QuarterlyTaxView()
        case 8: StateComparisonView()
        case 9: SocialSecurityPlannerView()
        default: GuideView(selectedTab: $selectedTab)
        }
    }
    #endif

    // MARK: - iPad Sidebar

    #if !os(macOS)
    private var ipadSidebarBody: some View {
        NavigationSplitView {
            List(selection: $sidebarSelection) {
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
        } detail: {
            WidthAwareContainer {
                ipadDetailView
            }
        }
        .onChange(of: sidebarSelection) { _, newValue in
            if let newValue { selectedTab = newValue }
        }
        .onChange(of: selectedTab) { _, newValue in
            sidebarSelection = newValue
        }
    }

    @ViewBuilder
    private var ipadDetailView: some View {
        switch sidebarSelection {
        case 0: GuideView(selectedTab: $selectedTab)
        case 1: SettingsView()
        case 2: IncomeSourcesView()
        case 3: AccountsView()
        case 4: RMDCalculatorView()
        case 5: ScenarioBuilderView()
        case 6: DashboardView()
        case 7: QuarterlyTaxView()
        case 8: StateComparisonView()
        case 9: SocialSecurityPlannerView()
        default: GuideView(selectedTab: $selectedTab)
        }
    }
    #endif

    // MARK: - iPhone Tab Bar

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

            ScenarioBuilderView()
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
