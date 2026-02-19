//
//  PaywallView.swift
//  RetireSmartIRA
//
//  Subscription paywall shown when the user is not subscribed
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // MARK: - Header
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)

                    Text("RetireSmartIRA")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Retirement Tax Planning Made Easy")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // MARK: - Feature List
                VStack(alignment: .leading, spacing: 16) {
                    Text("Everything You Need")
                        .font(.headline)

                    featureRow(icon: "sparkles", color: .yellow, title: "Guided Setup", description: "Step-by-step walkthrough to configure your tax plan")
                    featureRow(icon: "person.crop.circle.fill", color: .blue, title: "Profile & Filing Status", description: "Personal info, spouse support, state of residence")
                    featureRow(icon: "banknote.fill", color: .green, title: "Income & Deductions", description: "Track all income sources with SALT cap enforcement")
                    featureRow(icon: "building.columns.fill", color: .purple, title: "Account Management", description: "Traditional, Roth, 401(k), and inherited IRA tracking")
                    featureRow(icon: "calendar.badge.clock", color: .red, title: "RMD Calculator", description: "Required Minimum Distributions with multi-year projections")
                    featureRow(icon: "slider.horizontal.3", color: .orange, title: "Tax Scenarios", description: "Model Roth conversions, QCDs, withdrawals, and charitable giving")
                    featureRow(icon: "chart.bar.fill", color: .blue, title: "Tax Summary", description: "Federal and state tax breakdown with IRMAA analysis")
                    featureRow(icon: "dollarsign.circle.fill", color: .teal, title: "Quarterly Tax", description: "Estimated quarterly payment tracking and calculations")
                    featureRow(icon: "map.fill", color: .indigo, title: "State Comparison", description: "Compare your tax burden across all 50 states")
                }
                .padding()
                .background(Color(PlatformColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)

                // MARK: - Privacy Badge
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.green)
                    Text("100% private \u{2014} all data stays on your device")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                // MARK: - Pricing
                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(subscriptionManager.formattedPrice)
                            .font(.system(size: 44, weight: .bold))
                        Text("per year")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    // Subscribe Button
                    Button(action: {
                        Task { await subscriptionManager.purchase() }
                    }) {
                        ZStack {
                            Text("Subscribe Now")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .opacity(subscriptionManager.isLoading ? 0.5 : 1)

                            if subscriptionManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                    }
                    .disabled(subscriptionManager.isLoading)

                    // Restore Purchases
                    Button(action: {
                        Task { await subscriptionManager.restorePurchases() }
                    }) {
                        Text("Restore Purchases")
                            .font(.callout)
                            .foregroundStyle(.blue)
                    }
                    .disabled(subscriptionManager.isLoading)

                    // Error Message
                    if let error = subscriptionManager.purchaseError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
                .background(Color(PlatformColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)

                // MARK: - Legal
                VStack(spacing: 8) {
                    Text("Payment will be charged to your Apple ID account. Subscription automatically renews unless canceled at least 24 hours before the end of the current period.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 16) {
                        Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            .font(.caption2)
                        Link("Privacy Policy", destination: URL(string: "https://www.apple.com/legal/privacy/")!)
                            .font(.caption2)
                    }
                }
                .padding(.bottom, 20)
            }
            .padding()
        }
        .background(Color(PlatformColor.systemGroupedBackground))
    }

    // MARK: - Feature Row

    private func featureRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(SubscriptionManager())
}
