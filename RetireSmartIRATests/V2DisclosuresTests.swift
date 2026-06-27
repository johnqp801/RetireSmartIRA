import Testing
@testable import RetireSmartIRA

@Suite("V2Disclosures")
struct V2DisclosuresTests {
    @Test("positioning avoids full-planner overclaim and uses no em dash")
    func positioningIsHonest() {
        let lower = V2Disclosures.positioning.lowercased()
        #expect(!lower.contains("complete retirement"))
        #expect(!lower.contains("full retirement"))
        #expect(!lower.contains("optimization plan"))
        #expect(!V2Disclosures.positioning.contains("\u{2014}"))
        #expect(V2Disclosures.positioning.contains("transparent assumptions"))
    }

    @Test("limitations are present, non-empty, and use no em dash")
    func limitationsPresent() {
        #expect(V2Disclosures.limitations.count >= 5)
        #expect(V2Disclosures.limitations.allSatisfy { !$0.isEmpty })
        #expect(V2Disclosures.limitations.allSatisfy { !$0.contains("\u{2014}") })
    }
}
