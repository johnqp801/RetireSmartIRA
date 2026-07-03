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

    @Test("limitations reflect shipped taxable-accounts accuracy (no stale muni/rate-tier claims)")
    func limitationsMatchShippedEngine() {
        let all = V2Disclosures.limitations.joined(separator: "\n").lowercased()
        // Muni is now included in MAGI; the old "excluded from MAGI" claim must be gone.
        #expect(!all.contains("excluded from magi"))
        // Qualified dividends / LTCG are now rate-tiered; the old "not separately rate-tiered" claim must be gone.
        #expect(!all.contains("not separately rate-tiered"))
        // The accurate replacement is present.
        #expect(all.contains("average cost-basis estimate"))
    }

    @Test("inputsUsed is present, non-empty, and uses no em dash")
    func inputsUsedIsHonest() {
        #expect(!V2Disclosures.inputsUsed.isEmpty)
        #expect(!V2Disclosures.inputsUsed.contains("\u{2014}"))
        #expect(V2Disclosures.inputsUsed.lowercased().contains("taxable accounts"))
    }
}
