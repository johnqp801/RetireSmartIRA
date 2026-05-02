//
//  SpouseID.swift
//  RetireSmartIRA
//
//  Identifies which member of a couple a given operation applies to.
//  Used by MultiYearStaticInputs.withClaimAge(_:for:) and downstream SS nudge logic.
//

import Foundation

enum SpouseID: String, Codable, CaseIterable, Equatable {
    case primary
    case spouse
}
