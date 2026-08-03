import Foundation

// Hand-written Codable conformances for the enums carrying associated values.
// Swift cannot synthesize these. Each uses an explicit "kind" discriminator so
// the JSON stays readable and reviewable by a non-Swift reader, which is one of
// the reasons the data is moving to JSON at all.

extension StateTaxSystem: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, rate, single, married
    }
    private enum Kind: String, Codable {
        case noIncomeTax, flat, progressive, specialLimited
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .noIncomeTax:
            try c.encode(Kind.noIncomeTax, forKey: .kind)
        case .specialLimited:
            try c.encode(Kind.specialLimited, forKey: .kind)
        case .flat(let rate):
            try c.encode(Kind.flat, forKey: .kind)
            try c.encode(rate, forKey: .rate)
        case .progressive(let single, let married):
            try c.encode(Kind.progressive, forKey: .kind)
            try c.encode(single, forKey: .single)
            try c.encode(married, forKey: .married)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .noIncomeTax:
            self = .noIncomeTax
        case .specialLimited:
            self = .specialLimited
        case .flat:
            self = .flat(rate: try c.decode(Double.self, forKey: .rate))
        case .progressive:
            self = .progressive(
                single: try c.decode([TaxBracket].self, forKey: .single),
                married: try c.decode([TaxBracket].self, forKey: .married)
            )
        }
    }
}

extension StateDeduction: Codable {
    private enum CodingKeys: String, CodingKey { case kind, single, married }
    private enum Kind: String, Codable { case none, conformsToFederal, fixed }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try c.encode(Kind.none, forKey: .kind)
        case .conformsToFederal:
            try c.encode(Kind.conformsToFederal, forKey: .kind)
        case .fixed(let single, let married):
            try c.encode(Kind.fixed, forKey: .kind)
            try c.encode(single, forKey: .single)
            try c.encode(married, forKey: .married)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .none: self = .none
        case .conformsToFederal: self = .conformsToFederal
        case .fixed:
            self = .fixed(
                single: try c.decode(Double.self, forKey: .single),
                married: try c.decode(Double.self, forKey: .married)
            )
        }
    }
}

extension StateSafeHarborRule: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, rate, threshold, lowRate, highRate, disqualifyAGI
    }
    private enum Kind: String, Codable {
        case mirrorsFederal, flatRate, agiThreshold, mirrorsFederalWithDisqualification, noPenalty
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .mirrorsFederal:
            try c.encode(Kind.mirrorsFederal, forKey: .kind)
        case .flatRate(let rate):
            try c.encode(Kind.flatRate, forKey: .kind)
            try c.encode(rate, forKey: .rate)
        case .agiThreshold(let threshold, let lowRate, let highRate):
            try c.encode(Kind.agiThreshold, forKey: .kind)
            try c.encode(threshold, forKey: .threshold)
            try c.encode(lowRate, forKey: .lowRate)
            try c.encode(highRate, forKey: .highRate)
        case .mirrorsFederalWithDisqualification(let disqualifyAGI):
            try c.encode(Kind.mirrorsFederalWithDisqualification, forKey: .kind)
            try c.encode(disqualifyAGI, forKey: .disqualifyAGI)
        case .noPenalty:
            try c.encode(Kind.noPenalty, forKey: .kind)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .mirrorsFederal:
            self = .mirrorsFederal
        case .flatRate:
            self = .flatRate(try c.decode(Double.self, forKey: .rate))
        case .agiThreshold:
            self = .agiThreshold(
                threshold: try c.decode(Double.self, forKey: .threshold),
                lowRate: try c.decode(Double.self, forKey: .lowRate),
                highRate: try c.decode(Double.self, forKey: .highRate)
            )
        case .mirrorsFederalWithDisqualification:
            self = .mirrorsFederalWithDisqualification(
                disqualifyAGI: try c.decode(Double.self, forKey: .disqualifyAGI)
            )
        case .noPenalty:
            self = .noPenalty
        }
    }
}

extension RetirementIncomeExemptions.PhaseoutTier: Codable {
    private enum CodingKeys: String, CodingKey {
        case upperBound, mfjPercent, singlePercent
    }

    // Foundation's JSONEncoder throws on non-conforming floats by default, and
    // NJ's open-ended cliff band uses .infinity as its upper bound. Encode it
    // as a sentinel string so the JSON stays valid and human-readable.
    private static let infinitySentinel = "unbounded"

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if upperBound.isInfinite {
            try c.encode(Self.infinitySentinel, forKey: .upperBound)
        } else {
            try c.encode(upperBound, forKey: .upperBound)
        }
        try c.encode(mfjPercent, forKey: .mfjPercent)
        try c.encode(singlePercent, forKey: .singlePercent)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let sentinel = try? c.decode(String.self, forKey: .upperBound),
           sentinel == Self.infinitySentinel {
            self.init(upperBound: .infinity,
                      mfjPercent: try c.decode(Double.self, forKey: .mfjPercent),
                      singlePercent: try c.decode(Double.self, forKey: .singlePercent))
        } else {
            self.init(upperBound: try c.decode(Double.self, forKey: .upperBound),
                      mfjPercent: try c.decode(Double.self, forKey: .mfjPercent),
                      singlePercent: try c.decode(Double.self, forKey: .singlePercent))
        }
    }
}

extension RetirementIncomeExemptions.ExemptionLevel: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, maxExempt, maxExemptSingle, maxExemptMFJ, tiers
    }
    private enum Kind: String, Codable {
        case none, full, partial, steppedPhaseoutByFilingStatus
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try c.encode(Kind.none, forKey: .kind)
        case .full:
            try c.encode(Kind.full, forKey: .kind)
        case .partial(let maxExempt):
            try c.encode(Kind.partial, forKey: .kind)
            try c.encode(maxExempt, forKey: .maxExempt)
        case .steppedPhaseoutByFilingStatus(let single, let mfj, let tiers):
            try c.encode(Kind.steppedPhaseoutByFilingStatus, forKey: .kind)
            try c.encode(single, forKey: .maxExemptSingle)
            try c.encode(mfj, forKey: .maxExemptMFJ)
            try c.encode(tiers, forKey: .tiers)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .none:
            self = .none
        case .full:
            self = .full
        case .partial:
            self = .partial(maxExempt: try c.decode(Double.self, forKey: .maxExempt))
        case .steppedPhaseoutByFilingStatus:
            self = .steppedPhaseoutByFilingStatus(
                maxExemptSingle: try c.decode(Double.self, forKey: .maxExemptSingle),
                maxExemptMFJ: try c.decode(Double.self, forKey: .maxExemptMFJ),
                tiers: try c.decode([RetirementIncomeExemptions.PhaseoutTier].self, forKey: .tiers)
            )
        }
    }
}

extension RetirementIncomeExemptions.CapGainsTreatment: Codable {
    private enum Kind: String, Codable {
        case followsFederal, taxedAsOrdinary, noStateTax
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .followsFederal:  try c.encode(Kind.followsFederal)
        case .taxedAsOrdinary: try c.encode(Kind.taxedAsOrdinary)
        case .noStateTax:      try c.encode(Kind.noStateTax)
        }
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        switch try c.decode(Kind.self) {
        case .followsFederal:  self = .followsFederal
        case .taxedAsOrdinary: self = .taxedAsOrdinary
        case .noStateTax:      self = .noStateTax
        }
    }
}

extension RetirementIncomeExemptions.AgeTier: Codable {
    private enum CodingKeys: String, CodingKey { case minAge, maxAge, level }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(ageRange.lowerBound, forKey: .minAge)
        try c.encode(ageRange.upperBound, forKey: .maxAge)
        try c.encode(level, forKey: .level)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let lowerBound = try c.decode(Int.self, forKey: .minAge)
        let upperBound = try c.decode(Int.self, forKey: .maxAge)
        // ClosedRange's `...` traps (process crash) when lowerBound > upperBound.
        // Task 9's loader reads real, possibly hand-edited JSON across 51
        // jurisdictions, so malformed input must surface as a catchable
        // decode error, not kill the app.
        guard lowerBound <= upperBound else {
            throw DecodingError.dataCorruptedError(
                forKey: .maxAge, in: c,
                debugDescription: "AgeTier maxAge (\(upperBound)) must be >= minAge (\(lowerBound))")
        }
        self.init(
            ageRange: lowerBound...upperBound,
            level: try c.decode(RetirementIncomeExemptions.ExemptionLevel.self, forKey: .level)
        )
    }
}

extension RetirementIncomeExemptions: Codable {
    private enum CodingKeys: String, CodingKey {
        case socialSecurityExempt, pensionExemption, iraWithdrawalExemption
        case exemptionAppliesPerIndividual, regularExemptionMinAge, distributionMinAge, earlyAgeTier
        case pensionAndIRAShareSingleCap, otherRetirementIncomeExclusion
        case capitalGainsTreatment
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(socialSecurityExempt, forKey: .socialSecurityExempt)
        try c.encode(pensionExemption, forKey: .pensionExemption)
        try c.encode(iraWithdrawalExemption, forKey: .iraWithdrawalExemption)
        try c.encode(exemptionAppliesPerIndividual, forKey: .exemptionAppliesPerIndividual)
        try c.encode(regularExemptionMinAge, forKey: .regularExemptionMinAge)
        try c.encode(distributionMinAge, forKey: .distributionMinAge)
        try c.encodeIfPresent(earlyAgeTier, forKey: .earlyAgeTier)
        try c.encode(pensionAndIRAShareSingleCap, forKey: .pensionAndIRAShareSingleCap)
        try c.encode(otherRetirementIncomeExclusion, forKey: .otherRetirementIncomeExclusion)
        try c.encode(capitalGainsTreatment, forKey: .capitalGainsTreatment)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Every field falls back to its declared default. Phase 3 adds fields;
        // Phase 1 files must keep decoding without regeneration.
        self.init(
            socialSecurityExempt: try c.decodeIfPresent(Bool.self, forKey: .socialSecurityExempt) ?? true,
            pensionExemption: try c.decodeIfPresent(ExemptionLevel.self, forKey: .pensionExemption) ?? .none,
            iraWithdrawalExemption: try c.decodeIfPresent(ExemptionLevel.self, forKey: .iraWithdrawalExemption) ?? .none,
            exemptionAppliesPerIndividual: try c.decodeIfPresent(Bool.self, forKey: .exemptionAppliesPerIndividual) ?? false,
            regularExemptionMinAge: try c.decodeIfPresent(Int.self, forKey: .regularExemptionMinAge) ?? 0,
            distributionMinAge: try c.decodeIfPresent(Int.self, forKey: .distributionMinAge) ?? 59,
            earlyAgeTier: try c.decodeIfPresent(AgeTier.self, forKey: .earlyAgeTier),
            pensionAndIRAShareSingleCap: try c.decodeIfPresent(Bool.self, forKey: .pensionAndIRAShareSingleCap) ?? false,
            otherRetirementIncomeExclusion: try c.decodeIfPresent(Bool.self, forKey: .otherRetirementIncomeExclusion) ?? false,
            capitalGainsTreatment: try c.decodeIfPresent(CapGainsTreatment.self, forKey: .capitalGainsTreatment) ?? .followsFederal
        )
    }
}

extension StateTaxConfig: Codable {
    private enum CodingKeys: String, CodingKey {
        case state, taxSystem, retirementExemptions, stateDeduction
        case estimatedPaymentSchedule, safeHarborRule, currentYearSafeHarborRate
        case hsaContributionsTaxableForState
        case traditionalIRAContributionsTaxableForState
        case otherPreTaxDeductionsTaxableForState
        case pretax401kContributionsTaxableForState
        case capitalLossesClassIsolated
        case verification
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(state.abbreviation, forKey: .state)
        try c.encode(taxSystem, forKey: .taxSystem)
        try c.encode(retirementExemptions, forKey: .retirementExemptions)
        try c.encode(stateDeduction, forKey: .stateDeduction)
        try c.encode(estimatedPaymentSchedule, forKey: .estimatedPaymentSchedule)
        try c.encode(safeHarborRule, forKey: .safeHarborRule)
        try c.encode(currentYearSafeHarborRate, forKey: .currentYearSafeHarborRate)
        try c.encode(hsaContributionsTaxableForState, forKey: .hsaContributionsTaxableForState)
        try c.encode(traditionalIRAContributionsTaxableForState,
                     forKey: .traditionalIRAContributionsTaxableForState)
        try c.encode(otherPreTaxDeductionsTaxableForState,
                     forKey: .otherPreTaxDeductionsTaxableForState)
        try c.encode(pretax401kContributionsTaxableForState,
                     forKey: .pretax401kContributionsTaxableForState)
        try c.encode(capitalLossesClassIsolated, forKey: .capitalLossesClassIsolated)
        try c.encode(verification, forKey: .verification)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let abbreviation = try c.decode(String.self, forKey: .state)
        guard let state = USState.allCases.first(where: { $0.abbreviation == abbreviation }) else {
            throw DecodingError.dataCorruptedError(
                forKey: .state, in: c,
                debugDescription: "Unknown state abbreviation '\(abbreviation)'")
        }
        self.init(
            state: state,
            taxSystem: try c.decode(StateTaxSystem.self, forKey: .taxSystem),
            retirementExemptions: try c.decode(RetirementIncomeExemptions.self,
                                               forKey: .retirementExemptions),
            stateDeduction: try c.decode(StateDeduction.self, forKey: .stateDeduction),
            estimatedPaymentSchedule: try c.decodeIfPresent(
                EstimatedPaymentSchedule.self, forKey: .estimatedPaymentSchedule) ?? .federal,
            safeHarborRule: try c.decodeIfPresent(
                StateSafeHarborRule.self, forKey: .safeHarborRule) ?? .mirrorsFederal,
            currentYearSafeHarborRate: try c.decodeIfPresent(
                Double.self, forKey: .currentYearSafeHarborRate) ?? 0.90,
            hsaContributionsTaxableForState: try c.decodeIfPresent(
                Bool.self, forKey: .hsaContributionsTaxableForState) ?? false,
            traditionalIRAContributionsTaxableForState: try c.decodeIfPresent(
                Bool.self, forKey: .traditionalIRAContributionsTaxableForState) ?? false,
            otherPreTaxDeductionsTaxableForState: try c.decodeIfPresent(
                Bool.self, forKey: .otherPreTaxDeductionsTaxableForState) ?? false,
            pretax401kContributionsTaxableForState: try c.decodeIfPresent(
                Bool.self, forKey: .pretax401kContributionsTaxableForState) ?? false,
            capitalLossesClassIsolated: try c.decodeIfPresent(
                Bool.self, forKey: .capitalLossesClassIsolated) ?? false,
            verification: try c.decodeIfPresent(
                StateVerification.self, forKey: .verification) ?? .unverified
        )
    }
}
