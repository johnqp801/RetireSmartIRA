//
//  ActionItemKey.swift
//  RetireSmartIRA
//

import Foundation

enum ActionItemType: String {
    case roth
    case qcd
    case stockDonation = "stock_donation"
    case rmd
}

func actionItemKey(year: Int, action: ActionItemType) -> String {
    "action_done_\(year)_\(action.rawValue)"
}
