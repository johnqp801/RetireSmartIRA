### Task 7: Prove the new fields cannot be silently dropped by the encoder

Phase 1 found five separate fields that could have vanished without moving any computed value. Four of them shared one root cause: **asserting on round-tripped values rather than on the encoded representation.** This task applies the control that closed them to the five fields added in Tasks 2 to 6.

**Files:**
- Modify: `RetireSmartIRATests/StateTaxCodableRoundTripTests.swift`

- [ ] **Step 1: Write the failing JSON-shape test**

Read `retirementExemptionsEncodesExpectedJSONShape` and `stateTaxConfigEncodesExpectedJSONShape` first and extend them in the same style rather than adding a parallel mechanism.

```swift
    @Test("Phase 3a's new keys appear in encoded RetirementIncomeExemptions JSON")
    func phase3aKeysSurviveEncoding() throws {
        // Every value differs from its own default, so a dropped encode line
        // cannot be masked by decodeIfPresent falling back to the same value.
        let exemptions = RetirementIncomeExemptions(
            socialSecurityExempt: false,
            distributionMinAge: 55,
            exemptionAttribution: .perQualifyingSpouse,
            agiPhaseout: AGIPhaseout(thresholdSingle: 50_000, thresholdMFJ: 75_000,
                                     shape: .linear(perDollar: 1.0)),
            rothConversionExemption: RothConversionExemption(
                minAge: 55, withheldPortionRemainsTaxable: true))

        let data = try JSONEncoder().encode(exemptions)
        let object = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["distributionMinAge"] as? Int == 55)
        #expect(object["exemptionAttribution"] as? String == "perQualifyingSpouse")

        let phaseout = try #require(object["agiPhaseout"] as? [String: Any])
        #expect(phaseout["thresholdSingle"] as? Double == 50_000)
        #expect(phaseout["thresholdMFJ"] as? Double == 75_000)
        #expect((phaseout["shape"] as? [String: Any])?["kind"] as? String == "linear")

        let conversion = try #require(object["rothConversionExemption"] as? [String: Any])
        #expect(conversion["minAge"] as? Int == 55)
        #expect(conversion["withheldPortionRemainsTaxable"] as? Bool == true)
    }

    @Test("personalExemption appears in encoded StateTaxConfig JSON when present, and is absent when nil")
    func personalExemptionEncodingIsConditional() throws {
        let withExemption = StateTaxConfig(
            state: .newJersey, taxSystem: .flat(rate: 0.05),
            retirementExemptions: RetirementIncomeExemptions(),
            stateDeduction: .none,
            personalExemption: StatePersonalExemption(
                single: 1_000, marriedFilingJointly: 2_000,
                seniorAdditionalPerFiler: 1_000, seniorAge: 65))
        let present = try #require(try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(withExemption)) as? [String: Any])
        let exemption = try #require(present["personalExemption"] as? [String: Any])
        // All four values distinct, so no two fields can be swapped undetected.
        #expect(exemption["single"] as? Double == 1_000)
        #expect(exemption["marriedFilingJointly"] as? Double == 2_000)
        #expect(exemption["seniorAdditionalPerFiler"] as? Double == 1_000)
        #expect(exemption["seniorAge"] as? Int == 65)

        let without = StateTaxConfig(
            state: .kansas, taxSystem: .flat(rate: 0.05),
            retirementExemptions: RetirementIncomeExemptions(),
            stateDeduction: .none)
        let absent = try #require(try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(without)) as? [String: Any])
        #expect(absent["personalExemption"] == nil,
                "a nil personal exemption must omit the key, not write null, \
                so 50 files stay free of a key they do not need")
    }
```

`single: 1_000` and `seniorAdditionalPerFiler: 1_000` are the same value, so those two specifically cannot be told apart by this test alone. That is acceptable only because a swap between them is caught behaviorally by `personalExemptionSeniorIsPerFiler` in Task 3, which asserts 3,000 for a household where one spouse is 66 and the other 60. State that reasoning in the report rather than leaving it implicit.

- [ ] **Step 2: Run and confirm it passes** (the encode lines were written in Tasks 2 to 6)

If any assertion fails, the corresponding `encode` line is missing. Fix the encoder, not the test.

- [ ] **Step 3: Prove each assertion discriminates, by deleting encode lines**

For each of `distributionMinAge`, `exemptionAttribution`, `agiPhaseout`, `rothConversionExemption` and `personalExemption`: comment out its line in `encode(to:)`, run this suite, confirm a named failure, restore it. Five mutations, five transcripts. Report which you actually ran; do not reconstruct plausible output for any you skipped.

- [ ] **Step 4: Commit**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && git add -A && git commit -m "test(state-tax): JSON-shape assertions for every Phase 3a field"
```

---

