//
//  GuideView.swift
//  RetireSmartIRA
//
//  Get Started guide: setup checklist, tab guides, key concepts, and tips
//

import SwiftUI

struct GuideView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isWideLayout: Bool { horizontalSizeClass == .regular }

    // Section expansion states
    @State private var quickStartExpanded: Bool = true
    @State private var settingsGuideExpanded: Bool = false
    @State private var accountsGuideExpanded: Bool = false
    @State private var incomeGuideExpanded: Bool = false
    @State private var taxSummaryGuideExpanded: Bool = false
    @State private var rmdGuideExpanded: Bool = false
    @State private var scenariosGuideExpanded: Bool = false
    @State private var quarterlyTaxGuideExpanded: Bool = false
    @State private var keyConceptsExpanded: Bool = false
    @State private var tipsExpanded: Bool = false

    var body: some View {
        Group {
            if isWideLayout {
                wideBody
            } else {
                compactBody
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Layout Variants

    private var compactBody: some View {
        ScrollView {
            VStack(spacing: 24) {
                welcomeHeader
                setupProgressCard
                quickStartChecklist
                tabGuidesHeader
                settingsGuide
                incomeGuide
                accountsGuide
                rmdGuide
                scenariosGuide
                taxSummaryGuide
                quarterlyTaxGuide
                keyConceptsSection
                tipsSection
                disclaimerCard
            }
            .padding()
        }
    }

    private var wideBody: some View {
        HStack(alignment: .top, spacing: 20) {
            ScrollView {
                VStack(spacing: 24) {
                    welcomeHeader
                    setupProgressCard
                    quickStartChecklist
                    keyConceptsSection
                    tipsSection
                    disclaimerCard
                }
                .padding()
            }
            .frame(maxWidth: .infinity)

            ScrollView {
                VStack(spacing: 24) {
                    tabGuidesHeader
                    settingsGuide
                    incomeGuide
                    accountsGuide
                    rmdGuide
                    scenariosGuide
                    taxSummaryGuide
                    quarterlyTaxGuide
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Welcome Header

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundStyle(.blue)
                Text("Get Started")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Text("Your all-in-one retirement tax planning toolkit. Manage IRAs and 401(k)s, calculate RMDs, model Roth conversions, plan QCDs and charitable giving, project federal and state taxes, and stay on top of quarterly estimated payments \u{2014} all in one place.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("Uses 2026 federal tax brackets and all 50 state tax rates. Supports single and married filing jointly.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Setup Progress Card

    private var setupProgressCard: some View {
        let progress = dataManager.setupProgress

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Setup Progress")
                    .font(.headline)
                Spacer()
                Text("\(progress.completedSteps) of \(progress.totalSteps)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(progress.isComplete ? .green : .secondary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progress.isComplete ? Color.green : Color.blue)
                        .frame(width: geometry.size.width * Double(progress.completedSteps) / Double(progress.totalSteps), height: 8)
                }
            }
            .frame(height: 8)

            VStack(alignment: .leading, spacing: 10) {
                setupStepRow(title: "Set your date of birth", isComplete: progress.hasSetBirthDate)
                setupStepRow(title: "Add retirement accounts", isComplete: progress.hasAccounts)
                setupStepRow(title: "Enter income sources", isComplete: progress.hasIncomeSources)
                setupStepRow(title: "Add deductions", isComplete: progress.hasDeductions)
            }

            if progress.isComplete {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("All set! Your data is ready for tax planning.")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func setupStepRow(title: String, isComplete: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isComplete ? .green : .secondary)
                .font(.title3)
            Text(title)
                .font(.subheadline)
                .strikethrough(isComplete)
                .foregroundStyle(isComplete ? .secondary : .primary)
            Spacer()
        }
    }

    // MARK: - Quick Start Checklist

    private var quickStartChecklist: some View {
        DisclosureGroup(isExpanded: $quickStartExpanded) {
            VStack(alignment: .leading, spacing: 16) {
                quickStartStep(
                    number: 1,
                    title: "Settings",
                    description: "Set your date of birth and filing status. If married filing jointly, enable and configure your spouse.",
                    tabIcon: "gearshape.fill",
                    tabColor: .gray
                )
                quickStartStep(
                    number: 2,
                    title: "Income & Deductions",
                    description: "Enter all income sources with tax withholding amounts. Optionally add itemized deductions.",
                    tabIcon: "banknote.fill",
                    tabColor: .green
                )
                quickStartStep(
                    number: 3,
                    title: "Accounts",
                    description: "Add your Traditional IRA, Roth IRA, Traditional 401(k), and Roth 401(k) accounts with current balances.",
                    tabIcon: "building.columns.fill",
                    tabColor: .blue
                )
                quickStartStep(
                    number: 4,
                    title: "RMD Calculator",
                    description: "Check your Required Minimum Distribution status, deadlines, and project future RMDs under different growth scenarios.",
                    tabIcon: "calendar.badge.clock",
                    tabColor: .red
                )
                quickStartStep(
                    number: 5,
                    title: "Scenarios",
                    description: "Model Roth conversions, QCDs, stock and cash donations, and extra withdrawals. See real-time tax impact and bracket analysis.",
                    tabIcon: "slider.horizontal.3",
                    tabColor: .orange
                )
                quickStartStep(
                    number: 6,
                    title: "Tax Summary",
                    description: "Review your income breakdown, tax projection, and action items. Everything updates automatically.",
                    tabIcon: "chart.bar.fill",
                    tabColor: .purple
                )
                quickStartStep(
                    number: 7,
                    title: "Quarterly Tax",
                    description: "Review estimated quarterly tax payments based on all your Scenario decisions.",
                    tabIcon: "dollarsign.circle.fill",
                    tabColor: .purple
                )
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Image(systemName: "list.number")
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                Text("Quick Start Checklist")
                    .font(.headline)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func quickStartStep(number: Int, title: String, description: String, tabIcon: String, tabColor: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.callout)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(tabColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: tabIcon)
                        .foregroundStyle(tabColor)
                        .font(.subheadline)
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Tab Guides

    private var tabGuidesHeader: some View {
        HStack {
            Image(systemName: "square.grid.2x2.fill")
                .foregroundStyle(.blue)
            Text("Tab Guides")
                .font(.title3)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tabGuideSection<Content: View>(icon: String, title: String, color: Color, isExpanded: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func guidePoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var settingsGuide: some View {
        tabGuideSection(icon: "gearshape.fill", title: "Settings", color: .gray, isExpanded: $settingsGuideExpanded) {
            guidePoint("Set your date of birth to determine current age, RMD age, and QCD eligibility")
            guidePoint("Choose Single or Married Filing Jointly")
            guidePoint("If married, enable spouse tracking with name and date of birth")
            guidePoint("RMD age is calculated automatically: 72 (born before 1951), 73 (1951\u{2013}1959), or 75 (1960+)")
            guidePoint("Changes save automatically")
        }
    }

    private var accountsGuide: some View {
        tabGuideSection(icon: "building.columns.fill", title: "Accounts", color: .blue, isExpanded: $accountsGuideExpanded) {
            guidePoint("Add all retirement accounts: Traditional IRA, Roth IRA, Traditional 401(k), Roth 401(k)")
            guidePoint("Enter current balances \u{2014} these drive RMD calculations")
            guidePoint("Assign each account to an owner (You, Spouse, or Joint)")
            guidePoint("Only Traditional accounts have RMD requirements; Roth IRAs do not")
            guidePoint("Tap any account to edit; swipe to delete")
        }
    }

    private var incomeGuide: some View {
        tabGuideSection(icon: "banknote.fill", title: "Income & Deductions", color: .green, isExpanded: $incomeGuideExpanded) {
            guidePoint("Add every income source: Social Security, pensions, dividends, interest, capital gains, consulting")
            guidePoint("Enter tax withholding for each source \u{2014} this reduces quarterly payment estimates")
            guidePoint("Social Security is taxed at 0%, 50%, or 85% based on combined income thresholds")
            guidePoint("Long-term capital gains and qualified dividends receive preferential federal tax rates")
            guidePoint("Add itemized deductions (mortgage interest, property tax, medical, SALT) to compare against the standard deduction")
            guidePoint("The app automatically picks whichever deduction is higher, or you can override in Scenarios")
        }
    }

    private var taxSummaryGuide: some View {
        tabGuideSection(icon: "chart.bar.fill", title: "Tax Summary", color: .purple, isExpanded: $taxSummaryGuideExpanded) {
            guidePoint("Shows your complete financial picture at a glance")
            guidePoint("Income Breakdown: all sources plus RMD amounts")
            guidePoint("Tax Projection: federal + state tax, withholding credit, quarterly payment estimate")
            guidePoint("Tax Rates: marginal and average rates for both federal and California")
            guidePoint("Action Items: a to-do list generated from your RMDs, conversions, QCDs, and quarterly payments")
            guidePoint("Account Balances: Traditional vs. Roth totals with per-owner breakdown if married")
        }
    }

    private var rmdGuide: some View {
        tabGuideSection(icon: "calendar.badge.clock", title: "RMD Calculator", color: .red, isExpanded: $rmdGuideExpanded) {
            guidePoint("Shows whether RMDs are required based on your age and birth year")
            guidePoint("Displays current year RMD amount using the IRS Uniform Lifetime Table factor")
            guidePoint("Per-account breakdown showing each account\u{2019}s RMD contribution")
            guidePoint("Projection tool: model future RMDs over multiple years with adjustable growth rates")
            guidePoint("Key deadline: December 31 each year (first-year RMD can be delayed to April 1 of next year, but two RMDs in one year)")
            guidePoint("If married, shows separate projections for each spouse plus combined household totals")
        }
    }

    private var scenariosGuide: some View {
        tabGuideSection(icon: "slider.horizontal.3", title: "Scenarios", color: .orange, isExpanded: $scenariosGuideExpanded) {
            guidePoint("This is the scenario modeling engine \u{2014} changes here flow to Tax Summary and Quarterly Tax")
            guidePoint("Withdrawal Timing: choose which quarter you plan to take each withdrawal or conversion \u{2014} this shifts the tax obligation to that quarter\u{2019}s estimated payment")
            guidePoint("Roth Conversions: set conversion amounts and see real-time bracket impact")
            guidePoint("QCD (Qualified Charitable Distribution): donate up to $111k/person directly from IRA to charity; satisfies RMD tax-free; requires age 70\u{00BD}+")
            guidePoint("Appreciated Stock Donation: donate long-term stock to avoid capital gains tax and get a fair market value deduction")
            guidePoint("Cash Donations: direct cash gifts that provide a tax benefit when itemizing")
            guidePoint("Bracket Analysis shows whether your scenario pushes you into a higher federal or state bracket")
            guidePoint("Per-Decision Tax Impact shows the incremental tax cost or savings of each decision")
        }
    }

    private var quarterlyTaxGuide: some View {
        tabGuideSection(icon: "dollarsign.circle.fill", title: "Quarterly Tax", color: .purple, isExpanded: $quarterlyTaxGuideExpanded) {
            guidePoint("Shows estimated quarterly tax payments based on all income and Scenario decisions")
            guidePoint("Annual tax summary: gross income, deductions, taxable income, federal + state tax")
            guidePoint("Withholding from income sources is credited against your total liability")
            guidePoint("Payment schedule with IRS deadlines: April 15, June 15, September 15, January 15")
            guidePoint("Payment amounts vary by quarter based on when withdrawals and conversions are planned")
            guidePoint("Based on 90% safe harbor rule: pay 90% of current year tax to avoid underpayment penalties")
            guidePoint("Automatically recalculates when Scenario decisions change")
        }
    }

    // MARK: - Key Concepts

    private var keyConceptsSection: some View {
        DisclosureGroup(isExpanded: $keyConceptsExpanded) {
            VStack(alignment: .leading, spacing: 16) {
                conceptItem(
                    icon: "calendar",
                    title: "RMD Age Rules",
                    description: "Born before 1951: age 72. Born 1951\u{2013}1959: age 73. Born 1960+: age 75. Missing an RMD incurs a 25% penalty."
                )
                conceptItem(
                    icon: "arrow.right.arrow.left",
                    title: "Roth Conversion Window",
                    description: "The years between retirement and RMD age are ideal for converting Traditional IRA funds to Roth at potentially lower tax rates. Once RMDs begin, your taxable income rises."
                )
                conceptItem(
                    icon: "heart.fill",
                    title: "QCD Strategy",
                    description: "Qualified Charitable Distributions (up to $111,000/person/year) go directly from your IRA to charity. They satisfy your RMD but are excluded from taxable income. Available at age 70\u{00BD}+."
                )
                conceptItem(
                    icon: "doc.plaintext",
                    title: "Standard vs. Itemized",
                    description: "The app compares your standard deduction (including age-based senior bonuses) against your itemized total. Charitable contributions from Scenarios are included automatically."
                )
                conceptItem(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Scenario Flow",
                    description: "Scenario decisions flow through to Tax Summary (tax projection, action items) and Quarterly Tax (estimated payments). All three views stay in sync."
                )
                conceptItem(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Preferential Tax Rates",
                    description: "Long-term capital gains and qualified dividends are taxed at 0%, 15%, or 20% federally. California taxes all income as ordinary."
                )
                conceptItem(
                    icon: "person.2.fill",
                    title: "Filing Status Impact",
                    description: "Married Filing Jointly has wider tax brackets, a higher standard deduction, and different Social Security taxation thresholds compared to Single."
                )
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .frame(width: 24)
                Text("Key Concepts")
                    .font(.headline)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func conceptItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Tips & Best Practices

    private var tipsSection: some View {
        DisclosureGroup(isExpanded: $tipsExpanded) {
            VStack(alignment: .leading, spacing: 16) {
                tipItem(
                    icon: "arrow.right.arrow.left",
                    color: .orange,
                    title: "Convert Before RMDs",
                    description: "If you have years before RMDs start, consider Roth conversions to fill up lower tax brackets each year."
                )
                tipItem(
                    icon: "heart.fill",
                    color: .red,
                    title: "Use QCDs If Eligible",
                    description: "If you are age 70\u{00BD}+ and have RMDs, QCDs are the most tax-efficient way to give to charity."
                )
                tipItem(
                    icon: "chart.bar.fill",
                    color: .blue,
                    title: "Watch the Brackets",
                    description: "Use Scenarios\u{2019} bracket analysis to find the sweet spot where you maximize conversions without jumping to a higher marginal rate."
                )
                tipItem(
                    icon: "dollarsign.circle",
                    color: .green,
                    title: "Track Withholding",
                    description: "Enter tax withholding on each income source so quarterly payment estimates reflect what you have already paid."
                )
                tipItem(
                    icon: "doc.text.fill",
                    color: .purple,
                    title: "Check Deductions",
                    description: "If you have significant mortgage interest, property tax, or medical expenses, add them. Charitable contributions may push you over the standard deduction threshold."
                )
                tipItem(
                    icon: "arrow.clockwise",
                    color: .teal,
                    title: "Revisit Quarterly",
                    description: "Review your scenario each quarter. Life changes, market fluctuations, and new income can shift your optimal strategy."
                )
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(.orange)
                    .frame(width: 24)
                Text("Tips & Best Practices")
                    .font(.headline)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func tipItem(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Disclaimer

    private var disclaimerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundStyle(.orange)
                Text("Disclaimer")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            Text("This app provides estimates for planning purposes only. Consult with a qualified tax professional or financial advisor for personalized advice. Tax laws and regulations may change.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

#Preview {
    GuideView()
        .environmentObject(DataManager())
}
