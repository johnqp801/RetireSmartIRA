import Foundation

/// Provenance for one jurisdiction's tax configuration.
///
/// Required by schema on every state file. A jurisdiction cannot be added
/// without a primary source and a verification date. That requirement is the
/// forcing function: the 2026-08-02 audit found roughly 29 of 51 jurisdictions
/// defective, and Wisconsin was wrong while carrying a "verified" code comment,
/// because nothing structural required the comment to mean anything.
struct StateVerification: Codable, Equatable, Sendable {
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
        lastVerified: "",
        primarySources: [],
        billReferences: [],
        knownLimitations: []
    )
}
