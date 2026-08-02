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
