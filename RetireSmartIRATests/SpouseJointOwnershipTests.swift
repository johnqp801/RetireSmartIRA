//
//  SpouseJointOwnershipTests.swift
//  RetireSmartIRATests
//
//  Covers three ownership defects found while investigating "I added a spouse
//  with an IRA and don't see the RMDs":
//
//  1. A spouse-owned account with Enable Spouse OFF rendered an RMD of half the
//     balance.  `spouseCurrentAge` / `spouseRmdAge` both return 0 when there is
//     no spouse, `0 >= 0` reads as "RMD required", and the Uniform Lifetime
//     Table's `?? 2.0` fallback (meant for ages past 120) divided the balance
//     by 2.  A $900,000 account showed a $450,000 "Required Withdrawal" while
//     the household total above it showed $0.
//
//  2. `.joint`-owned retirement accounts belonged to neither per-owner bucket,
//     so they were counted by `totalTraditionalIRABalance` but silently dropped
//     from `calculateCombinedRMD()` — understating a required withdrawal, which
//     carries a 25% excise penalty.
//
//  3. An IRA has exactly one owner under IRS rules, so "Joint" should not be
//     offerable for retirement accounts at all, and "Spouse" should not be
//     offerable unless a spouse is configured.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Spouse & Joint Account Ownership")
@MainActor
struct SpouseJointOwnershipTests {

    // MARK: - Helpers

    private func makeIRA(
        _ name: String,
        _ type: AccountType = .traditionalIRA,
        balance: Double,
        owner: Owner
    ) -> IRAAccount {
        IRAAccount(name: name, accountType: type, balance: balance, owner: owner)
    }

    // MARK: - 1. Engine floor: no RMD below the Uniform Lifetime Table

    @Suite("RMD engine never invents a distribution below RMD age")
    @MainActor
    struct EngineFloor {

        /// The exact defect: age 0 fell through to the `?? 2.0` fallback.
        @Test("Age 0 produces no RMD, not half the balance")
        func ageZeroProducesNoRMD() {
            #expect(RMDCalculationEngine.calculateRMD(for: 0, balance: 900_000) == 0)
        }

        @Test("Every age below the table start produces no RMD")
        func belowTableStartProducesNoRMD() {
            for age in 0..<70 {
                #expect(
                    RMDCalculationEngine.calculateRMD(for: age, balance: 900_000) == 0,
                    "age \(age) produced a non-zero RMD"
                )
            }
        }

        @Test("The table's first age still divides normally")
        func tableStartStillDivides() {
            // 291,000 / 29.1 == 10,000
            #expect(abs(RMDCalculationEngine.calculateRMD(for: 70, balance: 291_000) - 10_000) < 0.01)
        }

        @Test("Regression: the age-73 case shown in the app is unchanged")
        func age73Unchanged() {
            // 1,200,000 / 26.5 == 45,283.0188...
            let rmd = RMDCalculationEngine.calculateRMD(for: 73, balance: 1_200_000)
            #expect(abs(rmd - 45_283.0188) < 0.01)
        }

        /// The `?? 2.0` fallback is correct *past* the table and is pinned by
        /// existing tests — the floor must not disturb it.
        @Test("Ages beyond the table still use the 2.0 divisor")
        func beyondTableUnchanged() {
            #expect(RMDCalculationEngine.calculateRMD(for: 120, balance: 1_000) == 500)
            #expect(RMDCalculationEngine.calculateRMD(for: 130, balance: 1_000) == 500)
        }

        @Test("A negative age produces no RMD rather than crashing")
        func negativeAge() {
            #expect(RMDCalculationEngine.calculateRMD(for: -5, balance: 900_000) == 0)
        }
    }

    // MARK: - 2. Joint accounts are counted, never dropped

    @Test("A joint traditional IRA counts toward the primary's RMD balance")
    func jointTraditionalCountsAsPrimary() {
        let mgr = AccountsManager()
        mgr.iraAccounts = [
            makeIRA("Mine", balance: 100_000, owner: .primary),
            makeIRA("Joint", balance: 50_000, owner: .joint)
        ]
        #expect(mgr.primaryTraditionalIRABalance == 150_000)
    }

    @Test("A joint Roth counts toward the primary's Roth balance")
    func jointRothCountsAsPrimary() {
        let mgr = AccountsManager()
        mgr.iraAccounts = [
            makeIRA("Mine", .rothIRA, balance: 100_000, owner: .primary),
            makeIRA("Joint", .rothIRA, balance: 25_000, owner: .joint)
        ]
        #expect(mgr.primaryRothBalance == 125_000)
    }

    @Test("Joint balances do not leak into the spouse's bucket")
    func jointDoesNotLeakToSpouse() {
        let mgr = AccountsManager()
        mgr.iraAccounts = [
            makeIRA("Joint", balance: 50_000, owner: .joint),
            makeIRA("Hers", balance: 900_000, owner: .spouse)
        ]
        #expect(mgr.spouseTraditionalIRABalance(enableSpouse: true) == 900_000)
    }

    /// The invariant the joint bug broke: with a spouse configured, no dollar of
    /// traditional balance may sit outside the two per-owner buckets.
    @Test("Primary + spouse accounts for every traditional dollar")
    func perOwnerBucketsCoverTheHouseholdTotal() {
        let mgr = AccountsManager()
        mgr.iraAccounts = [
            makeIRA("Mine", balance: 1_200_000, owner: .primary),
            makeIRA("Joint", balance: 50_000, owner: .joint),
            makeIRA("Hers", balance: 900_000, owner: .spouse)
        ]
        let perOwner = mgr.primaryTraditionalIRABalance
            + mgr.spouseTraditionalIRABalance(enableSpouse: true)
        #expect(perOwner == mgr.totalTraditionalIRABalance)
        #expect(perOwner == 2_150_000)
    }

    // MARK: - 3. Owner picker options

    @Test("Retirement accounts never offer Joint")
    func retirementNeverOffersJoint() {
        for enableSpouse in [true, false] {
            let options = Owner.retirementOwnerOptions(
                enableSpouse: enableSpouse,
                including: .primary
            )
            #expect(
                !options.contains(.joint),
                "Joint offered with enableSpouse=\(enableSpouse); an IRA has exactly one owner"
            )
        }
    }

    @Test("Spouse is offered only when a spouse is configured")
    func spouseOfferedOnlyWhenEnabled() {
        #expect(Owner.retirementOwnerOptions(enableSpouse: false, including: .primary) == [.primary])
        #expect(Owner.retirementOwnerOptions(enableSpouse: true, including: .primary) == [.primary, .spouse])
    }

    /// Editing a legacy account must not blank the picker: whatever the account
    /// is already set to has to remain selectable even if it is no longer offered.
    @Test("An existing owner stays selectable when editing legacy data")
    func existingOwnerIsGrandfathered() {
        let legacyJoint = Owner.retirementOwnerOptions(enableSpouse: false, including: .joint)
        #expect(legacyJoint.contains(.joint))
        #expect(legacyJoint.contains(.primary))

        let orphanSpouse = Owner.retirementOwnerOptions(enableSpouse: false, including: .spouse)
        #expect(orphanSpouse.contains(.spouse))
    }

    @Test("Options never contain duplicates")
    func optionsAreUnique() {
        for enableSpouse in [true, false] {
            for current in Owner.allCases {
                let options = Owner.retirementOwnerOptions(
                    enableSpouse: enableSpouse,
                    including: current
                )
                #expect(Set(options).count == options.count)
                #expect(options.contains(current), "the account's own owner must be selectable")
            }
        }
    }

    // MARK: - 4. Turning Enable Spouse off reassigns rather than deletes

    @Test("Reassignment moves spouse and joint accounts to the primary")
    func reassignmentMovesSpouseAndJoint() {
        let mgr = AccountsManager()
        mgr.iraAccounts = [
            makeIRA("Mine", balance: 1_200_000, owner: .primary),
            makeIRA("Hers", balance: 900_000, owner: .spouse),
            makeIRA("Joint", balance: 50_000, owner: .joint)
        ]

        mgr.reassignSpouseAndJointAccountsToPrimary()

        #expect(mgr.iraAccounts.allSatisfy { $0.owner == .primary })
        // Nothing deleted, nothing revalued.
        #expect(mgr.iraAccounts.count == 3)
        #expect(mgr.totalTraditionalIRABalance == 2_150_000)
    }

    @Test("Reassignment also covers taxable accounts")
    func reassignmentCoversTaxableAccounts() {
        let mgr = AccountsManager()
        mgr.taxableAccounts = [
            TaxableAccount(name: "Brokerage", owner: .spouse, balance: 400_000, costBasis: 250_000)
        ]

        mgr.reassignSpouseAndJointAccountsToPrimary()

        #expect(mgr.taxableAccounts.allSatisfy { $0.owner == .primary })
        #expect(mgr.taxableAccounts.first?.balance == 400_000)
    }

    @Test("The confirmation prompt reports what would be reassigned")
    func reassignmentSummaryIsAccurate() {
        let mgr = AccountsManager()
        mgr.iraAccounts = [
            makeIRA("Mine", balance: 1_200_000, owner: .primary),
            makeIRA("Hers", balance: 900_000, owner: .spouse),
            makeIRA("Joint", balance: 50_000, owner: .joint)
        ]
        mgr.taxableAccounts = [
            TaxableAccount(name: "Brokerage", owner: .spouse, balance: 400_000, costBasis: 250_000)
        ]

        let summary = mgr.spouseAndJointAccountSummary()
        #expect(summary.count == 3)
        #expect(summary.balance == 1_350_000)
    }

    @Test("With nothing to reassign the prompt reports zero")
    func reassignmentSummaryEmpty() {
        let mgr = AccountsManager()
        mgr.iraAccounts = [makeIRA("Mine", balance: 1_200_000, owner: .primary)]

        let summary = mgr.spouseAndJointAccountSummary()
        #expect(summary.count == 0)
        #expect(summary.balance == 0)
    }

    // MARK: - 5. The RMD screen refuses to price an unconfigured owner

    @Test("A spouse-owned account has no RMD context when there is no spouse")
    func spouseOwnedWithoutSpouseHasNoContext() {
        let context = RMDCalculatorView.ownerRMDContext(
            owner: .spouse,
            enableSpouse: false,
            primaryAge: 73, primaryRMDAge: 73,
            spouseAge: 0, spouseRMDAge: 0
        )
        #expect(context == nil, "with no spouse configured the screen must show no RMD at all")
    }

    @Test("A spouse-owned account uses the spouse's ages when a spouse exists")
    func spouseOwnedUsesSpouseAges() {
        let context = RMDCalculatorView.ownerRMDContext(
            owner: .spouse,
            enableSpouse: true,
            primaryAge: 73, primaryRMDAge: 73,
            spouseAge: 71, spouseRMDAge: 73
        )
        #expect(context?.age == 71)
        #expect(context?.rmdAge == 73)
    }

    @Test("Joint and primary accounts both price off the primary")
    func jointAndPrimaryUsePrimaryAges() {
        for owner in [Owner.primary, Owner.joint] {
            let context = RMDCalculatorView.ownerRMDContext(
                owner: owner,
                enableSpouse: true,
                primaryAge: 73, primaryRMDAge: 73,
                spouseAge: 71, spouseRMDAge: 73
            )
            #expect(context?.age == 73, "\(owner) should price off the primary")
            #expect(context?.rmdAge == 73)
        }
    }

    /// End-to-end guard on the reported symptom.
    @Test("The $450,000 phantom RMD cannot be produced")
    func phantomRMDIsImpossible() {
        let context = RMDCalculatorView.ownerRMDContext(
            owner: .spouse,
            enableSpouse: false,
            primaryAge: 73, primaryRMDAge: 73,
            spouseAge: 0, spouseRMDAge: 0
        )
        // No context => the view shows no RMD.  And even if some future caller
        // passes age 0 straight through, the engine floor returns 0.
        #expect(context == nil)
        #expect(RMDCalculationEngine.calculateRMD(for: 0, balance: 900_000) == 0)
    }
}
