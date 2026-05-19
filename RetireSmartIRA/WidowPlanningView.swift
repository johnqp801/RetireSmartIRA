//
//  WidowPlanningView.swift
//  RetireSmartIRA
//
//  Dedicated view promoting the widow-penalty callout into a full analysis:
//  bracket-compression card, IRMAA acceleration note, strategic recommendation,
//  and a sensitivity slider for lifetime survivor tax delta.
//

import SwiftUI

struct WidowPlanningView: View {
    @Environment(DataManager.self) var dataManager
    @State private var conversionAmount: Double = 0
    @State private var survivorYears: Double = 10

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                bracketCompressionCard
                irmaaAccelerationCard
                strategicRecommendation
                sensitivitySlider
            }
            .padding()
        }
        .navigationTitle("Widow Planning")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Widow Planning")
                .font(.title2.weight(.semibold))
            Text("The single-filer year is typically the most expensive single tax event for couples with large Traditional balances. Below: how it lands and what to do about it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var bracketCompressionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bracket Compression").font(.headline)
            HStack {
                Text("Current MFJ marginal rate")
                Spacer()
                Text("\(Int(dataManager.widowCurrentMarginalRate * 100))%").fontWeight(.semibold)
            }
            HStack {
                Text("Survivor's single-filer marginal rate")
                Spacer()
                Text("\(Int(dataManager.widowSurvivorMarginalRate * 100))%")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.Semantic.red)
            }
            HStack {
                Text("Annual delta on RMD income")
                Spacer()
                Text(dataManager.widowAdditionalTaxPerYear, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .fontWeight(.semibold)
            }
        }
        .font(.callout)
        .padding()
        .background(Color.UI.surfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var irmaaAccelerationCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("IRMAA Acceleration").font(.headline)
            Text("Single-filer IRMAA tiers kick in at roughly half the MFJ thresholds. The same MAGI that costs a couple Tier 1 surcharges can put a survivor in Tier 3 or higher.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.UI.surfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var strategicRecommendation: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Strategy").font(.headline)
            Text("Convert aggressively in joint years to drain the Traditional balance before single-filer brackets compress. Every dollar converted at MFJ rates saves the survivor roughly \(Int(dataManager.widowBracketJump * 100))% of bracket spread.")
                .font(.callout).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.Semantic.greenTint)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var sensitivitySlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sensitivity").font(.headline)
            Text("Conversion: $\(Int(conversionAmount).formatted())  |  Survivor years: \(Int(survivorYears))")
                .font(.caption).foregroundStyle(.secondary)
            Slider(value: $conversionAmount, in: 0...500_000, step: 5_000)
            Slider(value: $survivorYears, in: 0...30, step: 1)
            let delta = dataManager.widowLifetimeTaxDelta(conversionAmount: conversionAmount, survivorYears: Int(survivorYears))
            HStack {
                Text("Lifetime survivor tax delta")
                Spacer()
                Text(delta, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .fontWeight(.semibold)
                    .foregroundStyle(delta > 0 ? Color.Semantic.red : Color.Semantic.green)
            }
            // Decision C: V2.0 approximation tooltip
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text("Approximate single-filer adjustment. V2.0 will model this year-by-year through the multi-year engine.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color.UI.surfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
