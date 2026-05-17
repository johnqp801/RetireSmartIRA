//
//  SmartSliderNotches.swift
//  RetireSmartIRA
//
//  Pure notch-computation for ConversionSliderCard / WithdrawalSliderCard.
//  Pure-Swift, no SwiftUI. Tested independently of UI.
//

import Foundation
import CoreGraphics

public struct IRMAATierCrossing: Equatable {
    public let value: Double
    public let tier: Int
    public init(value: Double, tier: Int) { self.value = value; self.tier = tier }
}

public struct SmartSliderNotch: Equatable, Identifiable {
    public enum Kind: String, Equatable {
        case bracketFill
        case acaCliff
        case irmaaTier
    }
    public let id: String
    public let value: Double
    public let kind: Kind
    public let label: String
}

public enum SmartSliderNotches {

    /// Compute the ordered, deduplicated set of notches to render on a slider of `sliderMax`.
    /// Precedence on duplicates: bracketFill > acaCliff > irmaaTier (first-write-wins in that order).
    public static func compute(
        sliderMax: Double,
        bracketFillAmounts: [Double],
        cliffAmounts: [Double],
        irmaaTierCrossings: [IRMAATierCrossing]
    ) -> [SmartSliderNotch] {
        guard sliderMax > 0 else { return [] }
        var byValue: [Double: SmartSliderNotch] = [:]

        for v in bracketFillAmounts where v > 0 && v <= sliderMax {
            byValue[v] = SmartSliderNotch(
                id: "bracket-\(Int(v))",
                value: v,
                kind: .bracketFill,
                label: "Fills bracket at \(formatK(v))"
            )
        }
        for v in cliffAmounts where v > 0 && v <= sliderMax {
            if byValue[v] == nil {
                byValue[v] = SmartSliderNotch(
                    id: "cliff-\(Int(v))",
                    value: v,
                    kind: .acaCliff,
                    label: "ACA cliff"
                )
            }
        }
        for crossing in irmaaTierCrossings where crossing.value > 0 && crossing.value <= sliderMax {
            if byValue[crossing.value] == nil {
                byValue[crossing.value] = SmartSliderNotch(
                    id: "irmaa-\(crossing.tier)-\(Int(crossing.value))",
                    value: crossing.value,
                    kind: .irmaaTier,
                    label: "IRMAA Tier \(crossing.tier)"
                )
            }
        }
        return byValue.values.sorted { $0.value < $1.value }
    }

    /// Fraction (0...1) along a slider for `value` against `sliderMax`.
    public static func position(value: Double, sliderMax: Double) -> CGFloat {
        guard sliderMax > 0 else { return 0 }
        return CGFloat(max(0, min(1, value / sliderMax)))
    }

    private static func formatK(_ v: Double) -> String {
        if v >= 1_000 { return String(format: "$%.0fK", v / 1_000) }
        return String(format: "$%.0f", v)
    }
}
