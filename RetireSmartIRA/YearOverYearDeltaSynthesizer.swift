//
//  YearOverYearDeltaSynthesizer.swift
//  RetireSmartIRA
//

import Foundation

enum YearOverYearDeltaSynthesizer {
    struct Result {
        let taxDelta: Double?
        let causeSentence: String?
    }

    static func synthesize(prior: YearRecommendation?, current: YearRecommendation) -> Result {
        guard let prior else {
            return Result(taxDelta: nil, causeSentence: nil)
        }

        let taxDelta = current.taxBreakdown.total - prior.taxBreakdown.total

        let priorActionKinds = Set(prior.actions.map(\.actionKind))

        if current.actions.contains(where: { $0.actionKind == .traditionalWithdrawal })
            && !priorActionKinds.contains(.traditionalWithdrawal) {
            return Result(taxDelta: taxDelta, causeSentence: "RMDs begin.")
        }

        if current.actions.contains(where: { $0.actionKind == .claimSocialSecurity })
            && !priorActionKinds.contains(.claimSocialSecurity) {
            return Result(taxDelta: taxDelta, causeSentence: "Social Security claimed.")
        }

        if prior.taxBreakdown.irmaa == 0 && current.taxBreakdown.irmaa > 0 {
            return Result(taxDelta: taxDelta, causeSentence: "IRMAA Tier 1 crossed.")
        }

        if abs(taxDelta) < 1_000 {
            return Result(taxDelta: taxDelta, causeSentence: nil)
        }

        return Result(taxDelta: taxDelta, causeSentence: "Bracket / income change.")
    }
}

private extension LeverAction {
    enum ActionKind: Equatable {
        case rothConversion
        case traditionalWithdrawal
        case taxableWithdrawal
        case rothWithdrawal
        case hsaContribution
        case fourOhOneKContribution
        case deferSocialSecurity
        case claimSocialSecurity
    }

    var actionKind: ActionKind {
        switch self {
        case .rothConversion: return .rothConversion
        case .traditionalWithdrawal: return .traditionalWithdrawal
        case .taxableWithdrawal: return .taxableWithdrawal
        case .rothWithdrawal: return .rothWithdrawal
        case .hsaContribution: return .hsaContribution
        case .fourOhOneKContribution: return .fourOhOneKContribution
        case .deferSocialSecurity: return .deferSocialSecurity
        case .claimSocialSecurity: return .claimSocialSecurity
        }
    }
}
