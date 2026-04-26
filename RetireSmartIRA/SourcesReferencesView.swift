//
//  SourcesReferencesView.swift
//  RetireSmartIRA
//
//  Official IRS, SSA, and CMS sources used in all calculations.
//

import SwiftUI

struct SourcesReferencesView: View {
    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(Color.UI.brandTeal)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tax Year \(TaxCalculationEngine.config.taxYear)")
                            .font(.headline)
                        Text("All calculations use current IRS rules, rates, and thresholds published for this tax year.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            sourceSection(
                title: "Federal Income Tax Brackets",
                icon: "building.columns.fill",
                description: "Ordinary income and capital gains brackets, marginal rates, and filing status thresholds.",
                sources: [
                    ("IRS Rev. Proc. 2025-32", "2026 tax year inflation adjustments", "https://www.irs.gov/irb/2025-32_IRB"),
                    ("IRS Publication 17", "Your Federal Income Tax", "https://www.irs.gov/publications/p17"),
                ]
            )

            sourceSection(
                title: "Standard Deduction & Senior Bonus",
                icon: "minus.circle.fill",
                description: "Base standard deduction, age 65+ additional amounts, and the OBBBA Senior Bonus ($6,000/person, 2025-2028).",
                sources: [
                    ("IRS Rev. Proc. 2025-32", "2026 standard deduction amounts", "https://www.irs.gov/irb/2025-32_IRB"),
                    ("One Big Beautiful Bill Act", "Senior Bonus provision, signed July 4, 2025", "https://www.congress.gov/bill/119th-congress/house-bill/1"),
                ]
            )

            sourceSection(
                title: "SALT Cap",
                icon: "house.fill",
                description: "State and local tax deduction cap: $10K under TCJA, expanded to $40K+ (2025-2029) under OBBBA with income-based phaseout.",
                sources: [
                    ("Tax Cuts and Jobs Act (2017)", "Original $10,000 SALT cap", "https://www.congress.gov/bill/115th-congress/house-bill/1"),
                    ("One Big Beautiful Bill Act", "SALT cap expansion 2025-2029", "https://www.congress.gov/bill/119th-congress/house-bill/1"),
                ]
            )

            sourceSection(
                title: "IRMAA Medicare Surcharges",
                icon: "cross.case.fill",
                description: "Income-Related Monthly Adjustment Amount: 6 tiers of Part B and Part D premium surcharges based on modified AGI from 2 years prior.",
                sources: [
                    ("CMS Medicare Premiums", "Annual premium and surcharge announcement", "https://www.cms.gov/newsroom/fact-sheets/2026-medicare-parts-b-premiums-and-deductibles"),
                    ("SSA IRMAA Information", "How Medicare premiums are affected by income", "https://www.ssa.gov/benefits/medicare/medicare-premiums.html"),
                ]
            )

            sourceSection(
                title: "NIIT (3.8% Net Investment Income Tax)",
                icon: "chart.line.uptrend.xyaxis",
                description: "Applies to net investment income when MAGI exceeds $200K (single) or $250K (MFJ). These thresholds are not inflation-adjusted.",
                sources: [
                    ("IRC Section 1411", "Net Investment Income Tax statute", "https://www.law.cornell.edu/uscode/text/26/1411"),
                    ("IRS Form 8960", "Net Investment Income Tax calculation", "https://www.irs.gov/forms-pubs/about-form-8960"),
                ]
            )

            sourceSection(
                title: "AMT (Alternative Minimum Tax)",
                icon: "exclamationmark.triangle.fill",
                description: "Exemption amounts, phaseout thresholds, and 26%/28% AMT rates. Triggered primarily by large SALT deductions.",
                sources: [
                    ("IRS Form 6251", "Alternative Minimum Tax for Individuals", "https://www.irs.gov/forms-pubs/about-form-6251"),
                    ("IRS Rev. Proc. 2025-32", "2026 AMT exemption amounts", "https://www.irs.gov/irb/2025-32_IRB"),
                ]
            )

            sourceSection(
                title: "RMD Life Expectancy Tables",
                icon: "calendar.badge.clock",
                description: "Uniform Lifetime Table III (account owners) and Single Life Expectancy Table I (inherited IRA beneficiaries). Updated by IRS in 2022.",
                sources: [
                    ("IRS Publication 590-B", "Distributions from Individual Retirement Arrangements", "https://www.irs.gov/publications/p590b"),
                    ("IRS Uniform Lifetime Table III", "Divisors for calculating owner RMDs", "https://www.irs.gov/retirement-plans/plan-participant-employee/required-minimum-distribution-worksheets"),
                ]
            )

            sourceSection(
                title: "Inherited IRA Rules (SECURE Act)",
                icon: "arrow.down.doc.fill",
                description: "SECURE Act (effective January 1, 2020) replaced lifetime stretch with a 10-year rule for most non-spouse beneficiaries. Deaths before 2020 are grandfathered \u{2014} those beneficiaries retain the classic lifetime stretch using Single Life Expectancy Table I (term-certain, subtract 1 each year).",
                sources: [
                    ("SECURE Act (2019)", "Section 401 \u{2014} modifications to required minimum distribution rules", "https://www.congress.gov/bill/116th-congress/house-bill/1994"),
                    ("Treas. Reg. \u{00A7}1.401(a)(9)-9", "Life expectancy and distribution period tables", "https://www.ecfr.gov/current/title-26/section-1.401(a)(9)-9"),
                    ("IRS Publication 590-B", "Inherited IRA distribution rules, including pre-2020 grandfathering", "https://www.irs.gov/publications/p590b"),
                ]
            )

            sourceSection(
                title: "Social Security",
                icon: "person.2.fill",
                description: "PIA bend points, Average Wage Index, full retirement age schedule, early/delayed filing adjustments, spousal and survivor benefit formulas.",
                sources: [
                    ("SSA Bend Points", "Primary Insurance Amount formula by year", "https://www.ssa.gov/oact/cola/bendpoints.html"),
                    ("SSA Average Wage Index", "National average wage index series", "https://www.ssa.gov/oact/cola/AWI.html"),
                    ("SSA Retirement Age", "Full retirement age by birth year", "https://www.ssa.gov/benefits/retirement/planner/ageincrease.html"),
                    ("IRS Publication 915", "Social Security and Equivalent Railroad Retirement Benefits (taxation thresholds)", "https://www.irs.gov/publications/p915"),
                ]
            )

            sourceSection(
                title: "QCD (Qualified Charitable Distributions)",
                icon: "heart.fill",
                description: "Annual limit per person (inflation-adjusted under SECURE 2.0 Act). Available at age 70\u{00BD}+.",
                sources: [
                    ("IRS Publication 590-B", "QCD rules and eligible organizations", "https://www.irs.gov/publications/p590b"),
                    ("SECURE 2.0 Act (2022)", "QCD inflation adjustment provision", "https://www.congress.gov/bill/117th-congress/house-bill/2617"),
                ]
            )

            sourceSection(
                title: "Estimated Tax & Safe Harbor",
                icon: "calendar.badge.exclamationmark",
                description: "Federal 90%/100%/110% safe harbor rules. State-specific rules and payment schedules for 25+ states, including California's 30/40/0/30 quarterly split.",
                sources: [
                    ("IRS Publication 505", "Tax Withholding and Estimated Tax", "https://www.irs.gov/publications/p505"),
                    ("IRS Form 2210", "Underpayment of Estimated Tax by Individuals", "https://www.irs.gov/forms-pubs/about-form-2210"),
                    ("CA FTB Form 5805", "California underpayment of estimated tax", "https://www.ftb.ca.gov/forms/misc/5805.html"),
                ]
            )

            sourceSection(
                title: "State Income Tax",
                icon: "map.fill",
                description: "Tax rates, brackets, standard deductions, and retirement income exemptions for all 50 states + DC. Sourced from each state's tax authority for the current tax year.",
                sources: [
                    ("Tax Foundation", "State individual income tax rates and brackets", "https://taxfoundation.org/data/all/state/state-income-tax-rates-2026/"),
                    ("Retirement Living", "State taxes on retirement income", "https://www.retirementliving.com/taxes-by-state"),
                ]
            )

            sourceSection(
                title: "California Exemption Credits",
                icon: "star.fill",
                description: "Personal exemption credits ($144/person), with income-based phaseout. Applied as a credit against California tax liability.",
                sources: [
                    ("CA FTB", "California personal exemption credit", "https://www.ftb.ca.gov/file/personal/deductions/index.html"),
                ]
            )

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Data is reviewed and updated annually when the IRS, SSA, and CMS publish new figures. State tax data is sourced from individual state tax authorities and cross-referenced with the Tax Foundation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("This app provides estimates for planning purposes only. Consult with a qualified tax professional for personalized advice.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Sources & References")
        .frame(minWidth: 500, minHeight: 600)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Reusable Source Section

    private func sourceSection(
        title: String,
        icon: String,
        description: String,
        sources: [(name: String, detail: String, url: String)]
    ) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundStyle(Color.UI.brandTeal)
                        .frame(width: 20)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                }

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(sources.indices, id: \.self) { i in
                    if let url = URL(string: sources[i].url) {
                        Link(destination: url) {
                            HStack(spacing: 6) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sources[i].name)
                                        .font(.caption)
                                        .foregroundStyle(Color.UI.brandTeal)
                                    Text(sources[i].detail)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption2)
                                    .foregroundStyle(Color.UI.brandTeal.opacity(0.6))
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    NavigationStack {
        SourcesReferencesView()
    }
}
