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
@Observable
class SocialSecurityManager {
    var primarySSBenefit: SSBenefitEstimate?
    var spouseSSBenefit: SSBenefitEstimate?
    var primaryEarningsHistory: SSEarningsHistory?
    var spouseEarningsHistory: SSEarningsHistory?
    var ssWhatIfParams = SSWhatIfParameters()
    var ssAutoSync: Bool = true
}
