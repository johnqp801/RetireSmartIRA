//
//  GetStartedBanner.swift
//  RetireSmartIRA

import SwiftUI

struct GetStartedBanner: View {
    @EnvironmentObject var dataManager: DataManager
    @Binding var selectedTab: Int
    @AppStorage("getStartedBannerDismissed") private var dismissed = false

    private var checks: [(label: String, complete: Bool, deepLinkTab: Int)] {
        [
            ("Profile complete", !dataManager.userName.isEmpty, 1),
            ("Income added", !dataManager.incomeSources.isEmpty, 2),
            ("Accounts added", !dataManager.iraAccounts.isEmpty, 3),
            ("Social Security entered", dataManager.primarySSBenefit != nil, 9)
        ]
    }

    private var allComplete: Bool { checks.allSatisfy(\.complete) }

    var body: some View {
        if !dismissed {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sparkles").foregroundColor(.blue)
                    Text("Get Started").font(.headline)
                    Spacer()
                    Button { dismissed = true } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                ForEach(checks, id: \.label) { check in
                    HStack {
                        Image(systemName: check.complete ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(check.complete ? .green : .secondary)
                        Text(check.label)
                            .strikethrough(check.complete)
                            .foregroundColor(check.complete ? .secondary : .primary)
                        Spacer()
                        if !check.complete {
                            Button("Go") { selectedTab = check.deepLinkTab }
                                .buttonStyle(.borderless)
                                .font(.caption)
                        }
                    }
                    .font(.subheadline)
                }
                if allComplete {
                    Button("Try Tax Planning →") {
                        selectedTab = 5  // Tax Planning tag after restructure
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
                }
            }
            .padding(14)
            .background(Color.blue.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.2), lineWidth: 1))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
}
