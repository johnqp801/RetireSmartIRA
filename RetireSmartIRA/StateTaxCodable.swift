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
