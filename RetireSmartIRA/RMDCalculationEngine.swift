//
//  RMDCalculationEngine.swift
//  RetireSmartIRA
//
//  Pure RMD calculation logic extracted from DataManager.
//  All static methods — no SwiftUI, no persistence, no DataManager dependency.
//

import Foundation

struct RMDCalculationEngine {

    // MARK: - Core RMD

    static func calculateRMD(for age: Int, balance: Double) -> Double {
        // V2.0 SIMPLIFICATION: First-RMD April 1 deferral not modeled.
        // IRS allows the FIRST RMD to be deferred until April 1 of the year following
        // the year the owner reaches RMD age. This engine assumes the RMD is taken
        // in the turning-RMD-age year (no deferral). A user who defers their first
        // RMD would actually take TWO RMDs in year 2 (year-1 deferred + year-2 current)
        // — that double-RMD is not modeled here. V2.1 task.
        let divisor = lifeExpectancyFactor(for: age)
        return balance / divisor
    }

    // MARK: - IRS Uniform Lifetime Table III

    // V2.0 SIMPLIFICATION: Joint Life and Last Survivor Expectancy Table not embedded.
    // When the sole designated beneficiary is a spouse MORE than 10 years younger, IRS
    // allows using the Joint Life table (IRS Pub 590-B Table II), which produces a
    // larger factor (smaller RMD) than Uniform Lifetime Table III. This engine always
    // uses Uniform Lifetime Table III, which slightly over-states RMDs for affected
    // households. V2.1 should embed the Joint Life table and branch on the spouse-age
    // differential when the sole-beneficiary-spouse flag is set.
    static func lifeExpectancyFactor(for age: Int) -> Double {
        let table: [Int: Double] = [
            70: 29.1, 71: 28.2, 72: 27.4, 73: 26.5, 74: 25.5, 75: 24.6, 76: 23.7,
            77: 22.9, 78: 22.0, 79: 21.1, 80: 20.2, 81: 19.4,
            82: 18.5, 83: 17.7, 84: 16.8, 85: 16.0, 86: 15.2,
            87: 14.4, 88: 13.7, 89: 12.9, 90: 12.2, 91: 11.5,
            92: 10.8, 93: 10.1, 94: 9.5, 95: 8.9, 96: 8.4,
            97: 7.8, 98: 7.3, 99: 6.8, 100: 6.4, 101: 6.0,
            102: 5.6, 103: 5.2, 104: 4.9, 105: 4.6, 106: 4.3,
            107: 4.1, 108: 3.9, 109: 3.7, 110: 3.5, 111: 3.4,
            112: 3.3, 113: 3.1, 114: 3.0, 115: 2.9, 116: 2.8,
            117: 2.7, 118: 2.5, 119: 2.3, 120: 2.0
        ]
        return table[age] ?? 2.0 // Default to 2.0 for ages beyond table
    }

    // MARK: - IRS Single Life Expectancy Table I (for Inherited IRAs)

    static func singleLifeExpectancyFactor(for age: Int) -> Double {
        let table: [Int: Double] = [
            0: 84.6, 1: 83.6, 2: 82.6, 3: 81.6, 4: 80.6,
            5: 79.7, 6: 78.7, 7: 77.7, 8: 76.7, 9: 75.8,
            10: 74.8, 11: 73.8, 12: 72.8, 13: 71.8, 14: 70.8,
            15: 69.9, 16: 68.9, 17: 67.9, 18: 66.9, 19: 66.0,
            20: 65.0, 21: 64.0, 22: 63.0, 23: 62.1, 24: 61.1,
            25: 60.2, 26: 59.2, 27: 58.2, 28: 57.3, 29: 56.3,
            30: 55.3, 31: 54.4, 32: 53.4, 33: 52.5, 34: 51.5,
            35: 50.5, 36: 49.6, 37: 48.6, 38: 47.7, 39: 46.7,
            40: 45.7, 41: 44.8, 42: 43.8, 43: 42.9, 44: 41.9,
            45: 41.0, 46: 40.0, 47: 39.0, 48: 38.1, 49: 37.1,
            50: 36.2, 51: 35.3, 52: 34.3, 53: 33.4, 54: 32.5,
            55: 31.6, 56: 30.6, 57: 29.8, 58: 28.9, 59: 28.0,
            60: 27.1, 61: 26.2, 62: 25.4, 63: 24.5, 64: 23.7,
            65: 22.9, 66: 22.0, 67: 21.2, 68: 20.4, 69: 19.6,
            70: 18.8, 71: 18.0, 72: 17.2, 73: 16.4, 74: 15.6,
            75: 14.8, 76: 14.1, 77: 13.3, 78: 12.6, 79: 11.9,
            80: 11.2, 81: 10.5, 82: 9.9, 83: 9.3, 84: 8.7,
            85: 8.1, 86: 7.5, 87: 7.1, 88: 6.6, 89: 6.1,
            90: 5.7, 91: 5.3, 92: 4.9, 93: 4.6, 94: 4.3,
            95: 4.0, 96: 3.7, 97: 3.4, 98: 3.2, 99: 2.9,
            100: 2.7, 101: 2.5, 102: 2.3, 103: 2.1, 104: 1.9,
            105: 1.8, 106: 1.6, 107: 1.4, 108: 1.3, 109: 1.1,
            110: 1.0, 111: 0.9, 112: 0.8, 113: 0.7, 114: 0.6,
            115: 0.5, 116: 0.4, 117: 0.3, 118: 0.2, 119: 0.1
        ]
        let clamped = max(0, min(119, age))
        return table[clamped] ?? 1.0
    }

    // MARK: - Inherited IRA RMD

    static func calculateInheritedIRARMD(account: IRAAccount, forYear year: Int) -> InheritedRMDResult {
        guard account.accountType.isInherited,
              let beneficiaryType = account.beneficiaryType,
              let yearOfInheritance = account.yearOfInheritance,
              let beneficiaryBirthYear = account.beneficiaryBirthYear else {
            return InheritedRMDResult(annualRMD: 0, mustEmptyByYear: nil, yearsRemaining: nil, rule: "Missing inherited IRA data")
        }

        let yearsElapsed = year - yearOfInheritance
        let beneficiaryAge = year - beneficiaryBirthYear
        let isRothInherited = account.accountType == .inheritedRothIRA
        let deadline = yearOfInheritance + 10
        // Pre-SECURE: deaths before 2020-01-01 are grandfathered into the old stretch rules.
        let isPreSECURE = yearOfInheritance < 2020

        // Roth owners are always deemed to die before RBD (Treas. Reg. §1.408-8(b)(1)(ii)),
        // so any after-RBD branching is treated as before-RBD for Roth.
        let effectiveRBDStatus: DecedentRBDStatus = isRothInherited
            ? .beforeRBD
            : (account.decedentRBDStatus ?? .beforeRBD)

        // Roth-specific early branches:
        //   Spouse: §1.401(a)(9)-3(d) / §1.408-8(c)(2) allow deferral of RMDs until the year
        //     the decedent would have reached applicable RMD age. Until we model that year,
        //     we conservatively report $0 (correct for the pre-applicable-age period).
        //   Non-EDB post-SECURE: 10-year rule, no annual RMDs.
        //   All other Roth cases (non-spouse EDBs, pre-SECURE non-EDB) fall through to the
        //   per-type switch with rbdStatus forced to .beforeRBD via effectiveRBDStatus.
        if isRothInherited {
            if beneficiaryType == .spouse {
                // V2.0 SIMPLIFICATION: Spouse inherited Roth uses zero-RMD placeholder.
                // A surviving spouse who inherits a Roth IRA has no RMD obligation until
                // the year the decedent would have reached applicable RMD age (§1.408-8(c)(2)).
                // This placeholder correctly returns $0 for the PRE-applicable-age period but
                // UNDER-STATES future RMDs after that date — in reality the spouse should begin
                // taking RMDs (using their own SLE as sole beneficiary). V2.1 task: track
                // the decedent's would-be RMD age and switch to lifetime-stretch RMD calculation
                // once that year is reached.
                return InheritedRMDResult(
                    annualRMD: 0,
                    mustEmptyByYear: nil,
                    yearsRemaining: nil,
                    rule: "Surviving spouse of Roth — no RMD until decedent's would-be applicable RMD age (simplified)"
                )
            }
            if !beneficiaryType.isEligibleDesignated && !isPreSECURE {
                let remaining = max(0, deadline - year)
                if year >= deadline {
                    return InheritedRMDResult(
                        annualRMD: account.balance,
                        mustEmptyByYear: deadline,
                        yearsRemaining: 0,
                        rule: "10-year deadline reached — full balance must be withdrawn (Roth)"
                    )
                }
                return InheritedRMDResult(
                    annualRMD: 0,
                    mustEmptyByYear: deadline,
                    yearsRemaining: remaining,
                    rule: "10-year rule — no annual RMDs, must empty by \(deadline) (Roth)"
                )
            }
            // Non-spouse EDBs and pre-SECURE non-EDBs: fall through to the switch below.
        }

        // Traditional Inherited IRA (and Roth fall-through cases) by beneficiary type
        switch beneficiaryType {
        case .spouse:
            guard yearsElapsed >= 1 else {
                return InheritedRMDResult(annualRMD: 0, mustEmptyByYear: nil, yearsRemaining: nil,
                                          rule: "Spouse — RMDs begin the year after inheritance")
            }
            let factor = singleLifeExpectancyFactor(for: beneficiaryAge)
            let rmd = factor > 0 ? account.balance / factor : account.balance
            return InheritedRMDResult(
                annualRMD: rmd,
                mustEmptyByYear: nil,
                yearsRemaining: nil,
                rule: "Spouse — lifetime stretch (SLE factor \(String(format: "%.1f", factor)) at age \(beneficiaryAge))"
            )

        case .disabled, .chronicallyIll:
            // Non-spouse EDB: non-recalculation method per Treas. Reg. §1.401(a)(9)-5(d)(3).
            // Initial factor taken at age in year after death, reduced by 1 each subsequent year.
            guard yearsElapsed >= 1 else {
                return InheritedRMDResult(annualRMD: 0, mustEmptyByYear: nil, yearsRemaining: nil,
                                          rule: "\(beneficiaryType.rawValue) — RMDs begin the year after inheritance")
            }
            let initialAge = (yearOfInheritance + 1) - beneficiaryBirthYear
            let initialFactor = singleLifeExpectancyFactor(for: initialAge)
            let yearsOfReduction = year - (yearOfInheritance + 1)
            let factor = max(1.0, initialFactor - Double(yearsOfReduction))
            let rmd = account.balance / factor
            let rothLabel = isRothInherited ? " (Roth)" : ""
            return InheritedRMDResult(
                annualRMD: rmd,
                mustEmptyByYear: nil,
                yearsRemaining: nil,
                rule: "\(beneficiaryType.rawValue) — lifetime stretch\(rothLabel) (factor \(String(format: "%.1f", factor)))"
            )

        case .notTenYearsYounger:
            // V2.0 SIMPLIFICATION: Beneficiary classification trusts user-declared input.
            // The engine does not validate the .notTenYearsYounger designation against
            // actual birth years of the beneficiary and decedent — a user who incorrectly
            // self-declares as a non-EDB (e.g., they ARE more than 10 years younger) would
            // receive the wrong RMD treatment (lifetime stretch instead of 10-year rule).
            // V2.1 task: validate against stored birth years and warn or auto-correct.
            guard yearsElapsed >= 1 else {
                return InheritedRMDResult(annualRMD: 0, mustEmptyByYear: nil, yearsRemaining: nil,
                                          rule: "Not >10 years younger — RMDs begin the year after inheritance")
            }
            let initialAge = (yearOfInheritance + 1) - beneficiaryBirthYear
            let initialFactor = singleLifeExpectancyFactor(for: initialAge)
            let yearsOfReduction = year - (yearOfInheritance + 1)
            let factor = max(1.0, initialFactor - Double(yearsOfReduction))
            let rmd = account.balance / factor
            return InheritedRMDResult(
                annualRMD: rmd,
                mustEmptyByYear: nil,
                yearsRemaining: nil,
                rule: "Not >10 years younger — lifetime stretch (factor \(String(format: "%.1f", factor)))"
            )

        case .minorChild:
            // Pre-SECURE minor child: lifetime stretch continues past majority (no 10-year shift).
            if isPreSECURE {
                guard yearsElapsed >= 1 else {
                    return InheritedRMDResult(annualRMD: 0, mustEmptyByYear: nil, yearsRemaining: nil,
                                              rule: "Pre-SECURE grandfathered stretch — RMDs begin the year after inheritance")
                }
                let initialAge = (yearOfInheritance + 1) - beneficiaryBirthYear
                let initialFactor = singleLifeExpectancyFactor(for: initialAge)
                let yearsOfReduction = year - (yearOfInheritance + 1)
                let factor = max(1.0, initialFactor - Double(yearsOfReduction))
                let rmd = account.balance / factor
                return InheritedRMDResult(
                    annualRMD: rmd,
                    mustEmptyByYear: nil,
                    yearsRemaining: nil,
                    rule: "Pre-SECURE grandfathered stretch (minor) — factor \(String(format: "%.1f", factor))"
                )
            }
            let majorityYear = account.minorChildMajorityYear ?? (beneficiaryBirthYear + 21)
            if year < majorityYear {
                // Non-spouse EDB: non-recalculation method per §1.401(a)(9)-5(d)(3).
                guard yearsElapsed >= 1 else {
                    return InheritedRMDResult(annualRMD: 0, mustEmptyByYear: nil, yearsRemaining: nil,
                                              rule: "Minor child — RMDs begin the year after inheritance")
                }
                let initialAge = (yearOfInheritance + 1) - beneficiaryBirthYear
                let initialFactor = singleLifeExpectancyFactor(for: initialAge)
                let yearsOfReduction = year - (yearOfInheritance + 1)
                let factor = max(1.0, initialFactor - Double(yearsOfReduction))
                let rmd = account.balance / factor
                let rothLabel = isRothInherited ? " (Roth)" : ""
                return InheritedRMDResult(
                    annualRMD: rmd,
                    mustEmptyByYear: nil,
                    yearsRemaining: nil,
                    rule: "Minor child — SLE stretch until age of majority\(rothLabel) (factor \(String(format: "%.1f", factor)))"
                )
            } else {
                let tenYearDeadline = majorityYear + 10
                let remaining = max(0, tenYearDeadline - year)
                if year >= tenYearDeadline {
                    return InheritedRMDResult(
                        annualRMD: account.balance,
                        mustEmptyByYear: tenYearDeadline,
                        yearsRemaining: 0,
                        rule: "Minor child (now adult) — 10-year deadline reached, full balance due"
                    )
                }
                // Post-majority 10-year window: if decedent died after RBD, annual RMDs continue
                // on the ORIGINAL year-after-death schedule (no reset at majority) per T.D. 10001
                // and Treas. Reg. §1.401(a)(9)-5(e)(2).
                if effectiveRBDStatus == .afterRBD {
                    let initialAge = (yearOfInheritance + 1) - beneficiaryBirthYear
                    let initialFactor = singleLifeExpectancyFactor(for: initialAge)
                    let yearsOfReduction = year - (yearOfInheritance + 1)
                    let factor = max(1.0, initialFactor - Double(max(0, yearsOfReduction)))
                    let rmd = account.balance / factor
                    return InheritedRMDResult(
                        annualRMD: rmd,
                        mustEmptyByYear: tenYearDeadline,
                        yearsRemaining: remaining,
                        rule: "Minor child (now adult) — annual RMDs + must empty by \(tenYearDeadline) (factor \(String(format: "%.1f", factor)))"
                    )
                } else {
                    let rothLabel = isRothInherited ? " (Roth)" : ""
                    return InheritedRMDResult(
                        annualRMD: 0,
                        mustEmptyByYear: tenYearDeadline,
                        yearsRemaining: remaining,
                        rule: "Minor child (now adult) — no annual RMDs, must empty by \(tenYearDeadline)\(rothLabel)"
                    )
                }
            }

        case .nonEligibleDesignated:
            // Pre-SECURE grandfathered: lifetime stretch, no 10-year cap.
            // After-RBD rule: divisor is the longer of beneficiary's or decedent's single life expectancy
            // (longer SLE = smaller RMD), reduced by 1 each year thereafter.
            if isPreSECURE {
                guard yearsElapsed >= 1 else {
                    return InheritedRMDResult(annualRMD: 0, mustEmptyByYear: nil, yearsRemaining: nil,
                                              rule: "Pre-SECURE grandfathered stretch — RMDs begin the year after inheritance")
                }
                let initialAge = (yearOfInheritance + 1) - beneficiaryBirthYear
                var initialFactor = singleLifeExpectancyFactor(for: initialAge)
                if effectiveRBDStatus == .afterRBD,
                   let decedentBirthYear = account.decedentBirthYear {
                    let decedentAgeAtDeath = yearOfInheritance - decedentBirthYear
                    let decedentFactor = singleLifeExpectancyFactor(for: decedentAgeAtDeath)
                    initialFactor = max(initialFactor, decedentFactor)
                }
                let yearsOfReduction = year - (yearOfInheritance + 1)
                let factor = max(1.0, initialFactor - Double(yearsOfReduction))
                let rmd = account.balance / factor
                let rothLabel = isRothInherited ? " (Roth)" : ""
                return InheritedRMDResult(
                    annualRMD: rmd,
                    mustEmptyByYear: nil,
                    yearsRemaining: nil,
                    rule: "Pre-SECURE grandfathered stretch\(rothLabel) — factor \(String(format: "%.1f", factor))"
                )
            }

            let remaining = max(0, deadline - year)

            if year >= deadline {
                return InheritedRMDResult(
                    annualRMD: account.balance,
                    mustEmptyByYear: deadline,
                    yearsRemaining: 0,
                    rule: "10-year deadline reached — full balance must be withdrawn"
                )
            }

            if effectiveRBDStatus == .beforeRBD {
                return InheritedRMDResult(
                    annualRMD: 0,
                    mustEmptyByYear: deadline,
                    yearsRemaining: remaining,
                    rule: "10-year rule (before RBD) — no annual RMDs, must empty by \(deadline)"
                )
            } else {
                guard yearsElapsed >= 1 else {
                    return InheritedRMDResult(annualRMD: 0, mustEmptyByYear: deadline, yearsRemaining: remaining,
                                              rule: "10-year rule (after RBD) — RMDs begin the year after inheritance")
                }
                let initialAge = (yearOfInheritance + 1) - beneficiaryBirthYear
                let initialFactor = singleLifeExpectancyFactor(for: initialAge)
                let yearsOfReduction = year - (yearOfInheritance + 1)
                let factor = max(1.0, initialFactor - Double(yearsOfReduction))
                let rmd = account.balance / factor
                return InheritedRMDResult(
                    annualRMD: rmd,
                    mustEmptyByYear: deadline,
                    yearsRemaining: remaining,
                    rule: "10-year rule (after RBD) — annual RMDs required, must empty by \(deadline) (factor \(String(format: "%.1f", factor)))"
                )
            }
        }
    }

    // MARK: - Inherited IRA Projection

    struct InheritedProjectionRow: Identifiable {
        var id: Int { year }
        let year: Int
        let balance: Double
        let rmd: Double
        let remaining: Int?   // years until must-empty deadline (nil = lifetime stretch)
        let isDeadline: Bool  // true if this row triggers the full must-empty withdrawal
    }

    /// Projects an inherited IRA forward, computing per-year RMD by delegating
    /// to `calculateInheritedIRARMD` with a running balance snapshot. Keeping the
    /// rule logic in a single place prevents projection from drifting out of sync
    /// with current-year RMD (e.g. pre-SECURE grandfathered stretch rules).
    static func projectInheritedIRA(
        account: IRAAccount,
        currentYear: Int,
        projectionYears: Int,
        growthPercent: Double
    ) -> [InheritedProjectionRow] {
        guard account.accountType.isInherited,
              let beneficiaryType = account.beneficiaryType,
              let yearOfInheritance = account.yearOfInheritance,
              let beneficiaryBirthYear = account.beneficiaryBirthYear else { return [] }

        let isPreSECURE = yearOfInheritance < 2020
        let growthRate = growthPercent / 100.0

        let deadlineYear: Int? = {
            switch beneficiaryType {
            case .spouse, .disabled, .chronicallyIll, .notTenYearsYounger:
                return nil
            case .minorChild:
                if isPreSECURE { return nil }
                let majorityYear = account.minorChildMajorityYear ?? (beneficiaryBirthYear + 21)
                return majorityYear + 10
            case .nonEligibleDesignated:
                if isPreSECURE { return nil }
                return yearOfInheritance + 10
            }
        }()

        let lastYear: Int
        if let deadline = deadlineYear {
            lastYear = max(deadline, currentYear)
        } else {
            lastYear = currentYear + projectionYears - 1
        }

        var balance = account.balance
        var rows: [InheritedProjectionRow] = []

        for year in currentYear...lastYear {
            guard balance > 0.01 else { break }
            let isDeadlineYear = (deadlineYear != nil && year >= deadlineYear!)

            var snapshot = account
            snapshot.balance = balance
            let result = calculateInheritedIRARMD(account: snapshot, forYear: year)
            let rmd = min(result.annualRMD, balance)

            let remaining: Int? = deadlineYear.map { max(0, $0 - year) }

            rows.append(InheritedProjectionRow(
                year: year,
                balance: balance,
                rmd: rmd,
                remaining: remaining,
                isDeadline: isDeadlineYear
            ))

            balance -= rmd
            balance *= (1 + growthRate)
            balance = max(0, balance)
        }

        return rows
    }
}
