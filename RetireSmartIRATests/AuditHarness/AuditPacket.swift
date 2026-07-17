//
//  AuditPacket.swift
//  RetireSmartIRATests
//
//  Stage 1, Task 5 of the Multi-Year Display Audit Harness — the JSON packet emitter.
//
//  One `AuditPacket` per catalog profile bundles everything Stage 2's later multi-model reviewer
//  needs to reason about a single household WITHOUT re-running the engine: a human-readable
//  inputs summary, the full `DisplaySnapshot` (every rendered value), and the deterministic
//  property oracle's `InvariantViolation`s for that profile.
//
//  `AuditPacketWriter.write` emits one `<profileId>.json` per packet with `.prettyPrinted` +
//  `.sortedKeys`, so the output is byte-for-byte deterministic (stable key order, no RNG, no
//  Date()) and diffable across runs. The packets directory is git-ignored (Stage-2 input, not a
//  committed artifact) and created on demand.
//

import Foundation
@testable import RetireSmartIRA

/// A single profile's audit result, serialized for Stage 2. `Codable` so the whole packet
/// round-trips through JSON.
struct AuditPacket: Codable {
    let profileId: String
    let inputsSummary: [String: String]
    let snapshot: DisplaySnapshot
    let violations: [InvariantViolation]
}

/// Writes `AuditPacket`s to disk as deterministic JSON (one file per profile).
enum AuditPacketWriter {

    /// Create `dir` if absent and write one `<profileId>.json` per packet. Encoding is
    /// `.prettyPrinted` + `.sortedKeys` for stable, diffable output.
    static func write(_ packets: [AuditPacket], to dir: URL) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        for packet in packets {
            let data = try encoder.encode(packet)
            let fileURL = dir.appendingPathComponent("\(packet.profileId).json")
            try data.write(to: fileURL, options: .atomic)
        }
    }
}
