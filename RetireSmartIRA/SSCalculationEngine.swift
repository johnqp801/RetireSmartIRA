//
//  SSCalculationEngine.swift
//  RetireSmartIRA
//
//  Pure calculation engine for Social Security benefits.
//  No SwiftUI or DataManager dependencies — all static methods with explicit inputs.
//

import Foundation

struct SSCalculationEngine {

    // MARK: - Full Retirement Age

    /// Returns FRA as (years, months) based on birth year
    static func fullRetirementAge(birthYear: Int) -> (years: Int, months: Int) {
        switch birthYear {
        case ...1937:
            return (65, 0)
        case 1938:
            return (65, 2)
        case 1939:
            return (65, 4)
        case 1940:
            return (65, 6)
        case 1941:
            return (65, 8)
        case 1942:
            return (65, 10)
        case 1943...1954:
            return (66, 0)
        case 1955:
            return (66, 2)
        case 1956:
            return (66, 4)
        case 1957:
            return (66, 6)
        case 1958:
            return (66, 8)
        case 1959:
            return (66, 10)
        default: // 1960+
            return (67, 0)
        }
    }

    /// FRA expressed in total months for easier arithmetic
    static func fraInMonths(birthYear: Int) -> Int {
        let fra = fullRetirementAge(birthYear: birthYear)
        return fra.years * 12 + fra.months
    }

    /// FRA as a displayable string like "66 and 2 months" or "67"
    static func fraDescription(birthYear: Int) -> String {
        let fra = fullRetirementAge(birthYear: birthYear)
        if fra.months == 0 {
            return "\(fra.years)"
        }
        return "\(fra.years) and \(fra.months) months"
    }

    // MARK: - Benefit Adjustments

    /// Calculate monthly benefit at any claiming age given PIA (benefit at FRA).
    ///
    /// - Parameters:
    ///   - claimingAge: Age in years to start benefits (62-70)
    ///   - claimingMonth: Additional months past the claiming age year (0-11)
    ///   - pia: Primary Insurance Amount (monthly benefit at FRA)
    ///   - fraYears: FRA years component
    ///   - fraMonths: FRA months component
    /// - Returns: Adjusted monthly benefit
    static func benefitAtAge(claimingAge: Int, claimingMonth: Int = 0,
                             pia: Double, fraYears: Int, fraMonths: Int) -> Double {
        let fraTotal = fraYears * 12 + fraMonths
        let claimTotal = claimingAge * 12 + claimingMonth

        if claimTotal == fraTotal {
            return pia
        } else if claimTotal < fraTotal {
            return applyEarlyReduction(pia: pia, monthsEarly: fraTotal - claimTotal)
        } else {
            return applyDelayedCredits(pia: pia, monthsDelayed: claimTotal - fraTotal)
        }
    }

    /// Reduce retirement benefit for claiming before FRA.
    /// First 36 months: 5/9 of 1% per month. Additional months: 5/12 of 1% per month.
    static func applyEarlyReduction(pia: Double, monthsEarly: Int) -> Double {
        let first36 = min(monthsEarly, 36)
        let beyond36 = max(monthsEarly - 36, 0)
        let reductionFactor = 1.0
            - (Double(first36) * 5.0 / 9.0 / 100.0)
            - (Double(beyond36) * 5.0 / 12.0 / 100.0)
        return pia * max(reductionFactor, 0)
    }

    /// Reduce spousal benefit for claiming before FRA.
    /// First 36 months: 25/36 of 1% per month. Additional months: 5/12 of 1% per month.
    /// SSA uses different reduction factors for spousal benefits vs. retirement benefits.
    static func applySpousalEarlyReduction(maxSpousal: Double, monthsEarly: Int) -> Double {
        let first36 = min(monthsEarly, 36)
        let beyond36 = max(monthsEarly - 36, 0)
        let reductionFactor = 1.0
            - (Double(first36) * 25.0 / 36.0 / 100.0)
            - (Double(beyond36) * 5.0 / 12.0 / 100.0)
        return maxSpousal * max(reductionFactor, 0)
    }

    /// Increase benefit for claiming after FRA.
    /// 2/3 of 1% per month (8% per year), max at age 70.
    static func applyDelayedCredits(pia: Double, monthsDelayed: Int) -> Double {
        let creditFactor = 1.0 + (Double(monthsDelayed) * 2.0 / 3.0 / 100.0)
        return pia * creditFactor
    }

    /// Calculate reduction percentage for claiming at a given age (for display)
    static func adjustmentPercentage(claimingAge: Int, claimingMonth: Int = 0,
                                     fraYears: Int, fraMonths: Int) -> Double {
        let fraTotal = fraYears * 12 + fraMonths
        let claimTotal = claimingAge * 12 + claimingMonth
        let diff = claimTotal - fraTotal

        if diff == 0 {
            return 0
        } else if diff < 0 {
            let monthsEarly = -diff
            let first36 = min(monthsEarly, 36)
            let beyond36 = max(monthsEarly - 36, 0)
            return -(Double(first36) * 5.0 / 9.0 / 100.0 + Double(beyond36) * 5.0 / 12.0 / 100.0) * 100.0
        } else {
            return (Double(diff) * 2.0 / 3.0 / 100.0) * 100.0
        }
    }

    // MARK: - Break-Even Analysis

    /// Generate claiming scenarios for ages 62 through 70, computing cumulative benefits.
    ///
    /// - Parameters:
    ///   - pia: Monthly benefit at FRA
    ///   - birthYear: For FRA calculation
    ///   - lifeExpectancy: Age to project through
    ///   - colaRate: Annual COLA as percentage (e.g. 2.5 for 2.5%)
    /// - Returns: Array of scenarios for each claiming age
    static func claimingScenarios(pia: Double, birthYear: Int, lifeExpectancy: Int,
                                  colaRate: Double = 2.5) -> [SSClaimingScenario] {
        let fra = fullRetirementAge(birthYear: birthYear)
        var scenarios: [SSClaimingScenario] = []

        for claimAge in 62...70 {
            let monthly = benefitAtAge(claimingAge: claimAge, pia: pia,
                                       fraYears: fra.years, fraMonths: fra.months)
            let annual = monthly * 12
            let label = claimAge == fra.years && fra.months == 0
                ? "Claim at \(claimAge) (FRA)"
                : "Claim at \(claimAge)"

            var cumulative: [(age: Int, cumulative: Double)] = []
            var runningTotal = 0.0
            for age in 62...max(lifeExpectancy, 95) {
                if age >= claimAge {
                    let yearsReceiving = age - claimAge
                    let colaMultiplier = pow(1.0 + colaRate / 100.0, Double(yearsReceiving))
                    runningTotal += annual * colaMultiplier
                }
                cumulative.append((age: age, cumulative: runningTotal))
            }

            scenarios.append(SSClaimingScenario(
                claimingAge: claimAge,
                claimingMonth: 0,
                monthlyBenefit: monthly,
                annualBenefit: annual,
                cumulativeByAge: cumulative,
                breakEvenVs: [],
                label: label
            ))
        }

        // Calculate break-even ages between each pair of scenarios
        for i in 0..<scenarios.count {
            var breakEvens: [(vsAge: Int, breakEvenAge: Int?)] = []
            for j in 0..<scenarios.count where i != j {
                let be = findBreakEvenAge(
                    early: scenarios[i].cumulativeByAge,
                    later: scenarios[j].cumulativeByAge
                )
                breakEvens.append((vsAge: scenarios[j].claimingAge, breakEvenAge: be))
            }
            scenarios[i].breakEvenVs = breakEvens
        }

        return scenarios
    }

    /// Find the age where the later-claiming scenario's cumulative benefits surpass the earlier one.
    private static func findBreakEvenAge(early: [(age: Int, cumulative: Double)],
                                         later: [(age: Int, cumulative: Double)]) -> Int? {
        // Find first age where the later scenario passes the early scenario
        for i in 0..<min(early.count, later.count) {
            let earlyVal = early[i].cumulative
            let laterVal = later[i].cumulative

            // Later scenario must have started receiving benefits and surpassed early
            if laterVal > 0 && earlyVal > 0 && laterVal >= earlyVal {
                return early[i].age
            }
        }
        return nil
    }

    /// Generate chart data points for cumulative benefit curves
    static func cumulativeChartData(scenarios: [SSClaimingScenario],
                                    maxAge: Int = 95) -> [SSCumulativeChartPoint] {
        var points: [SSCumulativeChartPoint] = []
        for scenario in scenarios {
            for entry in scenario.cumulativeByAge where entry.age <= maxAge {
                points.append(SSCumulativeChartPoint(
                    age: entry.age,
                    cumulativeAmount: entry.cumulative,
                    scenarioLabel: scenario.label
                ))
            }
        }
        return points
    }

    /// Generate break-even comparisons for the key claiming age pairs
    static func breakEvenComparisons(scenarios: [SSClaimingScenario],
                                     lifeExpectancy: Int,
                                     fraAge: Int = 67) -> [SSBreakEvenComparison] {
        // Compare the common pairs: 62 vs FRA, 62 vs 70, FRA vs 70
        let pairs: [(Int, Int)] = [(62, fraAge), (62, 70), (fraAge, 70)]
        var results: [SSBreakEvenComparison] = []

        for (earlyAge, laterAge) in pairs {
            guard let early = scenarios.first(where: { $0.claimingAge == earlyAge }),
                  let later = scenarios.first(where: { $0.claimingAge == laterAge }) else { continue }

            let breakEven = findBreakEvenAge(
                early: early.cumulativeByAge,
                later: later.cumulativeByAge
            )

            // Calculate advantage at life expectancy
            let earlyAtLE = early.cumulativeByAge.first(where: { $0.age == lifeExpectancy })?.cumulative ?? 0
            let laterAtLE = later.cumulativeByAge.first(where: { $0.age == lifeExpectancy })?.cumulative ?? 0

            results.append(SSBreakEvenComparison(
                earlyAge: earlyAge,
                laterAge: laterAge,
                breakEvenAge: breakEven,
                earlyMonthly: early.monthlyBenefit,
                laterMonthly: later.monthlyBenefit,
                advantageAtLifeExpectancy: laterAtLE - earlyAtLE
            ))
        }

        return results
    }

    // MARK: - Benefit from SSA Statement Estimates

    /// Derive PIA from SSA statement's three estimates.
    /// The benefit at FRA IS the PIA.
    static func piaFromEstimates(benefitAtFRA: Double) -> Double {
        return benefitAtFRA
    }

    /// Calculate monthly benefit at any age using the 3 SSA estimates for validation.
    /// Uses the FRA estimate as PIA and applies standard adjustments.
    static func benefitFromEstimates(at claimingAge: Int, claimingMonth: Int = 0,
                                     benefitAt62: Double, benefitAtFRA: Double, benefitAt70: Double,
                                     birthYear: Int) -> Double {
        let fra = fullRetirementAge(birthYear: birthYear)
        return benefitAtAge(claimingAge: claimingAge, claimingMonth: claimingMonth,
                            pia: benefitAtFRA, fraYears: fra.years, fraMonths: fra.months)
    }

    // MARK: - Spousal Benefits (Phase 2)

    /// Maximum spousal benefit = 50% of worker's PIA at FRA
    static func maxSpousalBenefit(workerPIA: Double) -> Double {
        return workerPIA * 0.5
    }

    /// Spousal benefit under deemed filing (post-2015 Bipartisan Budget Act).
    /// Actual calculation: own-reduced-retirement + excess-spousal-reduced (if positive).
    /// Both components are reduced independently if claiming before FRA.
    static func spousalBenefit(workerPIA: Double, spouseOwnPIA: Double,
                               spouseClaimingAge: Int, spouseClaimingMonth: Int = 0,
                               spouseBirthYear: Int) -> Double {
        let spouseFRA = fullRetirementAge(birthYear: spouseBirthYear)
        let fraMonths = spouseFRA.years * 12 + spouseFRA.months
        let claimMonths = spouseClaimingAge * 12 + spouseClaimingMonth

        // Step 1: Own retirement benefit (with early reduction or DRCs)
        let ownBenefit = benefitAtAge(claimingAge: spouseClaimingAge, claimingMonth: spouseClaimingMonth,
                                      pia: spouseOwnPIA, fraYears: spouseFRA.years, fraMonths: spouseFRA.months)

        // Step 2: Max spousal benefit = 50% of worker's PIA
        let maxSpousal = maxSpousalBenefit(workerPIA: workerPIA)

        // Step 3: Excess spousal = max spousal - spouse's own PIA (unreduced)
        // If negative, no spousal top-up applies
        let excessSpousal = maxSpousal - spouseOwnPIA
        guard excessSpousal > 0 else {
            return ownBenefit  // Own PIA exceeds 50% of worker's PIA — no spousal top-up
        }

        // Step 4: Reduce the excess spousal if claiming before FRA
        let reducedExcess: Double
        if claimMonths >= fraMonths {
            reducedExcess = excessSpousal  // Full excess at or after FRA
        } else {
            let monthsEarly = fraMonths - claimMonths
            // The excess portion is reduced using spousal reduction factors
            reducedExcess = applySpousalEarlyReduction(maxSpousal: excessSpousal, monthsEarly: monthsEarly)
        }

        // Step 5: Total deemed filing benefit = own reduced retirement + reduced excess spousal
        return ownBenefit + reducedExcess
    }

    // MARK: - Effective Monthly Benefit (Spousal-Aware, Age-Aware)

    /// Result of computing the effective monthly benefit for one person in a couple.
    struct EffectiveBenefitResult {
        var monthly: Double             // The effective monthly benefit for the given year
        var isCollecting: Bool          // Whether this person is receiving benefits in the given year
        var ownMonthly: Double          // Own-record portion (without spousal top-up)
        var spousalTopUp: Double        // Spousal top-up portion (0 if not applicable)
        var includesSpousalTopUp: Bool  // Whether the spousal top-up is active
    }

    /// Compute the correct monthly SS benefit for one person in a couple for a specific year,
    /// considering: their claiming age, the other spouse's claiming status, and spousal top-up eligibility.
    ///
    /// For "already claiming" users, we assume `currentBenefit` already includes any spousal top-up
    /// that SSA is paying (since SSA pays one combined check).
    ///
    /// For "not yet claiming" users, we compute own-record benefit + spousal top-up (if the other
    /// spouse has also filed by the given year).
    ///
    /// - Parameters:
    ///   - personPIA: This person's Primary Insurance Amount (benefit at FRA)
    ///   - personBirthYear: This person's birth year
    ///   - personClaimingAge: Age this person plans to claim (or claimed)
    ///   - personClaimingMonth: Month within claiming year (0-11)
    ///   - personIsAlreadyClaiming: Whether this person is already receiving benefits
    ///   - personCurrentBenefit: Monthly amount if already claiming (assumed to include any spousal top-up)
    ///   - spousePIA: The other spouse's PIA (needed for spousal top-up calculation)
    ///   - spouseBirthYear: The other spouse's birth year
    ///   - spouseClaimingAge: Age the other spouse plans to claim (or claimed)
    ///   - spouseIsAlreadyClaiming: Whether the other spouse is already receiving benefits
    ///   - forYear: The calendar year to compute benefits for
    static func effectiveMonthlyBenefit(
        personPIA: Double, personBirthYear: Int,
        personClaimingAge: Int, personClaimingMonth: Int = 0,
        personIsAlreadyClaiming: Bool, personCurrentBenefit: Double = 0,
        spousePIA: Double, spouseBirthYear: Int,
        spouseClaimingAge: Int, spouseIsAlreadyClaiming: Bool,
        forYear: Int
    ) -> EffectiveBenefitResult {
        // Person's age in the given year
        let personAge = forYear - personBirthYear

        // Already claiming: SSA pays a single check that includes any spousal top-up.
        // Use the entered amount as-is.
        if personIsAlreadyClaiming {
            return EffectiveBenefitResult(
                monthly: personCurrentBenefit,
                isCollecting: true,
                ownMonthly: personCurrentBenefit,
                spousalTopUp: 0,
                includesSpousalTopUp: false  // We can't decompose what SSA is paying
            )
        }

        // Not yet claiming: check if person has reached claiming age
        guard personAge >= personClaimingAge else {
            return EffectiveBenefitResult(
                monthly: 0, isCollecting: false,
                ownMonthly: 0, spousalTopUp: 0, includesSpousalTopUp: false
            )
        }

        // Compute own-record benefit at claiming age
        let personFRA = fullRetirementAge(birthYear: personBirthYear)
        let ownBenefit = benefitAtAge(
            claimingAge: personClaimingAge, claimingMonth: personClaimingMonth,
            pia: personPIA, fraYears: personFRA.years, fraMonths: personFRA.months
        )

        // Check if the other spouse has filed (needed for spousal top-up)
        let spouseAge = forYear - spouseBirthYear
        let spouseHasFiled = spouseIsAlreadyClaiming || spouseAge >= spouseClaimingAge

        guard spouseHasFiled else {
            // Other spouse hasn't filed yet — no spousal top-up available
            return EffectiveBenefitResult(
                monthly: ownBenefit, isCollecting: true,
                ownMonthly: ownBenefit, spousalTopUp: 0, includesSpousalTopUp: false
            )
        }

        // Other spouse has filed — check for spousal top-up
        let withSpousal = spousalBenefit(
            workerPIA: spousePIA, spouseOwnPIA: personPIA,
            spouseClaimingAge: personClaimingAge, spouseClaimingMonth: personClaimingMonth,
            spouseBirthYear: personBirthYear
        )

        let topUp = max(0, withSpousal - ownBenefit)
        let effective = ownBenefit + topUp

        return EffectiveBenefitResult(
            monthly: effective, isCollecting: true,
            ownMonthly: ownBenefit, spousalTopUp: topUp,
            includesSpousalTopUp: topUp > 0
        )
    }

    /// Simplified version for single filers (no spouse) — just own-record, age-gated.
    static func effectiveMonthlyBenefitSingle(
        personPIA: Double, personBirthYear: Int,
        personClaimingAge: Int, personClaimingMonth: Int = 0,
        personIsAlreadyClaiming: Bool, personCurrentBenefit: Double = 0,
        forYear: Int
    ) -> EffectiveBenefitResult {
        let personAge = forYear - personBirthYear

        if personIsAlreadyClaiming {
            return EffectiveBenefitResult(
                monthly: personCurrentBenefit, isCollecting: true,
                ownMonthly: personCurrentBenefit, spousalTopUp: 0, includesSpousalTopUp: false
            )
        }

        guard personAge >= personClaimingAge else {
            return EffectiveBenefitResult(
                monthly: 0, isCollecting: false,
                ownMonthly: 0, spousalTopUp: 0, includesSpousalTopUp: false
            )
        }

        let fra = fullRetirementAge(birthYear: personBirthYear)
        let ownBenefit = benefitAtAge(
            claimingAge: personClaimingAge, claimingMonth: personClaimingMonth,
            pia: personPIA, fraYears: fra.years, fraMonths: fra.months
        )

        return EffectiveBenefitResult(
            monthly: ownBenefit, isCollecting: true,
            ownMonthly: ownBenefit, spousalTopUp: 0, includesSpousalTopUp: false
        )
    }

    // MARK: - Survivor Benefits (Phase 2)

    /// Survivor benefit considering age reduction and RIB-LIM.
    /// - survivorOwnBenefit: Survivor's own retirement benefit (already adjusted for their claiming age)
    /// - deceasedActualBenefit: Deceased's actual monthly benefit at time of death
    /// - deceasedPIA: Deceased's PIA (needed for RIB-LIM calculation)
    /// - survivorAge: Survivor's age when claiming survivor benefit (default: FRA = no reduction)
    /// - survivorFRAYears: Survivor's FRA years (for survivor benefit reduction)
    static func survivorBenefit(survivorOwnBenefit: Double, deceasedActualBenefit: Double,
                                deceasedPIA: Double? = nil,
                                survivorAge: Int? = nil, survivorFRAYears: Int? = nil) -> Double {
        // Calculate the survivor benefit from the deceased's record
        var deceasedSurvivorAmount = deceasedActualBenefit

        // Apply RIB-LIM: if deceased claimed early, survivor gets the higher of:
        //   (a) deceased's actual reduced benefit, or
        //   (b) 82.5% of deceased's PIA
        if let pia = deceasedPIA, deceasedActualBenefit < pia {
            let ribLimFloor = pia * 0.825
            deceasedSurvivorAmount = max(deceasedActualBenefit, ribLimFloor)
        }

        // Apply survivor age reduction if claiming before survivor FRA
        if let sAge = survivorAge, let fraYrs = survivorFRAYears, sAge < fraYrs {
            // Survivor benefit reduction: roughly linear from 71.5% at 60 to 100% at FRA
            // SSA uses months, but for this planning tool we approximate with years
            let survivorFRAMonths = fraYrs * 12
            let survivorClaimMonths = sAge * 12
            let monthsEarly = survivorFRAMonths - survivorClaimMonths
            // Maximum reduction at 60 is 28.5% (71.5% of full)
            // Reduction per month = 28.5% / 84 months (from 60 to 67) ≈ 0.339% per month
            let maxReductionMonths = (fraYrs - 60) * 12
            let reductionPerMonth = 0.285 / Double(maxReductionMonths)
            let reductionFactor = 1.0 - Double(min(monthsEarly, maxReductionMonths)) * reductionPerMonth
            deceasedSurvivorAmount *= max(reductionFactor, 0.715)
        }

        return max(survivorOwnBenefit, deceasedSurvivorAmount)
    }

    // MARK: - Couples Strategy Matrix

    /// Build a matrix of combined lifetime benefits for every feasible combination of
    /// primary and spouse claiming ages. Claiming ages earlier than the user's current
    /// age are excluded because those strategies are no longer actionable — you can't
    /// decide to claim in the past. When current ages aren't supplied (tests), the full
    /// 62–70 range is used.
    static func couplesMatrix(
        primaryPIA: Double, primaryBirthYear: Int, primaryLifeExpectancy: Int,
        spousePIA: Double, spouseBirthYear: Int, spouseLifeExpectancy: Int,
        colaRate: Double = 2.5, discountRate: Double = 0,
        primaryCurrentAge: Int = 62, spouseCurrentAge: Int = 62
    ) -> [SSCouplesMatrixCell] {
        let primaryFRA = fullRetirementAge(birthYear: primaryBirthYear)
        let spouseFRA = fullRetirementAge(birthYear: spouseBirthYear)

        let primaryMinAge = max(62, min(70, primaryCurrentAge))
        let spouseMinAge = max(62, min(70, spouseCurrentAge))

        var cells: [SSCouplesMatrixCell] = []
        var bestLifetime = -Double.infinity
        var bestPrimaryAge = max(67, primaryMinAge)
        var bestSpouseAge = max(67, spouseMinAge)

        // First pass: compute all cells
        for pAge in primaryMinAge...70 {
            let pOwnMonthly = benefitAtAge(claimingAge: pAge, pia: primaryPIA,
                                            fraYears: primaryFRA.years, fraMonths: primaryFRA.months)
            for sAge in spouseMinAge...70 {
                let sOwnMonthly = benefitAtAge(claimingAge: sAge, pia: spousePIA,
                                                fraYears: spouseFRA.years, fraMonths: spouseFRA.months)

                // Spousal top-up (deemed filing): each spouse may get a boost from the other's record
                // Spouse gets spousal top-up from primary's PIA
                let sWithSpousal = spousalBenefit(workerPIA: primaryPIA, spouseOwnPIA: spousePIA,
                                                   spouseClaimingAge: sAge, spouseBirthYear: spouseBirthYear)
                // Primary gets spousal top-up from spouse's PIA
                let pWithSpousal = spousalBenefit(workerPIA: spousePIA, spouseOwnPIA: primaryPIA,
                                                   spouseClaimingAge: pAge, spouseBirthYear: primaryBirthYear)

                // Effective monthly: higher of own or own+spousal top-up
                let pMonthly = max(pOwnMonthly, pWithSpousal)
                let sMonthly = max(sOwnMonthly, sWithSpousal)

                // Survivor benefits with RIB-LIM
                let survivorIfPrimaryDies = survivorBenefit(
                    survivorOwnBenefit: sMonthly, deceasedActualBenefit: pMonthly,
                    deceasedPIA: primaryPIA)
                let survivorIfSpouseDies = survivorBenefit(
                    survivorOwnBenefit: pMonthly, deceasedActualBenefit: sMonthly,
                    deceasedPIA: spousePIA)

                // Combined lifetime: both-alive phase + survivor phase for each death order
                // Pass own-only amounts so gap years before the other spouse files
                // use the correct (non-spousal-topped-up) benefit.
                let combined = couplesLifetimeBenefit(
                    primaryMonthly: pMonthly, primaryClaimAge: pAge, primaryLifeExp: primaryLifeExpectancy,
                    spouseMonthly: sMonthly, spouseClaimAge: sAge, spouseLifeExp: spouseLifeExpectancy,
                    primaryOwnMonthly: pOwnMonthly, spouseOwnMonthly: sOwnMonthly,
                    survivorIfPrimaryDies: survivorIfPrimaryDies,
                    survivorIfSpouseDies: survivorIfSpouseDies,
                    colaRate: colaRate, discountRate: discountRate
                )

                cells.append(SSCouplesMatrixCell(
                    primaryClaimingAge: pAge,
                    spouseClaimingAge: sAge,
                    primaryMonthly: pMonthly,
                    spouseMonthly: sMonthly,
                    primaryOwnMonthly: pOwnMonthly,
                    spouseOwnMonthly: sOwnMonthly,
                    combinedLifetimeBenefit: combined,
                    survivorBenefitIfPrimaryDies: survivorIfPrimaryDies,
                    survivorBenefitIfSpouseDies: survivorIfSpouseDies,
                    isHighestLifetime: false
                ))

                if combined > bestLifetime {
                    bestLifetime = combined
                    bestPrimaryAge = pAge
                    bestSpouseAge = sAge
                }
            }
        }

        // Mark the highest-lifetime cell
        for i in cells.indices {
            if cells[i].primaryClaimingAge == bestPrimaryAge &&
               cells[i].spouseClaimingAge == bestSpouseAge {
                cells[i].isHighestLifetime = true
            }
        }

        return cells
    }

    /// Compute household lifetime benefit across both-alive and survivor phases.
    /// Weights both death orderings by 50/50 for a balanced estimate.
    /// When discountRate > 0, applies present-value discounting relative to age 62.
    /// Uses pre-computed survivor benefits (with RIB-LIM) rather than simple max.
    ///
    /// `primaryOwnMonthly` / `spouseOwnMonthly`: benefit based on own record only (no spousal top-up).
    /// Used during gap years before the other spouse has filed — spousal top-up is only
    /// available once the worker whose record provides the top-up has actually claimed.
    static func couplesLifetimeBenefit(
        primaryMonthly: Double, primaryClaimAge: Int, primaryLifeExp: Int,
        spouseMonthly: Double, spouseClaimAge: Int, spouseLifeExp: Int,
        primaryOwnMonthly: Double? = nil, spouseOwnMonthly: Double? = nil,
        survivorIfPrimaryDies: Double? = nil, survivorIfSpouseDies: Double? = nil,
        colaRate: Double, discountRate: Double = 0
    ) -> Double {
        let cola = 1.0 + colaRate / 100.0
        let discount = 1.0 + discountRate / 100.0
        let baseAge = 62  // PV reference point

        // Own-only benefits for gap years (fall back to full monthly if not provided)
        let pOwn = primaryOwnMonthly ?? primaryMonthly
        let sOwn = spouseOwnMonthly ?? spouseMonthly

        // Survivor benefits: use pre-computed (with RIB-LIM) or fall back to simple max
        let survIfPDies = survivorIfPrimaryDies ?? max(spouseMonthly, primaryMonthly)
        let survIfSDies = survivorIfSpouseDies ?? max(primaryMonthly, spouseMonthly)

        // Phase 1: Both alive — from earliest claim to min(life expectancies)
        let startAge = max(primaryClaimAge, spouseClaimAge)
        let bothAliveEnd = min(primaryLifeExp, spouseLifeExp)

        var total = 0.0

        // Pre-claim gap years: only the earlier claimer receives benefits.
        // Spousal top-up is NOT available until the other spouse has filed,
        // so use own-only benefit amounts during the gap.
        let earlierClaimAge = min(primaryClaimAge, spouseClaimAge)
        for age in earlierClaimAge..<startAge {
            let pvFactor = discountRate > 0 ? pow(discount, Double(-(age - baseAge))) : 1.0
            if primaryClaimAge <= age {
                let pYears = age - primaryClaimAge
                total += pOwn * 12 * pow(cola, Double(pYears)) * pvFactor
            }
            if spouseClaimAge <= age {
                let sYears = age - spouseClaimAge
                total += sOwn * 12 * pow(cola, Double(sYears)) * pvFactor
            }
        }

        // Both-alive years — both have filed, so spousal top-up is now active
        for age in startAge...bothAliveEnd {
            let pYears = age - primaryClaimAge
            let sYears = age - spouseClaimAge
            let pvFactor = discountRate > 0 ? pow(discount, Double(-(age - baseAge))) : 1.0
            total += primaryMonthly * 12 * pow(cola, Double(pYears)) * pvFactor
            total += spouseMonthly * 12 * pow(cola, Double(sYears)) * pvFactor
        }

        // Phase 2: Survivor phase — weight both orderings equally

        // Scenario A: Primary dies at their LE, spouse survives to their LE
        var scenarioA = 0.0
        if spouseLifeExp > primaryLifeExp {
            for age in (primaryLifeExp + 1)...spouseLifeExp {
                let sYears = age - spouseClaimAge
                let pvFactor = discountRate > 0 ? pow(discount, Double(-(age - baseAge))) : 1.0
                scenarioA += survIfPDies * 12 * pow(cola, Double(sYears)) * pvFactor
            }
        }

        // Scenario B: Spouse dies at their LE, primary survives to their LE
        var scenarioB = 0.0
        if primaryLifeExp > spouseLifeExp {
            for age in (spouseLifeExp + 1)...primaryLifeExp {
                let pYears = age - primaryClaimAge
                let pvFactor = discountRate > 0 ? pow(discount, Double(-(age - baseAge))) : 1.0
                scenarioB += survIfSDies * 12 * pow(cola, Double(pYears)) * pvFactor
            }
        }

        // Average the two death-order scenarios for the survivor phase
        total += (scenarioA + scenarioB) / 2.0

        return total
    }

    /// Identify the couples strategy with the highest potential lifetime benefit
    static func couplesTopStrategy(
        matrix: [SSCouplesMatrixCell],
        primaryPIA: Double, spousePIA: Double
    ) -> SSCouplesTopStrategy? {
        guard let best = matrix.first(where: { $0.isHighestLifetime }) else { return nil }

        var rationale: String
        let higherAge = primaryPIA >= spousePIA ? best.primaryClaimingAge : best.spouseClaimingAge
        let lowerAge = primaryPIA >= spousePIA ? best.spouseClaimingAge : best.primaryClaimingAge

        if higherAge == 70 {
            rationale = "The higher earner delays to 70 to maximize the survivor benefit — protecting the surviving spouse with the largest possible monthly check."
        } else if higherAge > lowerAge {
            rationale = "The higher earner delays longer to boost survivor benefits, while the lower earner claims earlier to provide household income during the waiting period."
        } else if higherAge == lowerAge {
            rationale = "Both spouses claim at the same age, balancing total household income with survivor protection."
        } else {
            rationale = "This combination maximizes total household lifetime benefits given your life expectancy assumptions."
        }

        return SSCouplesTopStrategy(
            primaryClaimingAge: best.primaryClaimingAge,
            spouseClaimingAge: best.spouseClaimingAge,
            combinedLifetime: best.combinedLifetimeBenefit,
            rationale: rationale,
            monthlyWhileBothAlive: best.primaryMonthly + best.spouseMonthly,
            primaryMonthly: best.primaryMonthly,
            spouseMonthly: best.spouseMonthly,
            primaryOwnMonthly: best.primaryOwnMonthly,
            spouseOwnMonthly: best.spouseOwnMonthly
        )
    }

    // MARK: - Survivor Analysis

    /// Generate survivor scenarios showing income impact when each spouse dies.
    /// Supports both planned-claiming and already-claiming paths.
    static func survivorScenarios(
        primaryBenefit: SSBenefitEstimate, primaryBirthYear: Int,
        spouseBenefit: SSBenefitEstimate, spouseBirthYear: Int
    ) -> [SSSurvivorScenario] {
        // Resolve each person's monthly benefit
        let pMonthly: Double
        let pPIA: Double
        if primaryBenefit.isAlreadyClaiming {
            pMonthly = primaryBenefit.currentBenefit
            // For already-claiming, use currentBenefit as best PIA proxy
            pPIA = primaryBenefit.benefitAtFRA > 0 ? primaryBenefit.benefitAtFRA : primaryBenefit.currentBenefit
        } else {
            let primaryFRA = fullRetirementAge(birthYear: primaryBirthYear)
            pMonthly = benefitAtAge(
                claimingAge: primaryBenefit.plannedClaimingAge,
                claimingMonth: primaryBenefit.plannedClaimingMonth,
                pia: primaryBenefit.benefitAtFRA,
                fraYears: primaryFRA.years, fraMonths: primaryFRA.months
            )
            pPIA = primaryBenefit.benefitAtFRA
        }

        let sMonthly: Double
        let sPIA: Double
        if spouseBenefit.isAlreadyClaiming {
            sMonthly = spouseBenefit.currentBenefit
            sPIA = spouseBenefit.benefitAtFRA > 0 ? spouseBenefit.benefitAtFRA : spouseBenefit.currentBenefit
        } else {
            let spouseFRA = fullRetirementAge(birthYear: spouseBirthYear)
            sMonthly = benefitAtAge(
                claimingAge: spouseBenefit.plannedClaimingAge,
                claimingMonth: spouseBenefit.plannedClaimingMonth,
                pia: spouseBenefit.benefitAtFRA,
                fraYears: spouseFRA.years, fraMonths: spouseFRA.months
            )
            sPIA = spouseBenefit.benefitAtFRA
        }

        let combined = pMonthly + sMonthly
        var scenarios: [SSSurvivorScenario] = []

        // If primary dies first: spouse gets survivor benefit (with RIB-LIM)
        let spouseSurvivor = survivorBenefit(
            survivorOwnBenefit: sMonthly, deceasedActualBenefit: pMonthly,
            deceasedPIA: pPIA)
        let spouseSource = spouseSurvivor > sMonthly ? "Survivor benefit (from primary)" : "Own benefit"
        let spouseReduction = combined - spouseSurvivor
        scenarios.append(SSSurvivorScenario(
            title: "If primary dies first",
            deceasedOwner: .primary,
            householdMonthlyBefore: combined,
            householdMonthlyAfter: spouseSurvivor,
            monthlyReduction: spouseReduction,
            percentReduction: combined > 0 ? (spouseReduction / combined) * 100 : 0,
            survivorBenefitSource: spouseSource,
            filingStatusChange: "Married Filing Jointly \u{2192} Single"
        ))

        // If spouse dies first: primary gets survivor benefit (with RIB-LIM)
        let primarySurvivor = survivorBenefit(
            survivorOwnBenefit: pMonthly, deceasedActualBenefit: sMonthly,
            deceasedPIA: sPIA)
        let primarySource = primarySurvivor > pMonthly ? "Survivor benefit (from spouse)" : "Own benefit"
        let primaryReduction = combined - primarySurvivor
        scenarios.append(SSSurvivorScenario(
            title: "If spouse dies first",
            deceasedOwner: .spouse,
            householdMonthlyBefore: combined,
            householdMonthlyAfter: primarySurvivor,
            monthlyReduction: primaryReduction,
            percentReduction: combined > 0 ? (primaryReduction / combined) * 100 : 0,
            survivorBenefitSource: primarySource,
            filingStatusChange: "Married Filing Jointly \u{2192} Single"
        ))

        return scenarios
    }

    // MARK: - AWI Table (National Average Wage Index, 1951-2023)

    static let awiTable: [Int: Double] = [
        1951: 2799.16, 1952: 2973.32, 1953: 3139.44, 1954: 3155.64, 1955: 3301.44,
        1956: 3532.36, 1957: 3641.72, 1958: 3673.80, 1959: 3855.80, 1960: 4007.12,
        1961: 4086.76, 1962: 4291.40, 1963: 4396.64, 1964: 4576.32, 1965: 4658.72,
        1966: 4938.36, 1967: 5213.44, 1968: 5571.76, 1969: 5893.76, 1970: 6186.24,
        1971: 6497.08, 1972: 7133.80, 1973: 7580.16, 1974: 8030.76, 1975: 8630.92,
        1976: 9226.48, 1977: 9779.44, 1978: 10556.03, 1979: 11479.46, 1980: 12513.46,
        1981: 13773.10, 1982: 14531.34, 1983: 15239.24, 1984: 16135.07, 1985: 16822.51,
        1986: 17321.82, 1987: 18426.51, 1988: 19334.04, 1989: 20099.55, 1990: 21027.98,
        1991: 21811.60, 1992: 22935.42, 1993: 23132.67, 1994: 23753.53, 1995: 24705.66,
        1996: 25913.90, 1997: 27426.00, 1998: 28861.44, 1999: 30469.84, 2000: 32154.82,
        2001: 32921.92, 2002: 33252.09, 2003: 34064.95, 2004: 35648.55, 2005: 36952.94,
        2006: 38651.41, 2007: 40405.48, 2008: 41334.97, 2009: 40711.61, 2010: 41673.83,
        2011: 42979.61, 2012: 44321.67, 2013: 44888.16, 2014: 46481.52, 2015: 48098.63,
        2016: 48642.15, 2017: 50321.89, 2018: 52145.80, 2019: 54099.99, 2020: 55628.60,
        2021: 60575.07, 2022: 63795.13, 2023: 66621.80,
    ]

    // MARK: - SS Taxable Maximum Table (1951-2026)

    static let taxableMaxTable: [Int: Double] = [
        1951: 3600, 1952: 3600, 1953: 3600, 1954: 3600,
        1955: 4200, 1956: 4200, 1957: 4200, 1958: 4200,
        1959: 4800, 1960: 4800, 1961: 4800, 1962: 4800, 1963: 4800, 1964: 4800, 1965: 4800,
        1966: 6600, 1967: 6600,
        1968: 7800, 1969: 7800, 1970: 7800, 1971: 7800,
        1972: 9000, 1973: 10800, 1974: 13200, 1975: 14100,
        1976: 15300, 1977: 16500, 1978: 17700, 1979: 22900,
        1980: 25900, 1981: 29700, 1982: 32400, 1983: 35700,
        1984: 37800, 1985: 39600, 1986: 42000, 1987: 43800,
        1988: 45000, 1989: 48000, 1990: 51300, 1991: 53400,
        1992: 55500, 1993: 57600, 1994: 60600, 1995: 61200,
        1996: 62700, 1997: 65400, 1998: 68400, 1999: 72600,
        2000: 76200, 2001: 80400, 2002: 84900, 2003: 87000,
        2004: 87900, 2005: 90000, 2006: 94200, 2007: 97500,
        2008: 102000, 2009: 106800, 2010: 106800, 2011: 106800,
        2012: 110100, 2013: 113700, 2014: 117000, 2015: 118500,
        2016: 118500, 2017: 127200, 2018: 128400, 2019: 132900,
        2020: 137700, 2021: 142800, 2022: 147000, 2023: 160200,
        2024: 168600, 2025: 176100, 2026: 184500,
    ]

    // MARK: - PIA Bend Points (by year first eligible / turning 62)

    /// Returns PIA bend points for the year the worker turns 62.
    /// Bend points are published by SSA and differ each year.
    static func piaBendPoints(yearTurning62: Int) -> (bp1: Double, bp2: Double) {
        switch yearTurning62 {
        case ...1978: return (180, 1085)
        case 1979:    return (180, 1085)
        case 1980:    return (194, 1171)
        case 1981:    return (211, 1274)
        case 1982:    return (230, 1388)
        case 1983:    return (254, 1528)
        case 1984:    return (267, 1612)
        case 1985:    return (280, 1691)
        case 1986:    return (297, 1790)
        case 1987:    return (310, 1866)
        case 1988:    return (319, 1922)
        case 1989:    return (339, 2044)
        case 1990:    return (356, 2145)
        case 1991:    return (370, 2230)
        case 1992:    return (387, 2333)
        case 1993:    return (401, 2420)
        case 1994:    return (422, 2545)
        case 1995:    return (426, 2567)
        case 1996:    return (437, 2635)
        case 1997:    return (455, 2741)
        case 1998:    return (477, 2875)
        case 1999:    return (505, 3043)
        case 2000:    return (531, 3202)
        case 2001:    return (561, 3381)
        case 2002:    return (592, 3567)
        case 2003:    return (606, 3653)
        case 2004:    return (612, 3689)
        case 2005:    return (627, 3779)
        case 2006:    return (656, 3955)
        case 2007:    return (680, 4100)
        case 2008:    return (711, 4288)
        case 2009:    return (744, 4483)
        case 2010:    return (761, 4586)
        case 2011:    return (749, 4517)
        case 2012:    return (767, 4624)
        case 2013:    return (791, 4768)
        case 2014:    return (816, 4917)
        case 2015:    return (826, 4980)
        case 2016:    return (856, 5157)
        case 2017:    return (885, 5336)
        case 2018:    return (895, 5397)
        case 2019:    return (926, 5583)
        case 2020:    return (960, 5785)
        case 2021:    return (996, 6002)
        case 2022:    return (1024, 6172)
        case 2023:    return (1115, 6721)
        case 2024:    return (1174, 7078)
        case 2025:    return (1226, 7391)
        case 2026:    return (1286, 7749)
        default:      return (1286, 7749) // Use 2026 as best available for future years
        }
    }

    // MARK: - AIME/PIA Calculation

    /// Calculate AIME and PIA from an earnings history.
    ///
    /// - Parameters:
    ///   - records: Yearly earnings records
    ///   - birthYear: Worker's birth year (determines indexing year and bend points)
    ///   - futureEarningsPerYear: Projected annual earnings for future work years
    ///   - futureWorkYears: Number of additional years to project
    /// - Returns: Full PIA calculation result, or nil if no earnings
    static func calculatePIA(
        records: [SSEarningsRecord],
        birthYear: Int,
        futureEarningsPerYear: Double = 0,
        futureWorkYears: Int = 0
    ) -> SSPIAResult? {
        guard !records.isEmpty || futureWorkYears > 0 else { return nil }

        let indexingYear = birthYear + 60
        let yearTurning62 = birthYear + 62
        let currentYear = Calendar.current.component(.year, from: Date())

        // Get the AWI for the indexing year (or latest available)
        let indexingAWI = awiForYear(indexingYear)

        // Step 1: Index each year's earnings
        var allEarnings: [(year: Int, actual: Double, indexed: Double)] = []

        for record in records {
            let capped = min(record.earnings, taxableMaxTable[record.year] ?? record.earnings)
            let indexed: Double
            if record.year < indexingYear {
                let yearAWI = awiForYear(record.year)
                indexed = capped * (indexingAWI / yearAWI)
            } else {
                indexed = capped // No indexing at or after age 60
            }
            allEarnings.append((year: record.year, actual: capped, indexed: indexed))
        }

        // Add projected future earnings
        if futureEarningsPerYear > 0 && futureWorkYears > 0 {
            let startYear = (records.map(\.year).max() ?? currentYear) + 1
            for i in 0..<futureWorkYears {
                let year = startYear + i
                let capped = min(futureEarningsPerYear, taxableMaxTable[year] ?? futureEarningsPerYear)
                // Future years are at or after indexing year for most current users
                allEarnings.append((year: year, actual: capped, indexed: capped))
            }
        }

        // Step 2: Select top 35 years by indexed earnings
        let sorted = allEarnings.sorted { $0.indexed > $1.indexed }
        let top35 = Array(sorted.prefix(35))
        let yearsOfEarnings = allEarnings.filter { $0.actual > 0 }.count

        // Step 3: Compute AIME (truncate to whole dollar)
        let totalIndexed = top35.reduce(0.0) { $0 + $1.indexed }
        let aime = Int(totalIndexed / 420.0) // floor/truncate

        // Step 4: Apply PIA formula with bend points
        let bends = piaBendPoints(yearTurning62: yearTurning62)
        let rawPIA = piaFromAIME(aime: aime, bendPoint1: bends.bp1, bendPoint2: bends.bp2)

        // Step 5: Round PIA down to nearest dime
        let pia = floor(rawPIA * 10.0) / 10.0

        return SSPIAResult(
            aime: aime,
            pia: pia,
            indexedEarnings: allEarnings.sorted { $0.year < $1.year },
            top35Years: top35.map { (year: $0.year, indexed: $0.indexed) },
            totalIndexedEarnings: totalIndexed,
            bendPoint1: bends.bp1,
            bendPoint2: bends.bp2,
            yearsOfEarnings: yearsOfEarnings,
            zeroPaddedYears: max(0, 35 - yearsOfEarnings)
        )
    }

    /// Apply the PIA bend-point formula to an AIME value
    static func piaFromAIME(aime: Int, bendPoint1: Double, bendPoint2: Double) -> Double {
        let a = Double(aime)
        let tier1 = 0.90 * min(a, bendPoint1)
        let tier2 = 0.32 * max(0, min(a, bendPoint2) - bendPoint1)
        let tier3 = 0.15 * max(0, a - bendPoint2)
        return tier1 + tier2 + tier3
    }

    /// Look up AWI for a year, extrapolating if beyond published data
    private static func awiForYear(_ year: Int) -> Double {
        if let awi = awiTable[year] { return awi }
        // Extrapolate from last known year using ~4% annual growth
        guard let lastYear = awiTable.keys.max(), let lastAWI = awiTable[lastYear] else {
            return 66621.80 // fallback to 2023
        }
        let yearsForward = year - lastYear
        return lastAWI * pow(1.04, Double(yearsForward))
    }

    // MARK: - Earnings History Parser

    /// Parse pasted earnings history text into structured records.
    /// Handles SSA statement format including:
    /// - Single years: "2020  $85,000  $85,000"
    /// - Year ranges: "1966-1980  $48,273" (splits evenly across years)
    /// - "Not yet recorded" lines (skipped gracefully)
    /// - Two-column format (uses first dollar amount = SS earnings column)
    static func parseEarningsHistory(_ text: String) -> Result<SSParseResult, SSParseError> {
        let lines = text.components(separatedBy: .newlines)
        var records: [SSEarningsRecord] = []
        var skippedLines: [String] = []
        var zeroYears: [Int] = []
        var capYears: [Int] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // Skip lines with "not yet recorded"
            if trimmed.localizedCaseInsensitiveContains("not yet recorded") { continue }

            // Try year range first (e.g., "1966-1980  $48,273")
            let parsed = parseEarningsLine(trimmed)

            if parsed.isEmpty {
                // Skip header-like lines, but track them
                if trimmed.count > 2 {
                    skippedLines.append(trimmed)
                }
                continue
            }

            for entry in parsed {
                if entry.earnings == 0 {
                    zeroYears.append(entry.year)
                }
                if let cap = taxableMaxTable[entry.year], entry.earnings >= cap {
                    capYears.append(entry.year)
                }
                records.append(SSEarningsRecord(year: entry.year, earnings: entry.earnings))
            }
        }

        if records.isEmpty {
            return .failure(.noValidRows)
        }

        // Sort by year
        records.sort { $0.year < $1.year }

        return .success(SSParseResult(
            records: records,
            skippedLines: skippedLines,
            zeroYears: zeroYears,
            capYears: capYears
        ))
    }

    /// Parse a single line, returning one or more (year, earnings) pairs.
    /// Returns multiple entries for year ranges like "1966-1980 $48,273".
    /// Returns empty array if the line can't be parsed.
    private static func parseEarningsLine(_ line: String) -> [(year: Int, earnings: Double)] {
        // Clean $ and , for numeric parsing
        let cleaned = line.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")

        // Check for year range pattern: "YYYY-YYYY" (e.g., "1966-1980")
        let rangePattern = /\b(19[4-9]\d|20[0-3]\d)-(19[4-9]\d|20[0-3]\d)\b/
        if let rangeMatch = cleaned.firstMatch(of: rangePattern),
           let startYear = Int(rangeMatch.1),
           let endYear = Int(rangeMatch.2),
           endYear >= startYear {

            // Extract the first dollar amount on the line (SS earnings column)
            let amount = extractFirstAmount(from: cleaned, excluding: startYear, and: endYear)
            let yearCount = endYear - startYear + 1
            let perYear = amount / Double(yearCount)

            return (startYear...endYear).map { year in
                (year: year, earnings: perYear)
            }
        }

        // Single year pattern
        let yearPattern = /\b(19[4-9]\d|20[0-3]\d)\b/
        guard let yearMatch = cleaned.firstMatch(of: yearPattern),
              let year = Int(yearMatch.1) else { return [] }

        // Extract the first dollar amount (SS earnings column, ignoring Medicare column)
        let amount = extractFirstAmount(from: cleaned, excluding: year)
        return [(year: year, earnings: amount)]
    }

    /// Extract the first numeric amount from a cleaned line, skipping year-like tokens.
    private static func extractFirstAmount(from cleaned: String, excluding year1: Int, and year2: Int? = nil) -> Double {
        let tokens = cleaned.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        for token in tokens {
            // Skip year tokens
            if token == String(year1) { continue }
            if let y2 = year2, token == String(y2) { continue }
            // Skip the range token itself (e.g., "19661980" after cleaning)
            if token.contains("-") { continue }
            // Skip tokens that look like a year
            if token.count == 4, let val = Int(token), val >= 1940, val <= 2030 { continue }
            // Try to parse as a number — take the first one (SS earnings column)
            if let amount = Double(token), amount >= 0 {
                return amount
            }
        }

        return 0
    }

    // MARK: - XML Earnings Import

    /// Parse SSA XML statement file into earnings records.
    /// Handles the osss:OnlineSocialSecurityStatementData format from ssa.gov.
    /// Uses FicaEarnings (SS taxable earnings), skips entries with -1 (not yet recorded).
    /// Also extracts date of birth if present.
    struct SSXMLParseResult {
        var earnings: SSParseResult
        var dateOfBirth: Date?    // From UserInformation, if present
    }

    static func parseEarningsXML(_ data: Data) -> Result<SSXMLParseResult, SSParseError> {
        let parser = SSXMLEarningsParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.shouldProcessNamespaces = true
        xmlParser.delegate = parser
        xmlParser.parse()

        guard !parser.records.isEmpty else {
            return .failure(.noValidRows)
        }

        let records = parser.records.sorted { $0.year < $1.year }
        var zeroYears: [Int] = []
        var capYears: [Int] = []

        for record in records {
            if record.earnings == 0 {
                zeroYears.append(record.year)
            }
            if let cap = taxableMaxTable[record.year], record.earnings >= cap {
                capYears.append(record.year)
            }
        }

        let parseResult = SSParseResult(
            records: records,
            skippedLines: [],
            zeroYears: zeroYears,
            capYears: capYears
        )

        return .success(SSXMLParseResult(
            earnings: parseResult,
            dateOfBirth: parser.dateOfBirth
        ))
    }

    // MARK: - Helpers

    /// Birth year extracted from a Date
    static func birthYear(from date: Date) -> Int {
        Calendar.current.component(.year, from: date)
    }

    /// Current age in whole years from a birth date
    static func currentAge(from birthDate: Date) -> Int {
        let now = Date()
        let components = Calendar.current.dateComponents([.year], from: birthDate, to: now)
        return components.year ?? 0
    }

    /// Format a monthly benefit as currency
    static func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    /// Format a large cumulative amount (e.g., $1.2M)
    static func formatLargeCurrency(_ amount: Double) -> String {
        if amount >= 1_000_000 {
            return String(format: "$%.1fM", amount / 1_000_000)
        } else if amount >= 1_000 {
            return String(format: "$%.0fK", amount / 1_000)
        }
        return String(format: "$%.0f", amount)
    }
}

// MARK: - SSA XML Parser Delegate

/// XMLParser delegate that extracts earnings records from SSA's XML statement format.
/// Handles the osss:OnlineSocialSecurityStatementData schema.
private class SSXMLEarningsParser: NSObject, XMLParserDelegate {
    var records: [SSEarningsRecord] = []
    var dateOfBirth: Date?

    // Parsing state
    private var currentStartYear: Int?
    private var currentEndYear: Int?
    private var currentElement: String = ""
    private var currentText: String = ""
    private var inEarningsElement = false

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        // Strip namespace prefix for easier matching
        let local = elementName.components(separatedBy: ":").last ?? elementName

        if local == "Earnings" {
            inEarningsElement = true
            if let start = attributes["startYear"], let startYr = Int(start) {
                currentStartYear = startYr
            }
            if let end = attributes["endYear"], let endYr = Int(end) {
                currentEndYear = endYr
            }
        }

        currentElement = local
        currentText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        let local = elementName.components(separatedBy: ":").last ?? elementName
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if local == "DateOfBirth", let date = parseISODate(trimmed) {
            dateOfBirth = date
        }

        if local == "FicaEarnings", inEarningsElement,
           let startYear = currentStartYear,
           let endYear = currentEndYear,
           let amount = Double(trimmed) {

            // Skip -1 entries (SSA's "not yet recorded" marker)
            guard amount >= 0 else {
                // Reset for next element
                if local == "FicaEarnings" { /* wait for Earnings end */ }
                return
            }

            // Handle year ranges (though SSA XML typically uses startYear == endYear)
            if startYear == endYear {
                records.append(SSEarningsRecord(year: startYear, earnings: amount))
            } else {
                let yearCount = endYear - startYear + 1
                let perYear = amount / Double(yearCount)
                for year in startYear...endYear {
                    records.append(SSEarningsRecord(year: year, earnings: perYear))
                }
            }
        }

        if local == "Earnings" {
            inEarningsElement = false
            currentStartYear = nil
            currentEndYear = nil
        }

        currentElement = ""
    }

    private func parseISODate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        // Try just the date portion (handles "1955-02-02" from "1955-02-02T...")
        let dateOnly = String(string.prefix(10))
        return formatter.date(from: dateOnly)
    }
}
