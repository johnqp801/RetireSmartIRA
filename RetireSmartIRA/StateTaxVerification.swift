import Foundation

/// Provenance for one jurisdiction's tax configuration.
///
/// Present on every state file. Its purpose is to make a verification claim
/// checkable: the 2026-08-02 audit found roughly 29 of 51 jurisdictions
/// defective, and Wisconsin was wrong while carrying a "verified" code comment,
/// because nothing anywhere required that comment to mean anything.
///
/// Note what does and does not enforce that. These configurations are JSON, so
/// the enforcement lives in tests and in decoding, never in the Swift type
/// system. A file that omits `verification` entirely decodes to `.unverified`;
/// a file that omits `taxYear` inside it decodes to the `0` sentinel. Neither
/// is a compile error and neither can be made into one while the data ships as
/// JSON. `StateAccuracyContentTests` is where a covered jurisdiction's missing
/// provenance actually fails the suite. A test failure, not a build failure:
/// the code compiles and the app runs either way.
struct StateVerification: Codable, Equatable, Sendable {
    /// The tax year whose law this configuration states, e.g. `2026`.
    ///
    /// The accuracy page heads with state AND year together ("Iowa tax
    /// treatment, 2026") rather than a bare state name, because "verified
    /// August 2026" otherwise reads as a claim about current law generally
    /// instead of about one year's rules.
    ///
    /// `0` means the file did not state a year. That sentinel exists because
    /// fifty of the fifty-one bundled files predate this field; it is not a
    /// value any file should ship. `StateAccuracyContentTests` fails a covered
    /// jurisdiction that leaves it at `0`.
    let taxYear: Int

    /// The stated tax year, or `nil` when the file stated none.
    ///
    /// EVERY RENDERER MUST READ THIS, NOT `taxYear`. `0` is not a year and has
    /// no sensible rendering. Thirty-six jurisdictions carry it today, so an
    /// accuracy-page header interpolating `taxYear` directly would read
    /// "Pennsylvania tax treatment, 0" for most of the country, and it would
    /// do so silently, because nothing about an `Int` invites the author to
    /// ask what `0` means. Making the sentinel an `Optional` at the one place
    /// a renderer touches it turns that from a copy defect nobody would catch
    /// into a question the compiler asks.
    ///
    /// What to SHOW when it is `nil` is deliberately not decided here. That is
    /// user-facing copy and therefore John's to approve, and it belongs with
    /// the rest of the accuracy page's wording rather than buried in a data
    /// type.
    var statedTaxYear: Int? { taxYear == 0 ? nil : taxYear }

    /// ISO `yyyy-MM-dd`. Empty string means never verified.
    ///
    /// Deliberately a String, not a Date: this is a calendar date with no
    /// time-zone meaning, and Date round-trips lossily through JSON in a way
    /// that would make the Phase 1 equivalence test flaky.
    let lastVerified: String

    /// State DOR pages, statutes, or enrolled bills. Advisor blogs and
    /// tax-prep vendor help pages are not admissible here.
    let primarySources: [String]

    /// Bill numbers with their disposition, e.g. "SB25-136 (postponed indefinitely)".
    let billReferences: [String]

    /// Plain sentences describing what this app does NOT model for this state.
    /// Surfaced verbatim in the disclosure UI. Required, may be empty.
    let knownLimitations: [String]

    var isVerified: Bool { !lastVerified.isEmpty }

    /// Placeholder for jurisdictions carrying no verification stamp today.
    /// Phase 1 assigns this to every state that lacks a "Verified" comment.
    static let unverified = StateVerification(
        taxYear: 0,
        lastVerified: "",
        primarySources: [],
        billReferences: [],
        knownLimitations: []
    )

    enum CodingKeys: String, CodingKey {
        case taxYear
        case lastVerified
        case primarySources
        case billReferences
        case knownLimitations
    }
}

extension StateVerification {
    /// Hand-written so `taxYear` can be absent without failing the decode.
    ///
    /// Fifty of the fifty-one bundled 2026 files were generated before this
    /// field existed. Synthesized decoding would make `taxYear` mandatory and
    /// every one of those files would throw, which the loader converts into a
    /// per-state fallback to the frozen legacy table and, in debug builds, an
    /// `assertionFailure`. So the field is optional at the JSON layer by
    /// necessity, and the completeness requirement is carried by
    /// `StateAccuracyContentTests` instead.
    ///
    /// Only `taxYear` is lenient. The other four keys stay mandatory, exactly
    /// as synthesized decoding had them, because every shipped file has them.
    ///
    /// Written in an extension so the memberwise initializer is still
    /// synthesized, which keeps `taxYear` a required argument at every Swift
    /// construction site.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            taxYear: try container.decodeIfPresent(Int.self, forKey: .taxYear) ?? 0,
            lastVerified: try container.decode(String.self, forKey: .lastVerified),
            primarySources: try container.decode([String].self, forKey: .primarySources),
            billReferences: try container.decode([String].self, forKey: .billReferences),
            knownLimitations: try container.decode([String].self, forKey: .knownLimitations)
        )
    }
}
