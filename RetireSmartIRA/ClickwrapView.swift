//
//  ClickwrapView.swift
//  RetireSmartIRA
//
//  First-launch Terms of Use acceptance screen.
//  Shown until the user checks the box and taps Continue.
//

import SwiftUI

struct ClickwrapView: View {
    @ObservedObject var manager: TermsAcceptanceManager
    @State private var isChecked = false
    @State private var showFullTerms = false
    @State private var hasScrolledToBottom = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            VStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)
                Text("RetireSmartIRA")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Before you get started, please review and accept our Terms of Use.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 40)
            .padding(.bottom, 16)

            Divider()

            // MARK: - Scrollable summary
            ScrollView {
                termsSummaryView
                    .padding(.vertical, 16)
            }

            Divider()

            // MARK: - Bottom action area
            VStack(spacing: 12) {
                // Prominent "Read Terms" button — shown until user has scrolled to bottom
                if !hasScrolledToBottom {
                    Button {
                        showFullTerms = true
                    } label: {
                        Label("Read Full Terms of Use", systemImage: "doc.text.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 24)
                } else {
                    // After reading, show a subtle link to re-read
                    Button {
                        showFullTerms = true
                    } label: {
                        Label("Review Full Terms of Use", systemImage: "doc.text")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                checkboxRow

                Button {
                    manager.recordAcceptance()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isChecked ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .animation(.easeInOut(duration: 0.2), value: isChecked)
                }
                .disabled(!isChecked)
                .padding(.horizontal, 24)

                Text("You must accept the Terms of Use to use RetireSmartIRA.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(Color(PlatformColor.systemGroupedBackground))
        .sheet(isPresented: $showFullTerms) {
            fullTermsView
        }
    }

    // MARK: - CheckboxRow

    private var checkboxRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isChecked.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(isChecked ? .blue : .secondary)
                    Text("I have read and agree to the **Terms of Use** (v\(TermsAcceptanceManager.currentToUVersion)) for RetireSmartIRA.")
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(hasScrolledToBottom ? .primary : .secondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(!hasScrolledToBottom)

            if !hasScrolledToBottom {
                Label("Please read the full Terms of Use first", systemImage: "arrow.up.doc")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.leading, 38)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - TermsSummaryView

    private var termsSummaryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            summaryRow(
                icon: "info.circle",
                title: "Not Financial Advice",
                body: "RetireSmartIRA provides educational estimates only. Results are not tax, legal, or investment advice. Consult a qualified professional before making financial decisions."
            )
            summaryRow(
                icon: "exclamationmark.triangle",
                title: "No Warranty",
                body: "The app is provided \"as is.\" While we work to keep calculations accurate, we make no guarantees regarding completeness or fitness for any particular purpose."
            )
            summaryRow(
                icon: "dollarsign.circle",
                title: "Free to Use",
                body: "RetireSmartIRA is currently free. If paid features are introduced in the future, you will be notified and no charges will apply without your consent."
            )
            summaryRow(
                icon: "lock.shield",
                title: "Privacy",
                body: "We collect minimal data necessary to operate the app. We do not sell your personal information. See our Privacy Policy for full details."
            )
            summaryRow(
                icon: "scalemass",
                title: "Limitation of Liability",
                body: "To the extent permitted by law, Alamo Ventures Group LLC\u{2019}s liability is limited to the amount you paid for the app in the preceding 12 months."
            )
            summaryRow(
                icon: "map",
                title: "Governing Law",
                body: "These terms are governed by the laws of the State of California. Disputes are subject to binding arbitration in Contra Costa County, California."
            )
        }
        .padding(.horizontal, 24)
    }

    private func summaryRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - FullTermsView

    private var fullTermsView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Text(TermsOfUseText.fullText)
                        .font(.footnote)
                        .padding()

                    // Invisible marker at the bottom of the terms text
                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            withAnimation {
                                hasScrolledToBottom = true
                            }
                        }
                }
            }
            .navigationTitle("Terms of Use")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showFullTerms = false }
                }
            }
        }
    }
}

#Preview {
    ClickwrapView(manager: TermsAcceptanceManager())
}
