import Foundation

/// What part of a jurisdiction's tax treatment a limitation sentence is about.
///
/// EXISTS BECAUSE A SURFACE HAS TO CHOOSE. Every limitation a state ships
/// rendered, unfiltered, inside the pension editor's "What kind of pension is
/// this?" section. That was harmless while every stored sentence was about a
/// pension, which was true of all six that existed before this field, Georgia's
/// included: its $70,000 figure is the TY2027 RETIREMENT-INCOME EXCLUSION, not
/// the $15,000/$30,000 standard deduction its wording suggests.
///
/// It stopped being true when the remaining jurisdictions were authored. Utah's
/// taxpayer tax credit and retirement credit, and New Mexico's age-65 Schedule
/// PIT-ADJ exemption, are not about pensions at all: they change tax for every
/// filer who qualifies, including one with no pension. Rendering them under
/// "What kind of pension is this?" would be true and misplaced, and would
/// invite a user to think answering the picker changes them.
///
/// The topic names the MECHANISM the sentence is about, not the screen it
/// belongs on. Surfaces choose: the pension editor asks for `.pension` alone,
/// and the per-state accuracy page shows every topic. Naming a screen here
/// would put a layout decision inside the tax data, and the same sentence is
/// already read by three surfaces.
///
/// Every case below is used by a sentence that ships today. Add a case when a
/// sentence needs one, not in advance; a case no sentence carries is a
/// distinction nothing has had to defend.
enum LimitationTopic: String, Codable, Equatable, Sendable, CaseIterable {
    /// How a pension, annuity, IRA or other retirement distribution is taxed,
    /// exempted or classified. Includes a cap on a retirement-income exclusion.
    case pension
    /// A credit against tax, computed after taxable income and therefore
    /// unaffected by how any income is classified.
    case credit
    /// An exemption from income that does not turn on retirement
    /// classification, such as an age-based personal exemption.
    case exemption
}

/// One plain sentence describing something this app does not model for a
/// jurisdiction, together with what it is about.
///
/// THE TEXT IS JOHN'S APPROVED COPY and is rendered verbatim. The topic is
/// part of that editorial decision rather than an implementation detail,
/// because it decides which surfaces show the sentence.
struct StateLimitation: Codable, Equatable, Sendable {
    /// Rendered verbatim to the user. May carry the `{scope}` token, which each
    /// surface substitutes; see `StateAccuracyContent.LimitationScope`.
    let text: String

    /// What the sentence is about. Decides which surfaces render it.
    let topic: LimitationTopic

    enum CodingKeys: String, CodingKey {
        case text
        case topic
    }

    /// Accepts EITHER the tagged object form or a bare JSON string.
    ///
    /// The bare form resolves to `.pension`, which is the pre-tag behaviour:
    /// the sentence keeps rendering everywhere it used to, including the
    /// pension editor. That direction is deliberate. The alternative default
    /// would silently REMOVE a disclosure from the one screen a pension holder
    /// sees, and a disclosure disappearing is the dangerous direction in this
    /// program; a true sentence shown under a slightly wrong heading is not.
    ///
    /// It is a robustness fallback, not a second supported shape. No bundled
    /// file uses it, and `StateAccuracyContentTests
    /// .everyShippedLimitationIsTaggedInTheFileItself` reads the files off disk
    /// and fails if one ever does. Strict decoding was considered and rejected:
    /// a throw here is converted by `StateTaxDataLoader` into a per-state
    /// fallback to the frozen legacy table, whose `verification` is
    /// `.unverified`, so a mistyped entry would drop the state's disclosure
    /// entirely in release and trap the process in debug.
    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let bare = try? container.decode(String.self) {
            self.init(text: bare, topic: .pension)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(text: try container.decode(String.self, forKey: .text),
                  topic: try container.decode(LimitationTopic.self, forKey: .topic))
    }

    init(text: String, topic: LimitationTopic) {
        self.text = text
        self.topic = topic
    }
}

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

    /// Plain sentences describing what this app does NOT model for this state,
    /// each tagged with what it is about. Surfaced verbatim in the disclosure
    /// UI. Required, may be empty.
    ///
    /// AN EMPTY LIST IS NOT A CLEAN BILL OF HEALTH. It records what has not
    /// been FOUND for this jurisdiction, never what does not EXIST. Thirty-six
    /// jurisdictions are outside the scope this release authored pages for and
    /// carry an empty list for that reason alone.
    let knownLimitations: [StateLimitation]

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
            knownLimitations: try container.decode([StateLimitation].self, forKey: .knownLimitations)
        )
    }
}
