//
//  SocialSecurityManager.swift
//  RetireSmartIRA
//
//  Manages Social Security planner data (benefit estimates, earnings history, parameters).
//  Extracted from DataManager as part of God Class decomposition.
//  Bridge methods that coordinate with other managers remain in DataManager+SocialSecurity.swift.
//

import SwiftUI
import Foundation
import Combine

@MainActor
class SocialSecurityManager: ObservableObject {
    @Published var primarySSBenefit: SSBenefitEstimate?
    @Published var spouseSSBenefit: SSBenefitEstimate?
    @Published var primaryEarningsHistory: SSEarningsHistory?
    @Published var spouseEarningsHistory: SSEarningsHistory?
    @Published var ssWhatIfParams = SSWhatIfParameters()
    @Published var ssAutoSync: Bool = true
}
