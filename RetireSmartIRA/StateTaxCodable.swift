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
