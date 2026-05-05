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
    @State private var selectedTab: Int = 1
    @State private var sidebarSelection: Int? = 1
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
                    Label("Tax Planning", systemImage: "chart.bar.doc.horizontal.fill")
                        .tag(5)
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
        case 1: SettingsView(selectedTab: $selectedTab)
        case 2: IncomeSourcesView()
        case 3: AccountsView()
        case 4: RMDCalculatorView()
        case 5: TaxPlanningView()
        case 7: QuarterlyTaxView()
        case 8: StateComparisonView()
        case 9: SocialSecurityPlannerView()
        default: SettingsView(selectedTab: $selectedTab)
        }
    }
    #endif

    // MARK: - iPad Sidebar

    #if !os(macOS)
    private var ipadSidebarBody: some View {
        NavigationSplitView {
            List(selection: $sidebarSelection) {
                Section("Setup") {
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
                    Label("Tax Planning", systemImage: "chart.bar.doc.horizontal.fill")
                        .tag(5)
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
        case 1: SettingsView(selectedTab: $selectedTab)
        case 2: IncomeSourcesView()
        case 3: AccountsView()
        case 4: RMDCalculatorView()
        case 5: TaxPlanningView()
        case 7: QuarterlyTaxView()
        case 8: StateComparisonView()
        case 9: SocialSecurityPlannerView()
        default: SettingsView(selectedTab: $selectedTab)
        }
    }
    #endif

    // MARK: - iPhone Tab Bar

    private var tabBody: some View {
        TabView(selection: $selectedTab) {
            SettingsView(selectedTab: $selectedTab)
                .tabItem { Label("My Profile", systemImage: "person.crop.circle.fill") }
                .tag(1)

            IncomeSourcesView()
                .tabItem { Label("Income", systemImage: "banknote.fill") }
                .tag(2)

            AccountsView()
                .tabItem { Label("Accounts", systemImage: "building.columns.fill") }
                .tag(3)

            SocialSecurityPlannerView()
                .tabItem { Label("Social Security", systemImage: "person.text.rectangle.fill") }
                .tag(9)

            TaxPlanningView()
                .tabItem { Label("Tax Planning", systemImage: "chart.bar.doc.horizontal.fill") }
                .tag(5)

            // Items below appear in the More menu automatically (iOS auto-overflow past 5):
            RMDCalculatorView()
                .tabItem { Label("RMD Calculator", systemImage: "calendar.badge.clock") }
                .tag(4)

            QuarterlyTaxView()
                .tabItem { Label("Quarterly Tax", systemImage: "dollarsign.circle.fill") }
                .tag(7)

            StateComparisonView()
                .tabItem { Label("State Comparison", systemImage: "map.fill") }
                .tag(8)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataManager())
}
