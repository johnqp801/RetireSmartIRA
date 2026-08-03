import Foundation

/// Answers whether the app has real state tax law for a given year, or is
/// holding the newest year it has constant.
///
/// A multi-year plan routinely projects thirty years forward while only one
/// year of state law exists in the bundle. That is a defensible modeling
/// choice, but before this type it was an undisclosed one: nothing in the app
/// distinguished a 2026 figure computed from 2026 law from a 2044 figure
/// computed from the same 2026 law.
enum StateTaxYearAvailability {

    /// Candidate years to probe. Bundled data starts at 2026; the upper bound
    /// is deliberately generous so adding a future year needs no code change.
    private static let probeRange = 2020...2100

    /// Anchors `Bundle(for:)` to the framework/app bundle that actually
    /// contains the resources, matching `StateTaxDataLoader.BundleMarker`.
    private final class BundleProbe {}

    /// True when at least one of the 51 jurisdictions has a bundled JSON file
    /// for `taxYear`.
    ///
    /// This is a `Bundle.url(forResource:)` lookup, never a decode, so it
    /// cannot be fooled by a file that exists but fails to parse -- that
    /// failure is `isBundledButUnloadable`'s job, not this one's.
    /// `StateTaxDataLoader.configs(for:).isEmpty` cannot be used for this
    /// question: `load(taxYear:)` throws on the FIRST missing or malformed
    /// jurisdiction and the year cache turns that throw into an empty
    /// dictionary, so a year with 50 good files and 1 broken one is
    /// indistinguishable from a year that was never bundled at all. Checking
    /// all 51 possible filenames (not just one) closes the same gap one
    /// level down: if the probe checked only, say, California, then deleting
    /// California specifically would misreport an otherwise-intact year as
    /// unbundled. As long as ANY of the 51 resolves, the year counts as
    /// bundled, however broken the rest of it is.
    private static func hasBundledData(taxYear: Int) -> Bool {
        let bundle = Bundle(for: BundleProbe.self)
        return USState.allCases.contains { state in
            bundle.url(forResource: "statetax-\(taxYear)-\(state.abbreviation)", withExtension: "json") != nil
        }
    }

    /// The newest tax year with at least one bundled jurisdiction file.
    ///
    /// Falls back to one year below `probeRange`'s floor -- never a real tax
    /// year -- if nothing in the probed range is bundled at all. That
    /// fallback is not expected to be reachable in a shipping build (2026's
    /// files always ship), but it exists so a catastrophically empty bundle
    /// reads every candidate year as extrapolated rather than silently
    /// naming a year that has no data either.
    static let latestBundledTaxYear: Int = {
        probeRange.last { hasBundledData(taxYear: $0) } ?? (probeRange.lowerBound - 1)
    }()

    /// True when `taxYear` has no bundled law and the newest available year is
    /// being held constant for it.
    static func isExtrapolated(taxYear: Int) -> Bool {
        taxYear > latestBundledTaxYear
    }

    /// Pure decision logic for the "shipped but broken" signal, separated
    /// from bundle/loader I/O so it can be exercised directly with literal
    /// inputs. `hasBundledData` is true when at least one jurisdiction file
    /// exists for the year; `configs` is what
    /// `StateTaxDataLoader.configs(for:)` actually produced for it.
    static func isBundledButUnloadable(hasBundledData: Bool, configs: [USState: StateTaxConfig]) -> Bool {
        hasBundledData && configs.isEmpty
    }

    /// True when `taxYear` has at least one bundled jurisdiction file, but the
    /// full multi-state load came back empty anyway -- the year's law
    /// shipped and something in it failed to decode. This is a BUILD DEFECT,
    /// not an extrapolation: it must never be folded into `isExtrapolated`,
    /// because that would tell a user "assumes prior-year law" about a year
    /// whose own law actually shipped and merely failed to load.
    static func isBundledButUnloadable(taxYear: Int) -> Bool {
        isBundledButUnloadable(hasBundledData: hasBundledData(taxYear: taxYear),
                                configs: StateTaxDataLoader.configs(for: taxYear))
    }

    /// A plain sentence for a projection year, or nil when real law exists.
    /// Phase 6 renders this; nothing consumes it yet.
    static func disclosure(forProjectionYear year: Int) -> String? {
        guard isExtrapolated(taxYear: year) else { return nil }
        return "State tax for \(year) assumes \(latestBundledTaxYear) law held constant, "
            + "not a forecast of future legislation."
    }
}
